---
name: suno-enqueue
description: Use this skill whenever the agent's task involves generating music on Suno. The agent MUST follow these rules exactly. Never browse to suno.com, never use puppeteer, curl, gogcli, or filesystem tools to do Suno work — only the suno-enqueue CLI documented here.
---

# suno-enqueue — the only way to make a Suno song

You are a Paperclip music agent. The Suno harness daemon owns all side effects: browser automation, MP3 downloads, Google Drive uploads, file management. **Your only job is to push a well-formed song request into the queue, poll for the result, and report back on your own Paperclip issue.**

The daemon never speaks to Paperclip — it has no bot identity. You are the one who reports the GDrive link on your issue, using your normal Paperclip agent commenting flow. That keeps responsibility (and audit trail) with you.

If you try to do Suno work yourself, you will waste tokens, lose context across Claude Code session boundaries, and cause file overwrites or upload failures. The harness is designed so the agent **cannot** do those things — but you also must not try.

## Eight absolute rules

1. **The only way to create a Suno song is via this CLI:**
   ```sh
   echo '<JSON>' | ~/Develop/suno-process/bin/suno-enqueue
   ```
2. **Do not browse to suno.com**, do not use puppeteer/playwright/curl against it, do not open the Suno app. The harness has a Chrome browser already attached over CDP.
3. **Do not invoke gogcli.** The daemon uploads to Google Drive. You will not touch GDrive directly.
4. **Do not create, move, or delete files** under `~/Develop/suno-process/`. The daemon owns that directory.
5. **Acquire a concurrency token at the start of your run.** The daemon caps active agents at 6. Skipping this step does not protect the cap — but it lets you know whether to start work or wait.
   ```sh
   # Start
   curl -sS -X POST -H 'content-type: application/json' \
     -d '{"agent":"<your-paperclip-agent-name>"}' \
     http://127.0.0.1:8788/checkout
   # If the response is {"granted": false, ...}, sleep 30 seconds and retry.
   # If granted, you'll receive a token string — save it for /release.
   ```
   At the end of your run:
   ```sh
   curl -sS -X POST -H 'content-type: application/json' \
     -d '{"token":"<token from /checkout>"}' \
     http://127.0.0.1:8788/release
   ```
6. **`song_title` is required.** Suno's web form treats Song Title as optional, but our queue rejects it. **Always invent a song title** — even a working title — before calling the CLI.
7. **`client_request_id` must be a fresh UUID v4 for each new song.** Use `uuidgen` or the equivalent. Re-use the same UUID **only** when you intend to retry the exact same request (idempotent — the daemon will return the existing row's status, not duplicate it).
8. **Poll `/status/<client_request_id>` and post the result on your own Paperclip issue.** The daemon will NOT comment for you. When `status` becomes `done`, the response's `request.music_drive_link` is the GDrive URL for the primary clip; post that link as a comment on your issue using your standard Paperclip commenting tool/skill. If `status` becomes `needs_human` or starts with `paused_by_`, post a brief status note explaining the situation — humans watching the dashboard will resolve it, and you should stop until status returns to `done`.

## Payload schema

```json
{
  "client_request_id": "550e8400-e29b-41d4-a716-446655440000",
  "persona": "BalladBot",                       // = your Paperclip agent name
  "paperclip_issue_id": "issue_abc123",         // for your own tracking (daemon doesn't read it)
  "song_title": "겨울 새벽의 정류장",            // REQUIRED
  "version": "v5.5",                            // model
  "prompt": "분위기 있는 발라드, 차분한 피아노로 시작",
  "lyrics": "...",
  "styles": "ballad, ambient piano, 90s K-pop",
  "exclude_styles": "edm, distortion",
  "vocal_gender": "Female",                     // "Male" | "Female" | null (= Auto)
  "lyrics_mode": "Manual",                      // "Manual" | "Mumble" | "Auto"
  "max_mode": true,                             // boolean
  "weirdness": 30,                              // 0..100
  "style_influence": 60,                        // 0..100
  "audio_input_path": "~/clips/cut.wav",        // OPTIONAL local audio file — see below
  "audio_mode": "cover"                         // OPTIONAL "cover" | "remix" | "extend"
}
```

Field rules:

* `client_request_id`: UUID v4. Fresh per song, except deliberate retries.
* `persona`: Your agent name in Paperclip. Used as the GDrive subfolder.
* `paperclip_issue_id`: Stored as metadata so you can correlate later. The daemon does not read it.
* `song_title`: Required. Used in the GDrive filename. Keep it short and human-readable; avoid characters that break filenames if possible.
* `lyrics_mode`: If `Manual`, supply `lyrics`. If `Auto` or `Mumble`, `lyrics` may be omitted.
* `vocal_gender`: `null` means "let Suno choose".
* `weirdness`, `style_influence`: integers 0–100. The Suno UI defaults are 50.
* `audio_input_path` *(optional)*: a **local** audio file path on the daemon host (the daemon and you share the host). When present, the daemon attaches it to Suno's "Add audio" input for **audio-conditioned generation** before clicking Create; when absent, behaviour is identical to the text-only flow (no regression). The daemon does NOT browse or click on its own beyond the documented flow — rule 2 still holds; you never touch the browser. Contract is enforced at **enqueue time** so a bad value returns `VALIDATION_ERROR` immediately instead of wasting a claim:
  * Path may be absolute or `~/`-relative (`~` expands to the daemon user's home).
  * Must resolve to an existing, non-empty **regular file**.
  * Extension must be Suno-accepted: `.wav .flac .mp3 .mpeg .mpga .ogg .oga .opus .webm .mp4 .m4a .aac`.
  * File must be within the daemon's size cap (**default 50 MB**).
* `audio_mode` *(optional)*: mode hint applied **after** the audio is attached — `"cover"`, `"remix"`, or `"extend"` (maps to Suno's post-attach toggle). Best-effort: if Suno doesn't expose the requested toggle, the daemon logs and proceeds with Suno's default. Omit it to accept whatever Suno selects. Ignored when `audio_input_path` is absent.

## Full workflow

```sh
# 1. Acquire a slot
RESP=$(curl -sS -X POST -H 'content-type: application/json' \
  -d '{"agent":"BalladBot"}' http://127.0.0.1:8788/checkout)
TOKEN=$(echo "$RESP" | jq -r .token)
[ -z "$TOKEN" ] && { echo "Slot unavailable, retry later"; exit 0; }

# 2. Build payload
CRID=$(uuidgen | tr 'A-Z' 'a-z')
cat <<EOF | ~/Develop/suno-process/bin/suno-enqueue
{
  "client_request_id": "$CRID",
  "persona": "BalladBot",
  "paperclip_issue_id": "$PAPERCLIP_ISSUE_ID",
  "song_title": "겨울 새벽의 정류장",
  "version": "v5.5",
  "lyrics": "...",
  "styles": "ballad, ambient piano",
  "lyrics_mode": "Manual",
  "vocal_gender": "Female",
  "max_mode": true,
  "weirdness": 30,
  "style_influence": 60
}
EOF

# 3. Poll until done (up to ~10 minutes including generate + upload)
for i in $(seq 1 60); do
  STATUS=$(curl -sS "http://127.0.0.1:8788/status/$CRID" | jq -r .request.status)
  echo "status: $STATUS"
  case "$STATUS" in
    done) break ;;
    needs_human|paused_by_*) echo "blocked: $STATUS"; break ;;
  esac
  sleep 10
done

# 4. Read the drive link and report it on YOUR issue via your normal
#    Paperclip commenting flow (do NOT call the daemon for this).
LINK=$(curl -sS "http://127.0.0.1:8788/status/$CRID" | jq -r .request.music_drive_link)
# e.g. "🎵 Done: $LINK" as a comment on PAPERCLIP_ISSUE_ID

# 5. Release the slot
curl -sS -X POST -H 'content-type: application/json' \
  -d "{\"token\":\"$TOKEN\"}" http://127.0.0.1:8788/release
```

## What the daemon does on your behalf

(For your awareness, not for you to replicate.)

* Fills the Suno Advanced form with your inputs
* If `audio_input_path` is present: attaches that local file to Suno's "Add audio" upload input (driving Suno's upload wizard), applies the `audio_mode` toggle when requested, then proceeds with the normal flow. Download/stems/GDrive logic is unchanged for audio-conditioned songs.
* Clicks Create and watches the network for completion (≤5 min)
* Downloads both clips' MP3s
* Downloads stems if your Suno account has the feature
* Uploads everything to GDrive: `<root>/<persona>/<song_title>.mp3`, `<song_title> (alt).mp3`, `<song_title>.meta.json`, and `<song_title>/<stem>.mp3` for stems
* Verifies every upload and deletes the local file
* Re-generates `suno-queue.csv` and re-uploads it to GDrive

## Common error responses

* `{"ok": false, "error": "VALIDATION_ERROR", "detail": {...}}` — fix the payload and retry. For `audio_input_path`, `detail.field` is `"audio_input_path"` and `detail.reason` is one of `not_found`, `not_a_file`, `unsupported_format`, `too_large`, `empty` — correct the file/path and re-enqueue (a fresh `client_request_id` is fine since the bad row was never created).
* `{"ok": true, "created": false, "status": "..."}` — duplicate `client_request_id`; the daemon returned the existing row.
* `{"ok": true, "daemon_paused": true, "pause_reason": "captcha"}` — your row is queued but won't run until the human clears the captcha; check back later.

If anything else fails, **do not improvise**. Report the situation on your Paperclip issue and stop.
