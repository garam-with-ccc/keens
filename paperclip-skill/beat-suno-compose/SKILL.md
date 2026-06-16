---
name: beat-suno-compose
description: Use this skill to build an audio-conditioned Suno song from a persona's OWN prior track — search the persona's self-composed YouTube uploads, download the audio, separate stems, infer BPM, cut a clean 4-bar loop, and feed that clip to suno-enqueue via audio_input_path. The persona-only source scope is the originality guardrail. Pairs with write-suno-prompt (the prompt half) and suno-enqueue (the execution half).
---

# beat-suno-compose — persona track → 4-bar reference clip → audio-conditioned Suno song

This skill produces a short **reference audio clip** cut from a persona's *own* prior song and hands it to Suno for **audio-conditioned generation**. It is the front half of a three-skill chain:

1. **`beat-suno-compose` (this skill)** — find/download a persona track, separate stems, infer BPM, cut a 4-bar loop. Output = a local clip path + a partially-filled payload.
2. **[`write-suno-prompt`](../write-suno-prompt/SKILL.md)** — author the `styles`/`prompt`/parameters, and the audio-conditioned tuning (`audio_mode`, `style_influence`, `weirdness`).
3. **[`suno-enqueue`](../suno-enqueue/SKILL.md)** — push the JSON (now carrying `audio_input_path`), poll, report the GDrive link.

> **You never touch the browser.** All Suno side effects (attach, create, download, upload) belong to the suno-process daemon. suno-enqueue's eight absolute rules — especially **rule 2, no browsing to suno.com** — apply unchanged here. This skill only does *local* audio prep (yt-dlp / demucs / librosa / ffmpeg) on the daemon host, then enqueues.

---

## Originality guardrail (read first — non-negotiable)

**Scope the YouTube search to songs the persona itself made.** The reference clip must come from the persona's *own* catalogue — not someone else's recording, not a commercial release, not a track that merely sounds similar.

* Conditioning Suno on a third party's copyrighted master would produce a derivative of *their* work. That is off-limits.
* Conditioning on the persona's *own* earlier output keeps the new song inside the persona's own creative lineage — that is the whole point of "compose from your own beat."
* If you cannot confirm a candidate video is the persona's own composition/upload, **do not use it.** Stop and ask, or fall back to text-only generation (skip `audio_input_path` entirely).

---

## Required runtime tools

All run **locally on the daemon host** (the same host suno-enqueue's daemon runs on, so the cut clip path is reachable by `audio_input_path`).

| Tool | Purpose | Install |
|---|---|---|
| **`yt-dlp`** | Download audio from the persona's YouTube upload | `pipx install yt-dlp` (or `brew install yt-dlp`) |
| **`ffmpeg`** | Audio decode/encode + the final 4-bar cut | `brew install ffmpeg` |
| **`demucs`** | Stem separation (board-confirmed engine) | `pipx install demucs` (PyTorch-backed) |
| **`librosa`** *(primary)* | BPM + onset detection from the drum stem | `pip install librosa soundfile` |
| **`aubio`** *(fallback)* | BPM + onset, lighter dependency | `pip install aubio` |

Check availability before running; if a tool is missing, install it (per above) or stop and report — do **not** improvise a different pipeline.

```sh
for t in yt-dlp ffmpeg demucs; do command -v "$t" >/dev/null || echo "MISSING: $t"; done
python3 -c "import librosa" 2>/dev/null || echo "MISSING: librosa (will try aubio)"
```

---

## Pipeline

Work in a scratch dir you own, e.g. `~/beat-suno/<persona>/<slug>/`. Do **not** write under `~/Develop/suno-process/` (suno-enqueue rule 4).

### 1. Find the persona's own track on YouTube

Search YouTube for an upload the **persona itself** composed/published. Confirm authorship (channel = the persona, or the brief explicitly names the source video). Capture the video URL.

> Originality guardrail above governs this step. No persona-owned candidate → no `audio_input_path`.

### 2. Download the audio with `yt-dlp`

```sh
WORK=~/beat-suno/$PERSONA/$SLUG
mkdir -p "$WORK"
yt-dlp -x --audio-format wav --audio-quality 0 \
  -o "$WORK/source.%(ext)s" "$VIDEO_URL"
# → $WORK/source.wav
```

### 3. Separate stems with `demucs`

```sh
demucs --two-stems=drums -o "$WORK/demucs" "$WORK/source.wav"
# htdemucs default → $WORK/demucs/htdemucs/source/{drums,no_drums}.wav
DRUMS="$WORK/demucs/htdemucs/source/drums.wav"
```

The **drums/percussion stem** is what BPM/onset detection runs on — isolating it makes tempo tracking far more reliable than the full mix. (Full 4-stem `demucs -o ...` also works; you just need the drum stem.)

### 4. Infer BPM from the drum stem

`librosa` first; `aubio` as a fallback.

```python
# bpm.py — prints "<bpm> <first_onset_sec>"
import sys, librosa
y, sr = librosa.load(sys.argv[1], sr=None, mono=True)
tempo = float(librosa.beat.tempo(y=y, sr=sr)[0])          # global BPM estimate
onsets = librosa.onset.onset_detect(y=y, sr=sr, units="time")
first = float(onsets[0]) if len(onsets) else 0.0
print(f"{tempo:.2f} {first:.4f}")
```

```sh
read BPM ONSET < <(python3 bpm.py "$DRUMS")
# aubio fallback: aubio tempo "$DRUMS"   /   aubio onset "$DRUMS"
```

### 5. Cut a 4-bar loop from the first onset (`ffmpeg`)

Assume 4/4. **4 bars = 16 beats.** Seconds = `16 * 60 / BPM`. Start at the first detected onset so the clip lands on the downbeat instead of mid-silence.

```sh
DUR=$(python3 -c "print(16*60/float('$BPM'))")
ffmpeg -y -ss "$ONSET" -t "$DUR" -i "$WORK/source.wav" \
  -c:a pcm_s16le "$WORK/cut.wav"
# → $WORK/cut.wav  (the reference clip)
```

Cut from the **full mix** (`source.wav`), not the isolated drum stem — Suno conditions better on a musical excerpt than on drums alone. The drum stem is only for tempo/onset analysis.

> **Deferred — verse/chorus detection (follow-up, NOT in this version).** This v1 does a single naive cut: first onset → 4 bars. It does **not** locate a chorus/hook or pick the "best" section. Smarter section detection (e.g. structural segmentation to grab the chorus) is a **follow-up** item, intentionally out of scope per the board. Document this limitation wherever you report the clip.

### 6. Enqueue as an audio-conditioned Suno song

Feed `cut.wav`'s **absolute** path into the `audio_input_path` field of a payload you author with [`write-suno-prompt`](../write-suno-prompt/SKILL.md), then run it through [`suno-enqueue`](../suno-enqueue/SKILL.md). No browser, no manual upload — the daemon attaches the file.

```sh
CLIP="$WORK/cut.wav"          # must be within suno-enqueue's accepted formats + size cap
CRID=$(uuidgen | tr 'A-Z' 'a-z')
cat <<EOF | ~/Develop/suno-process/bin/suno-enqueue
{
  "client_request_id": "$CRID",
  "persona": "$PERSONA",
  "paperclip_issue_id": "$PAPERCLIP_ISSUE_ID",
  "song_title": "<invent one>",
  "version": "v5.5",
  "styles": "<from write-suno-prompt>",
  "prompt": "<from write-suno-prompt>",
  "lyrics_mode": "Auto",
  "audio_input_path": "$CLIP",
  "audio_mode": "cover"
}
EOF
```

`audio_input_path` / `audio_mode` are defined in [suno-enqueue's payload schema](../suno-enqueue/SKILL.md#payload-schema). Acquire the concurrency token, poll `/status`, and report the `music_drive_link` exactly as suno-enqueue documents — that half is unchanged.

---

## Outputs

* **`$WORK/cut.wav`** — the 4-bar reference clip (the `audio_input_path` value).
* **`$WORK/source.wav`** and **`$WORK/demucs/...`** — intermediate artifacts (keep for re-cuts; safe to delete after).
* **The enqueued payload** — JSON carrying `audio_input_path` + `audio_mode`, handed to suno-enqueue.

When you report on your Paperclip issue, note the **source video** (proving persona-ownership), the **inferred BPM**, and that the cut used the **naive first-onset/4-bar** method (verse/chorus detection deferred).

---

## Guardrails recap

* **Persona-own source only** — the originality guardrail. No third-party masters as conditioning input.
* **No browser / no manual Suno upload** — suno-enqueue rules 1–8 hold; the daemon owns all Suno side effects.
* **Validate the clip** against suno-enqueue's `audio_input_path` contract (existing regular file, accepted extension, within size cap) — a bad clip returns `VALIDATION_ERROR` at enqueue time.
* **Scratch files stay outside `~/Develop/suno-process/`** (rule 4).
