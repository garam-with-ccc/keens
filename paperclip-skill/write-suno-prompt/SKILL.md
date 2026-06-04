---
name: write-suno-prompt
description: Use this skill to turn a creative brief into a well-formed Suno style prompt and suno-enqueue payload. This is the prompt-authoring half; suno-enqueue is the execution half. Apply it whenever you are deciding WHAT styles / prompt / parameters to send — before you call the suno-enqueue CLI. Based on Suno's official "Writing a style prompt" guide.
---

# write-suno-prompt — brief → Suno style prompt

This skill is the **partner** of [`suno-enqueue`](../suno-enqueue/SKILL.md). They form a pair:

* **`write-suno-prompt` (this skill)** — *how to compose* the `styles` / `prompt` / parameters from a creative brief.
* **`suno-enqueue`** — *how to actually run it*: acquire a slot, push the JSON, poll, report the GDrive link.

> Compose your payload with **this** skill, then execute it with **suno-enqueue**. Never browse to suno.com — suno-enqueue's rules still apply unchanged.

This skill does not make music and does not call any CLI. It produces a filled-in `suno-enqueue` payload (the JSON in suno-enqueue's "Payload schema") that you then pipe into `~/Develop/suno-process/bin/suno-enqueue`.

---

## The mental model: a style prompt is mix-and-match

Suno reads `styles` as a layered list of descriptors. You build it by picking from **five axes** and combining them. You don't need all five — pick what serves the brief.

| Axis | Pick from… (examples) |
|---|---|
| **Decade** | 1950s, 1960s, 90s, 2000s, 2010s |
| **Sonic Style** | Glitchy, Alternative, Indie, Cinematic, Lofi, Acapella, Chamber, Soulful |
| **Genre** | Nu Jazz, K-Pop, R&B, Singer-Songwriter, Neo-Soul, EDM, Future Bass |
| **Instruments** | Piano, 808s, String quartet, Brass section, Tabla, Synth bass |
| **Mood** | Bouncy, Dark, Meditative, Relaxed, Excited, Tense |

---

## The six rules (all from the official guide — apply every time)

### 1. Mix-and-match across the axes
Pull one or more items from Decade / Sonic Style / Genre / Instruments / Mood and string them together. A good `styles` value usually touches **genre + 1–2 instruments + a mood**, optionally pinned to a decade.

### 2. Choose your level of detail
Both extremes are valid — match it to how locked-in the brief is.
* **Simple:** `Funk` · `Alternative R&B` · `Electro-pop`
* **Detailed:** `1960s Funk w/ brass section` · `Alternative R&B, soulful male vocals, boy band harmonies` · `Gritty electro pop for late night parties with buzzy synth bass`

A tight brief → more detail. A "surprise me" brief → fewer descriptors + higher `weirdness`.

### 3. Order changes the result — most important style FIRST
The leading token dominates the sound.
* `Trap soul with electronic beats` → leans **trap**.
* `Soul trap with electronic beats` → leans **soul**.
* `Electronic beats with soul and trap` → leans **electronic**.

So: put the genre/feel that defines the track at the very front of `styles`.

### 4. Repeat important tags to raise their odds
Repetition increases the chance Suno honors a feature. To force brass:
`1970s Funk with brass section, brass, horns, horn section, brass section`
beats `1970s funk with brass`. Use sparingly for the 1–2 elements that *must* be present.

### 5. Put BPM and Key directly in the style prompt
Tempo and key go **inside `styles`** (not a separate field):
`Key of G Major, 140bpm` · `Ab Minor 89bpm`.
Add them when the brief specifies a tempo/feel (e.g. rhythm-game drop, ballad), otherwise omit and let Suno choose.

### 6. Use the genre dictionary as vocabulary
Pull precise descriptors from the compressed dictionary below instead of vague words.

#### Genre / descriptor dictionary (condensed from the guide)
| Bucket | Vocabulary |
|---|---|
| **EDM** | Dance pop, Drill, Jersey club, Festival, Future Bass, Bit pop, chip tune, Nu disco, electropop, french house, acid breaks, industrial, Complextro, Stutter house, Liquid Drum & Bass, Deep house, techno, jungle, two step, dubstep |
| **Funk** | 1970s funk, Synth funk, electrofunk, 1980s soul, nu-disco, Boogie, Thai funk |
| **R&B / Soul** | Alternative R&B, Trap soul, Smooth soul, Art R&B, Neo-soul, jazz fusion, pop soul, Contemporary/Classic R&B, New Jack Swing, Quietstorm, Church, Gospel, Blues |
| **Hip Hop** | Conscious, Southern, Hardcore, UK Grime, boom bap, Indie hip hop, cloud rap, Gangsta Rap, Detroit Trap, Jazz Rap, Pop rap, G-Funk, East/West Coast, Chipmunk Soul, Twerk, Snap, Experimental, Abstract |
| **Rock** | Pop Rock, Psychedelic rock, post-punk, post-grunge, post-britpop, funk rock, stadium rock, Piano rock, alt rock, indie rock, Thrash/death/melodic-death metal, metal core, LA metal |
| **Pop** | Alt-pop, teen pop, power pop, euro pop, synth pop, hip house, Pep band |
| **Indie / Folk** | Dream pop, bedroom pop, Indie pop, indie folk, chamber pop, folk pop, art pop, contemporary folk, Singer-songwriter, Glitch folk, chamber folk, Stomp and holler, bluegrass |
| **International** | K-pop, C-pop, J-pop, J-rock, Bollywood, World Music, Egyptian, Arabian, Bulgarian Chant, Amapiano, Afropiano, Afrobeats, UK garage, UK grime, Flamenco |
| **Latin** | Reggaeton, montuno, salsa, Mariachi, bossa soul, bossa nova, baile funk, cumbia, cha cha cha, rumba, MPB, tango |
| **Weird** | Glitch, IDM, Ancient, Avant Garde, Art, Art pop, Dissonant, Detuned, toy pop |
| **Deep / Heady** | Meditative, Hypnagogic, Dreamy, Hypnotic, Ambient |
| **Country** | Contemporary/traditional country, country pop, country trap, country rap, bro-country |
| **Misc** | minimal, sparse, busy, active, slow, ballad, fast, uptempo, smooth, Syncopated, accents (British, UK, Indian, Chinese, Korean…) |
| **Instruments** | Brass section, Tabla, String section, 808, Rhodes, tribal, organic drums, flute, orchestra, synth bass, 80s synths, funk guitar, military band |
| **Vocals** | Male Voice, Boy band, Female voice, girl group, Growling vocal, soulful vocal, whispering, Gritty rock voice, Acapella, Spoken, chant, Vocoder |

---

## Creative Boost: expanding into the free-text `prompt`

Suno's "Creative Boost" button turns a short tag into a vivid groove description. Do the same by hand when filling the `prompt` field. Example from the guide:

> `1960s Funk w/ brass section` **+Boost →**
> "A tight 1960s funk groove drives the track, anchored by syncopated drums, crisp hi-hats, and an agile bassline. Wah guitar riffs and electric piano add rhythmic color. The brass section—trumpet, sax, and trombone—delivers powerful stabs, punchy hooks, and instrumental breaks."

Keep `styles` as the compact tag list; use `prompt` for the prose groove/arrangement narrative.

---

## Mapping the brief onto the suno-enqueue payload

Follow suno-enqueue's payload schema **exactly**. This skill teaches how to *fill* each field:

| Field | How to fill it (using the rules above) |
|---|---|
| **`styles`** | The mix-and-match tag list. Apply rules **1–6**: most-important genre first (rule 3), genre + instruments + mood (rule 1), repeat must-have tags (rule 4), append `Key … , NNNbpm` (rule 5). Comma-separated. This is the single most important field. |
| **`exclude_styles`** | Anything that would break the brief. Name the adjacent-but-wrong genres and timbres you must keep out (e.g. for a clean ballad: `edm, distortion, screamo`; for a hard J-core drop: `acoustic, ballad, lofi`). |
| **`prompt`** | Free-text groove/mood narrative — the hand-written "Creative Boost" expansion. Describe drums, bassline, energy arc, and the emotional scene. Don't restate the tag list; paint it. |
| **`song_title`** | REQUIRED (suno-enqueue rejects empty). Invent a short, human-readable, filename-safe title. |
| **`vocal_gender`** | `"Male"` / `"Female"` / `null` (Auto). Set from the brief's vocal direction; `null` if it doesn't matter. |
| **`lyrics_mode`** | `"Manual"` (you supply `lyrics`), `"Auto"`, or `"Mumble"` (instrumental-ish / no real words). Match the deliverable. |
| **`lyrics`** | Required only when `lyrics_mode` is `Manual`. Originality guardrail: never reproduce protected lyrics or reference real artists/producer tags (Suno's moderation rejects those). |
| **`weirdness`** (0–100) | Experimentation. UI default 50. Lower (~20–35) for on-genre, predictable tracks; higher (~60–80) for "Weird"/avant / surprise-me briefs. |
| **`style_influence`** (0–100) | How hard Suno clings to your `styles`. UI default 50. Higher (~65–85) when genre fidelity matters; lower when you want room to roam. |
| **`max_mode`** | `true` for the strongest quality pass; set per brief/credit budget. |
| **`version`** | The model string (e.g. `"v5.5"`). |

> Reminder: `client_request_id` (fresh UUID v4), `persona`, `paperclip_issue_id`, the concurrency token, polling, and reporting the GDrive link are all **suno-enqueue's** job — see that skill. This skill stops once the payload's creative fields are filled.

---

## Worked examples: brief → finished payload

### Example 1 — Bright youth vocaloid rock (LAST_NOTE house style)
**Brief:** Upbeat school-anime opening, fast guitar-driven J-rock, female vocal, hopeful. ~180bpm.

```json
{
  "song_title": "Morning Bell Sprint",
  "version": "v5.5",
  "styles": "J-rock, power pop, bright guitar rock, driving drums, energetic, soaring female vocal, anime opening, fast, E Major 180bpm, J-rock, guitar",
  "exclude_styles": "ballad, lofi, ambient, edm, trap",
  "prompt": "A bright, breathless school-anime opening. Palm-muted electric guitars and a galloping snare push the verse forward, the pre-chorus lifts on stacked backing 'oh-oh's, and the chorus explodes into wide power chords with a hopeful, run-down-the-hallway energy. Clean female lead, crisp and youthful.",
  "vocal_gender": "Female",
  "lyrics_mode": "Auto",
  "weirdness": 25,
  "style_influence": 75,
  "max_mode": true
}
```
*Rules used:* genre first (`J-rock`), genre+instrument+mood mix, repeated `J-rock`/`guitar` (rule 4), `E Major 180bpm` inline (rule 5), exclusions guard against drift to ballad/edm.

### Example 2 — J-core / rhythm-game drop (USAO house style)
**Brief:** Hard festival rhythm-game track, massive kick, screeching synth lead, no real lyrics, fast and aggressive. 175bpm.

```json
{
  "song_title": "Overdrive Core",
  "version": "v5.5",
  "styles": "J-core, hardcore, hardstyle, distorted kick, kick, screeching supersaw lead, festival, aggressive, fast, rhythm game, F Minor 175bpm, J-core, hardcore",
  "exclude_styles": "acoustic, ballad, lofi, ambient, smooth, soft vocals",
  "prompt": "A relentless J-core assault built for a rhythm-game boss stage. Gabber-style distorted kicks hammer four-on-the-floor, a detuned supersaw screams the lead riff, and the drop detonates with white-noise risers and stutter edits. Brief vocal chops as texture only — energy stays maxed end to end.",
  "vocal_gender": null,
  "lyrics_mode": "Mumble",
  "weirdness": 45,
  "style_influence": 80,
  "max_mode": true
}
```
*Rules used:* hardest genre first, repeated `kick`/`J-core`/`hardcore` (rule 4), `F Minor 175bpm` inline (rule 5), aggressive exclusions keep it from softening.

### Example 3 — Neon-melancholy vocal EDM-pop (YUNOSUKE house style)
**Brief:** Emotional future-bass pop, bittersweet night-city mood, male vocal, lush supersaws and piano, mid-tempo. Around 150bpm.

```json
{
  "song_title": "Citylight Afterglow",
  "version": "v5.5",
  "styles": "future bass, electro pop, emotional, lush supersaw, piano, melancholic, neon, male vocal, mid-tempo, future bass, Bb Minor 150bpm",
  "exclude_styles": "hardcore, distortion, metal, country",
  "prompt": "Neon-melancholy future bass for an empty late-night train platform. A soft piano motif opens, vocal chops shimmer over warm sub-bass, and the drop blooms into lush detuned supersaws with a gated, breathing rhythm. Bittersweet and cinematic — longing under the city lights.",
  "vocal_gender": "Male",
  "lyrics_mode": "Manual",
  "lyrics": "[Verse]\n(write original lyrics here — no real-artist references)\n[Chorus]\n...",
  "weirdness": 35,
  "style_influence": 70,
  "max_mode": true
}
```
*Rules used:* `future bass` first and repeated (rules 3–4), genre+instrument+mood mix, `Bb Minor 150bpm` inline (rule 5), exclusions keep it from hardening.

---

## Quick checklist before you hand off to suno-enqueue

- [ ] `styles` leads with the defining genre/feel (rule 3)
- [ ] `styles` mixes genre + instrument(s) + mood (rule 1), at the right detail level (rule 2)
- [ ] Must-have elements repeated (rule 4)
- [ ] BPM/Key written inside `styles` when relevant (rule 5)
- [ ] Vocabulary pulled from the dictionary (rule 6)
- [ ] `exclude_styles` blocks the adjacent-wrong genres
- [ ] `prompt` is a vivid groove narrative, not a tag restate
- [ ] `song_title` set; `vocal_gender` / `lyrics_mode` / `lyrics` match the brief
- [ ] `weirdness` / `style_influence` tuned to brief (not blindly 50)
- [ ] **Originality guardrail:** no protected lyrics, no real-artist/producer-tag references, no clone of a specific recording

Then execute with **[`suno-enqueue`](../suno-enqueue/SKILL.md)**.
