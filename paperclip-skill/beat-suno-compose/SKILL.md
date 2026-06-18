---
name: beat-suno-compose
description: Use this skill to build an audio-conditioned Suno song from a persona's OWN prior track — search the persona's self-composed YouTube uploads, download the audio, separate stems, infer BPM from the drum stem, cut a clean 4-bar loop starting at the first pitch, and feed that clip to suno-enqueue via audio_input_path. The persona-only source scope is the originality guardrail. Pairs with write-suno-prompt (the prompt half) and suno-enqueue (the execution half).
---

# beat-suno-compose — persona track → 4-bar reference clip → audio-conditioned Suno song

This skill produces a short **reference audio clip** cut from a persona's *own* prior song and hands it to Suno for **audio-conditioned generation**. It is the front half of a three-skill chain:

1. **`beat-suno-compose` (this skill)** — find/download a persona track, separate stems, infer BPM from the drum stem, cut a 4-bar loop starting at the first pitch. Output = a local clip path + a partially-filled payload.
2. **[`write-suno-prompt`](../write-suno-prompt/SKILL.md)** — author the `styles`/`prompt`/parameters, and the audio-conditioned tuning (`audio_mode`, `style_influence`, `weirdness`).
3. **[`suno-enqueue`](../suno-enqueue/SKILL.md)** — push the JSON (now carrying `audio_input_path`), poll, report the GDrive link.

> **You never touch the browser.** All Suno side effects (attach, create, download, upload) belong to the suno-process daemon. suno-enqueue's eight absolute rules — especially **rule 2, no browsing to suno.com** — apply unchanged here. This skill only does *local* audio prep (yt-dlp / demucs / librosa / ffmpeg) on the daemon host, then enqueues.

---

## Originality guardrail (read first — non-negotiable)

**Scope the YouTube search to songs the persona itself made.** The reference clip must come from the persona's *own* catalogue — not someone else's recording, not a commercial release, not a track that merely sounds similar.

* Conditioning Suno on a third party's copyrighted master would produce a derivative of *their* work. That is off-limits.
* Conditioning on the persona's *own* earlier output keeps the new song inside the persona's own creative lineage — that is the whole point of "compose from your own beat."
* If you cannot confirm a candidate video is the persona's own composition/upload, **do not use it.** Stop and ask, or fall back to text-only generation (skip `audio_input_path` entirely).

### Emulation personas: "own catalogue" = the camp's own persona-lens output (self-seed)

Most roster producers are **emulation personas** (e.g. Kanye, Pharrell) — they reference a real-world artist's *style* but have **no real-world catalogue of their own** to draw a clip from. A literal reading of "the persona's own catalogue" would lock every emulation persona out of the audio path entirely. That is **not** the intent.

For an emulation persona, **"the persona's own catalogue" means the camp's own generated output in that persona's lens.** Concretely, the **self-seed** path:

1. Generate a **persona-lens seed track text-only** (no `audio_input_path`) via the normal write-suno-prompt → suno-enqueue chain — this is the camp's own original output, produced through the persona's stylistic lens.
2. Run **this skill's pipeline on that self-generated seed**: stem-sep → BPM → first-pitch 4-bar cut → self-condition the audio path on the cut.

This is **skill-clean** (no third-party master ever touches the conditioning input) and still exercises the full pipeline. The seed audio you condition on must be the camp's own generation — **conditioning on a real commercial master remains forbidden**, regardless of which artist the persona emulates.

> **Rule of thumb:** real-artist persona with a genuine self-uploaded catalogue → condition on that. Emulation persona with no real catalogue → self-seed (generate text-only in the persona's lens, then condition on a cut of *that*). Never a commercial master either way.

---

## Required runtime tools

All run **locally on the daemon host** (the same host suno-enqueue's daemon runs on, so the cut clip path is reachable by `audio_input_path`).

| Tool | Purpose | Install |
|---|---|---|
| **`yt-dlp`** | Download audio from the persona's YouTube upload | `pipx install yt-dlp` (or `brew install yt-dlp`) |
| **`ffmpeg`** | Audio decode/encode + the final 4-bar cut | `brew install ffmpeg` |
| **`demucs`** | Stem separation (board-confirmed engine) | `pipx install demucs` (PyTorch-backed) |
| **`librosa`** *(primary)* | BPM from the drum stem **+** first-pitch detection (`pyin`) on the full mix | `pip install librosa soundfile` |
| **`aubio`** *(BPM fallback only)* | BPM, lighter dependency. **Note:** aubio has no first-pitch step — if you fall back to it for tempo, still use librosa `pyin` for the cut start. | `pip install aubio` |

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
>
> **Emulation persona (no real catalogue)?** Don't search YouTube — **self-seed** instead: generate a persona-lens seed track text-only first, then run steps 2–5 of this pipeline on that self-generated audio. See "Emulation personas" under the originality guardrail. (For self-seed, your `source.wav` in step 2 is the camp's own generated seed file, not a yt-dlp download.)

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
SOURCE="$WORK/source.wav"   # full mix — used for first-pitch detection
```

The **drums/percussion stem** is what **BPM** detection runs on — isolating it makes tempo tracking far more reliable than the full mix. The **cut start point is the first *pitch*** and is computed from the **full mix** (`source.wav`), *not* from the drum stem — see step 4. (Full 4-stem `demucs -o ...` also works; you just need the drum stem for tempo. If you want a cleaner pitch signal you may point the pitch detector at the harmonic stem `no_drums.wav` instead of the full mix.)

### 4. Infer BPM (drum stem) and the first PITCH (full mix)

Two **separate** computations:

* **BPM / tempo** — from the **drum/percussion stem** (`$DRUMS`), where the beat is cleanest.
* **First pitch** — the time of the first sustained *pitched* (voiced) frame in the **full mix** (`$SOURCE`) via `librosa.pyin`. This is the cut start point.

> **Do NOT use the drum-stem onset as the cut start.** A drum onset lands on the first *percussion transient* (the beat drop), which chops off any melodic intro that precedes it. The cut must begin on the first **pitch**, so an intro melody is preserved and the clip starts on a note, not a kick.

`librosa` is primary; `aubio` may substitute **for BPM only** (it has no pitch step).

```python
# bpm.py — usage: python3 bpm.py <drum_stem.wav> [<fullmix_or_harmonic.wav>]
# prints "<bpm> <first_pitch_sec>"
#   - BPM (tempo)     : inferred from the DRUM/percussion stem (arg 1)
#   - first_pitch_sec : time of the FIRST sustained PITCH in the full mix /
#                       harmonic stem (arg 2; defaults to arg 1 if omitted)
# The cut start point is first_pitch_sec — NOT the drum onset.
import sys, librosa, numpy as np

drums_path = sys.argv[1]
pitch_path = sys.argv[2] if len(sys.argv) > 2 else sys.argv[1]

# --- tempo from the drum/percussion stem (drums track tempo best) ---
yd, srd = librosa.load(drums_path, sr=None, mono=True)
tempo = float(np.atleast_1d(librosa.feature.tempo(y=yd, sr=srd))[0])

# --- first PITCH from the full mix / harmonic content (the cut start) ---
yp, srp = librosa.load(pitch_path, sr=None, mono=True)
f0, _, voiced_prob = librosa.pyin(
    yp, sr=srp,
    fmin=librosa.note_to_hz('C2'), fmax=librosa.note_to_hz('C7'))
times = librosa.times_like(f0, sr=srp)

# require a short sustained voiced run so a single noisy frame can't trip it
MIN_VOICED_FRAMES = 3
voiced = (np.nan_to_num(voiced_prob) > 0.5) & ~np.isnan(f0)
first_pitch = 0.0
run = 0
for i, v in enumerate(voiced):
    run = run + 1 if v else 0
    if run >= MIN_VOICED_FRAMES:
        first_pitch = float(times[i - MIN_VOICED_FRAMES + 1])
        break

print(f"{tempo:.2f} {first_pitch:.4f}")
```

```sh
read BPM PITCH < <(python3 bpm.py "$DRUMS" "$SOURCE")
# aubio fallback for TEMPO ONLY: aubio tempo "$DRUMS"
#   (still take PITCH from librosa pyin — aubio has no first-pitch step)
```

### 5. Cut a 4-bar loop from the first PITCH (`ffmpeg`)

Assume 4/4. **4 bars = 16 beats.** Seconds = `16 * 60 / BPM`. Start at the **first pitch** (`$PITCH` from step 4) so the clip begins on the first musical note — intro melody included — instead of on the drum drop or mid-silence.

```sh
DUR=$(python3 -c "print(16*60/float('$BPM'))")
ffmpeg -y -ss "$PITCH" -t "$DUR" -i "$WORK/source.wav" \
  -c:a pcm_s16le "$WORK/cut.wav"
# → $WORK/cut.wav  (the reference clip, starting on the first pitch)
```

Cut from the **full mix** (`source.wav`), not the isolated drum stem — Suno conditions better on a musical excerpt than on drums alone. The drum stem is only for tempo analysis; the **start time comes from first-pitch detection on the full mix**.

> **Deferred — verse/chorus detection (follow-up, NOT in this version).** This v1 does a single naive cut: first pitch → 4 bars. It does **not** locate a chorus/hook or pick the "best" section. Smarter section detection (e.g. structural segmentation to grab the chorus) is a **follow-up** item, intentionally out of scope per the board. Document this limitation wherever you report the clip.

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

When you report on your Paperclip issue, note the **source video** (proving persona-ownership), the **inferred BPM**, the **first-pitch start time** the cut began at, and that the cut used the **naive first-pitch/4-bar** method (verse/chorus detection deferred).

---

## Guardrails recap

* **Persona-own source only** — the originality guardrail. No third-party masters as conditioning input. For emulation personas (no real catalogue), "persona-own" = the camp's own persona-lens generation (self-seed); commercial masters stay forbidden.
* **No browser / no manual Suno upload** — suno-enqueue rules 1–8 hold; the daemon owns all Suno side effects.
* **Validate the clip** against suno-enqueue's `audio_input_path` contract (existing regular file, accepted extension, within size cap) — a bad clip returns `VALIDATION_ERROR` at enqueue time.
* **Scratch files stay outside `~/Develop/suno-process/`** (rule 4).
