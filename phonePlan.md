# Melodi — Android Plan (Android 13+)

## Architecture Decisions

- **Min SDK**: 33 (Android 13+) — uses `READ_MEDIA_AUDIO`, avoids legacy storage complexity
- **Download server**: VPS (always-on), both Linux desktop AND Android use it — one code path, simpler
- **Server language**: Python (FastAPI) — yt-dlp is already Python, minimal boilerplate
- **Audio**: Migrate `audioplayers` → `just_audio` + `audio_service` for background playback + lock screen controls
- **No iOS support**

---

## Phase 1 — Android platform setup
*Blocks all other phases*

1. Run `flutter create --platforms android .` to generate the `android/` folder
2. In `android/app/build.gradle`: set `minSdkVersion 33`, `targetSdkVersion 34`
3. In `AndroidManifest.xml` add permissions:
   - `INTERNET`
   - `READ_MEDIA_AUDIO`
   - `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
   - `POST_NOTIFICATIONS` — **mandatory on Android 13+**; without it the media playback notification silently fails to appear
4. Install Android NDK in Android Studio — required by `metadata_god` (Rust/Cargokit)
   - First build compiles Rust: takes 20–40 min, subsequent builds use cache
5. Add `permission_handler` to pubspec.yaml
6. In app startup (before audio service initializes): request `Permission.notification` and `Permission.audio` using `permission_handler`
7. In `library_page.dart` (`_pickAndScan`): request `READ_MEDIA_AUDIO` permission before scanning on Android

---

## Phase 2 — SQLite conditional init
*Parallel with Phase 3–6 after Phase 1*

Currently uses `sqflite_common_ffi` everywhere. Android needs plain `sqflite`.

- `main.dart`: wrap `sqfliteFfiInit()` in `if (!Platform.isAndroid)`
- `database_helper.dart`: use `databaseFactoryFfi.openDatabase` on desktop, plain `openDatabase` on Android

---

## Phase 3 — Background audio service
*Parallel after Phase 1. **HIGH risk** — do on a separate git branch and merge last, after all other phases are verified.*

`audioplayers` has no notification or lock-screen controls on Android.

**Migration: `audioplayers` → `just_audio` + `audio_service`**

**Step 1 — Migrate to `just_audio` first (no background isolate yet)**
- Swap `audioplayers` for `just_audio`; verify all playback, queue, shuffle, loop, and seek logic works on both Linux and Android before proceeding
- Do not add `audio_service` until this step is confirmed stable

**Step 2 — Design the isolate communication bridge**
`audio_service` runs `MelodiAudioHandler` in a background Dart isolate. Isolates do not share memory, so the handler cannot directly access the SQLite DB, `ChangeNotifier`/`Provider` state, or the scanner service. Chosen approach:
- **Play count & recent_items**: open a second SQLite connection inside the background isolate (SQLite supports multiple connections from separate isolates when WAL mode is enabled). The background handler calls `DatabaseHelper` directly — no message passing needed.
- **Album art**: pass the file path in `MediaItem.extras` when playback starts; the background isolate reads the file bytes directly from disk.
- **Provider state sync**: the background handler fires `audio_service` custom events (`customEvent`) back to the main isolate for any UI-state updates (e.g. notifying `PlayerProvider` of song changes).

Document and review this design before writing any code.

**Step 3 — Wrap with `audio_service`**
- Remove `audioplayers`, add `just_audio: ^0.9.x` and `audio_service: ^0.18.x`
- `just_audio` uses GStreamer on Linux — desktop is unaffected
- Rewrite `player_provider.dart` as a `BaseAudioHandler` subclass (`MelodiAudioHandler`) following the bridge design from Step 2:
  - All existing logic is preserved: manual queue, `_source`/`_sourceIndex`, shuffle, loop, `_sourceName`, play count tracking
  - `playFromSource()`, `addToQueue()`, `next()`, `previous()`, `seek()` map directly to `just_audio` equivalents
  - `audio_service` wraps the handler in a background isolate and provides:
    - Android notification with play/pause/next/prev controls
    - Lock screen / Bluetooth headset controls
    - `MediaSession` metadata (title, artist, album art)
- `main.dart`: wrap root widget in `AudioServiceWidget`
- A thin `PlayerProvider` ChangeNotifier wraps `MelodiAudioHandler` to keep the same UI interface

---

## Phase 4 — Remote download server
*Fully independent — can be built before any Flutter work*

**FastAPI server** (runs on VPS, ~60 lines of Python):

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/search?q=<query>&limit=20` | Calls `yt-dlp ytsearch20:<q> --flat-playlist --dump-single-json`, returns JSON array |
| `POST` | `/download` body `{"url": "..."}` | Calls `yt-dlp --audio-quality 5 -x --audio-format mp3`, streams mp3 back with headers `X-Title`, `X-Artist` |

### Auth
- `X-Api-Key: <secret>` header on every request
- Key stored in server `.env` file (not in repo)

### Rate limiting
- Max 10 requests per minute per API key (use `slowapi` with an in-memory counter)
- Requests exceeding the limit receive HTTP 429

### Logging
- Log each request: timestamp, endpoint, client IP, API key prefix (first 6 chars), success/failure
- Write to a rotating log file (`logging.handlers.RotatingFileHandler`, max 5 MB × 3 files)

### Deployment
- Run as `systemd` service on VPS, listen on port 8080
- **Strongly recommended**: use [Tailscale](https://tailscale.com) or WireGuard as a zero-trust overlay instead of exposing port 8080 to the internet. Both the VPS and the phone join the same private mesh — no open ports, no API key needed, no rate limiting needed. This is simpler and more secure.
- If exposing to the internet directly: put behind nginx with HTTPS and keep the API key secret

---

## Phase 5 — HTTP download client
*Depends on Phase 4*

Replace `Process.run` / `Process.start` in `yt_dlp_service.dart` for **both platforms**:

- Add `http` (or `dio`) to pubspec.yaml
- Rewrite `yt_dlp_service.dart`:
  - `search()`: `GET /search?q=...` → parse same JSON shape as today
  - `downloadMp3()`: `POST /download` → stream response body to file in music folder, call `onProgress` with byte count
- Remove all `Process.run` / `Process.start` / `dart:io` Process usage from the file
- Store server base URL + API key in `SharedPreferences` (user sets once in a Settings screen, or hard-coded constant for initial release)

---

## Phase 6 — Responsive UI
*Parallel after Phase 1*

Desktop UI assumes wide screen. Use `MediaQuery.of(context).size.width < 600` breakpoint.

| Screen | Desktop (≥ 600px) | Mobile (< 600px) |
|---|---|---|
| Library grid | 4 columns | 2 columns |
| Home shelf cards | 160px wide | 130px wide |
| Playlist detail | wide table | compact list |
| Mini player | current | current (already compact) |
| Now Playing | current | current (full-screen) |

Files to update: `library_page.dart`, `home_page.dart`, `playlist_detail_page.dart`

---

## Phase 7 — Music folder on Android
*Parallel after Phase 1*

- Default music folder: `getExternalStorageDirectory()` + `/Music/Melodi/` via `path_provider` — auto-set on first launch if no folder saved
- `FilePicker.getDirectoryPath()` works on Android 13 via SAF — keep for user override
- Downloaded files go to same folder; `scanner_service.dart` scans after each download (no change needed)

---

## Verification

1. `flutter build apk --debug` — succeeds, no Dart errors
2. Install on Android 13 device/emulator — app launches, Library tab loads
3. Scan a folder with MP3s — songs appear, metadata extracted correctly
4. Play a song, lock screen — music continues, notification shows controls
5. Search via remote server — results appear, download completes, song appears in Library
6. Add song to playlist, playlist cover loads on Home/Library

---

## Out of Scope (this phase)
- iOS support
- Artist detail page
- Offline server fallback
