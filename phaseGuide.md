I'm building a Flutter desktop app for a personal music player. 

# PHASE 1

Set up the main project structure with three bottom navigation tabs:
1. Library (home)
2. Search
3. Now Playing

Create empty placeholder pages for each. Use Material 3 theming with a dark mode look inspired by Spotify (dark grays, not pure black, with blue accent color #0b007f). 

The app title is "Melodi". Include a basic AppBar on the Library page that says "My Library". Just scaffold these pages with text placeholders. Do not add any actual functionality yet.

Important: Target the Linux desktop platform specifically. Ensure linux deployment is configured in the project setup.


# PHASE 2

Extend the Flutter app. On the Library page, I need a local music scanner.

Add a button "Choose Music Folder" that uses file_picker to let me select a directory. Once selected, recursively scan that folder for all .mp3 files. 

For each file, extract metadata using a suitable package: track title, artist, album, and album art if embedded. Display them in a ListView with a Spotify-like layout: album art on the left (use a placeholder icon if none found), title and artist to the right.

Cache the scanned library to a local SQLite database so it persists between app restarts. Only re-scan when the user manually triggers it.

I need the full code for:
- The file picker integration
- The metadata extraction logic
- The database schema and read/write functions
- The ListView UI with album art and text


# PHASE 3

Add music playback to the Flutter app.

When I tap a song in the library ListView, it should start playing using the audio_service package or just_audio. Build a Spotify-style mini-player bar that appears above the bottom navigation, showing the album art, track title, artist, and play/pause button. 

Tapping the mini-player should navigate to the full Now Playing page, which has:
- Large album art centered
- Track title and artist
- A seekable progress slider (current time / total duration)
- Previous, Play/Pause, Next buttons
- The background color dynamically extracted from the album art's dominant color

The player must continue playing when I navigate between tabs. Keep the playback logic in a state management solution (Provider or Riverpod) so it's accessible globally.

Provide the full code for the player service, the mini-player widget, and the Now Playing page.


# PHASE 4

Build the search and download functionality.

On the Search page, add a TextField that performs a YouTube search as the user types. Use the yt-dlp command-line tool to do the search (run it as a process with the flat_search or youtube:search prefix). Display results in a list with thumbnail, title, channel name, and duration.

Add a download icon on each result. When tapped, use yt-dlp to download the best audio, extract it as MP3, and save it to the user's chosen music folder. Show a progress indicator during download. 

Once downloaded, trigger a re-scan of the library so it appears in the Library tab immediately without manually refreshing.

Also, tag the downloaded MP3 with proper metadata fetched from yt-dlp (title, artist) and embed the thumbnail as album art. Add a "bulk download" mode where I can select multiple results and download them sequentially.

Write the full code for:
- The search query to yt-dlp
- The download pipe with progress
- The metadata embedding
- The library refresh triggerBuild the search and download functionality.

On the Search page, add a TextField that performs a YouTube search as the user types. Use the yt-dlp command-line tool to do the search (run it as a process with the flat_search or youtube:search prefix). Display results in a list with thumbnail, title, channel name, and duration.

Add a download icon on each result. When tapped, use yt-dlp to download the best audio, extract it as MP3, and save it to the user's chosen music folder. Show a progress indicator during download. 

Once downloaded, trigger a re-scan of the library so it appears in the Library tab immediately without manually refreshing.

Also, tag the downloaded MP3 with proper metadata fetched from yt-dlp (title, artist) and embed the thumbnail as album art. Add a "bulk download" mode where I can select multiple results and download them sequentially.

Write the full code for:
- The search query to yt-dlp
- The download pipe with progress
- The metadata embedding
- The library refresh trigger


# PHASE 5

Add playlist creation and queue management.

I want to create playlists that are saved as .m3u files in a Playlists subfolder inside my music folder. In the Library tab, add a "Playlists" section at the top.

Long-press on any track to show a context menu with options:
- Add to Queue
- Add to Playlist (shows a list of existing playlists + create new)
- Delete File (moves to trash, don't permanently delete)

Build a Queue view accessible from the Now Playing page (a list icon in the top right). It shows the current queue, with drag-to-reorder functionality.

When the current song finishes, automatically play the next one in the queue. If the queue is empty, stop.

Provide the full code for playlist CRUD, the .m3u read/write service, the context menu, and the drag-and-drop queue UI.