# Melodi

A personal music player for Linux desktop, built with Flutter.

## Features

- Browse your local MP3 library
- Scan any folder recursively for MP3 files
- Displays track title, artist, album, and embedded album art
- Library persists between sessions (SQLite)

## Requirements

- Flutter 3.29+ with Linux desktop enabled
- Linux build dependencies: `clang cmake ninja-build pkg-config libgtk-3-dev`

## Setup

```bash
flutter pub get
flutter run -d linux
```

## Project Structure

```
lib/
  main.dart              # App entry point, theme, bottom nav
  pages/
    library_page.dart    # Music library UI + folder scanner
    search_page.dart     # Search (placeholder)
    now_playing_page.dart# Now Playing (placeholder)
  data/
    song_model.dart      # Song data class
    database_helper.dart # SQLite read/write
  services/
    scanner_service.dart # Recursive MP3 scanner + metadata extraction
```

