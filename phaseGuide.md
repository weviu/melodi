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


# PHASE 6 


### The Queue System

The queue is an ordered, editable list that dictates upcoming playback without disrupting the currently playing track.

- **Access the Queue**: Tapping the queue icon (three horizontal lines) in the Now Playing screen.
- **Visual Structure**: The queue is divided into two sections:
    - **Now Playing**: The current track, displayed at the top.
    - **Next Up**: Everything scheduled to play next, listed in order below.
- **Managing Tracks**:
    - **Reorder**: Long-press and drag a track by its handle (three lines on the right) to rearrange.
    - **Remove**: Swipe left on a track to delete it, or tap the selection circle and hit "Remove."
    - **Clear Queue**: A single button to wipe the entire "Next Up" list at once.
- **What Happens When It Ends**: Once the queue is exhausted, playback stops. Spotify's auto-recommendation preview that follows is something you'll skip entirely in your app—just silence.

---

### The Context Menu (Three Dots)

The context menu is the action hub for any song, album, or playlist.

- **Add to Queue**: Sends the track to the "Next Up" list. It's always available and is the most-used action.
- **Add to Playlist**: Opens a sub-menu of your playlists. Tap one to add the track, or use "New Playlist" at the top to create one on the spot.
- **Go to Artist**: Navigates directly to the artist's page.
- **Go to Album**: Navigates to the full album the track belongs to.
- **Like / Save**: A heart icon to save the track to your Liked Songs library.
- **Share**: Copy link or share to external apps.
- **Remove from This Playlist**: Only appears when viewing a track inside a playlist you own.
- **Hide Song**: For algorithm-generated playlists, tells Spotify never to play this track again in that specific playlist.


# PHASE 7

## The Main Playlist View

When you open a playlist, this is what you see:

### Header Area (top third of screen)

- **Gradient background** sampled from the playlist cover art's dominant colors, fading into the dark background below. It's subtle but gives each playlist a distinct personality.
- **Playlist cover art** on the left, about 200x200 pixels, with rounded corners (8px radius, not perfectly square), subtle drop shadow.
- **Playlist title** in bold, large type (around 28px). If it's a long name, it wraps to two lines max.
- **"Playlist" label** in all caps, small, above the title.
- **Creator name** below the title: "by username" with a small avatar. Tapping the name goes to their profile.
- **Song count and total duration** in a muted, smaller font: "72 songs, 4 hr 28 min"
- **Action row** directly below the metadata:
  - Green play button (large, circular, #1DB954)
  - Shuffle button (white, smaller, interlocking arrows icon)
  - Download toggle (down arrow in a circle, turns green when downloaded)
  - Three-dot overflow menu (•••) — share, edit, make collaborative, etc.

### Song List (below the header)

- A **sticky header row** with column labels: #, Title, Artist, Album, Duration, and a clock icon for duration. This row disappears as you scroll down (replaced by the track list), but the header area collapses elegantly.
- **Each row** is about 56px tall, with a subtle hover highlight (light gray overlay on desktop, none on mobile).
- **Row layout (left to right):**
  - Track number (muted, 16px, right-aligned)
  - Album art thumbnail (40x40, 4px rounded corners)
  - Title and artist stacked vertically. Title in white, artist in muted gray (smaller, 14px). If the track is "explicit," there's a tiny "E" badge.
  - Album name (muted, truncated with ellipsis if too long)
  - Duration (muted, right-aligned)
- **Currently playing track** is highlighted: title turns Spotify green, and a small green speaker icon (equalizer bars) replaces the track number.
- **Long press / right-click** on a track opens a context menu: Add to Queue, Add to Playlist, Go to Artist, Go to Album, Remove from Playlist, Share.

### Sticky Playlist Header (as you scroll)

When you scroll down past the header, a slim version pins to the top:
- Playlist name (truncated) on the left
- Green play button (small) on the right
- Background blurs slightly (frosted glass effect)

---

## The Now Playing Screen

This is the screen you see when actively listening, with the large album art.

### Layout (top to bottom)

- **Collapse handle** — a tiny gray pill shape at the very top, indicating you can swipe down to minimize.
- **Album art** dominates the center. It's large (around 300x300), with a subtle drop shadow and rounded corners. It sits inside the full area, not edge-to-edge.
- **Track title** below the art, bold, around 22px, one line.
- **Artist name** below the title, linked (tappable), slightly smaller, muted.
- **Progress bar** — a slim horizontal slider. The played portion is white (or green on premium), the remaining is dark gray. Current time on the left, total duration on the right, both in tiny monospace font.
- **Playback controls** — centered row:
  - Shuffle (small, left)
  - Previous (medium)
  - Play/Pause (largest, white circle with green play button on desktop; green border on mobile)
  - Next (medium)
  - Repeat (small, right). If repeat-one is active, a tiny "1" badge appears.
- **Action row** below controls:
  - Heart/like button (green outline when liked, filled green when tapped)
  - Add to playlist (plus icon)
  - Queue icon (three stacked lines)
  - Share / Connect to device (varies by platform)
- **Lyrics / Now Playing View toggle** — swiping left on the album art reveals synced lyrics (if available). Swiping right goes back to art.
- **Background** — the dominant color of the album art, heavily blurred and darkened, fills the entire screen. It transitions smoothly when the track changes.

### Subtle Animations

- The play/pause button morphs smoothly (scale and icon change).
- The progress bar glows slightly at the playhead.
- Background color transitions over ~1 second when the next song starts.
- Shuffle/repeat icons have a slight green tint and glow when active.
