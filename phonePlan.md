# Melodi — Android / Mobile Plan

## Decision: Remote Server for Downloads

The download feature (yt-dlp) will run on the existing remote Linux server.
The Android app sends a YouTube URL to the server via HTTP, the server downloads
and converts the file, then streams it back to the phone.

### Why remote server (not on-device):
- yt-dlp / ffmpeg are desktop CLI tools — can't run on Android
- Avoids ~30MB APK size increase from bundling ffmpeg_kit_flutter
- Server has fast internet — downloads are likely faster than the phone would manage directly
- yt-dlp stays up to date server-side, no app updates needed for YouTube changes
- Works for iOS too if we ever go there

---

## Server API Plan

**Endpoint:** `POST /download`
**Auth:** `X-Api-Key: <secret>` header (keep key out of version control)
**Body:** `{ "url": "https://youtube.com/watch?v=..." }`
**Response:** audio file streamed back (mp3/m4a), same quality settings as desktop
  (`--audio-quality 5 --concurrent-fragments 4`)

Server-side language: TBD (Dart `shelf`, Python Flask, or similar — small wrapper around yt-dlp)
Port: TBD (e.g. 8080), needs to be open in firewall

---

## Flutter Migration Steps (when ready)

1. `flutter create --platforms android .` — adds Android support
2. Swap `sqflite_common_ffi` → `sqflite` in pubspec.yaml + main.dart (one-liner)
3. Add permissions to `android/app/src/main/AndroidManifest.xml`:
   - `READ_MEDIA_AUDIO` (Android 13+) or `READ_EXTERNAL_STORAGE` (older)
4. Install Android NDK — required by `metadata_god` (Rust/Cargokit)
5. Replace hardcoded file paths with `path_provider` (e.g. `getApplicationDocumentsDirectory()`)
6. Replace yt-dlp local call in `yt_dlp_service.dart` with HTTP call to remote server
7. Layout pass — current UI is desktop-width; add responsive breakpoints or a phone-specific layout

---

## Packages to add for Android

| Package | Purpose |
|---|---|
| `http` or `dio` | HTTP calls to download server |
| `permission_handler` | Request storage / audio permissions at runtime |
| `path_provider` | Get correct file paths per platform |

---

## Notes

- `audioplayers` already supports Android — handles audio focus (pauses on calls) out of the box
- `palette_generator`, `provider`, `flutter_svg` all support Android with no changes
- `metadata_god` supports Android but first build is slow (compiles Rust via NDK)
- The yt-dlp download feature is the **only** part that needs a fundamentally different approach on mobile
- Everything else (UI, playback, playlists, queue) should work with minimal changes
