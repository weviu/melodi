Build the Home page for my Flutter desktop music app "Melodi". This replaces the placeholder Home tab. Implement a Spotify-style layout with recently played items and quick-access shelves.

COLOR SYSTEM (from shared theme):
- lilyDark (#0F2F6A): filled buttons, active icons
- lilyLight (#153A80): text links, hover overlays, gradient placeholders
- bgDark (#121212): page background
- bgSurface (#181818): card backgrounds
- textPrimary (#FFFFFF): titles, card names
- textSecondary (#B3B3B3): subtitles, labels
- hoverBg (#282828): hover state on cards

PAGE STRUCTURE (SingleChildScrollView):

1. STICKY HEADER (not in scroll, use a Column with the header outside the ScrollView):
   - Row with time-based greeting ("Good morning/afternoon/evening", 28px, bold, white) on the left
   - CircleAvatar on the right (radius 20), gradient background from lilyLight to lilyDark, white "U" text inside, acts as a placeholder user avatar
   - Divider below (1px, #282828)

2. RECENTLY PLAYED SHELF:
   - Section header: "Recently played" (white, 20px, bold) on the left. No "Show all" link needed—8 items is the full recent history.
   - Horizontal ListView of cards, 8 items max, loaded from local SQLite or shared preferences (a simple recent_items table tracking what the user played last, with item_type: "playlist" or "artist" and the item_id)
   - Each card (width 160):
     - ClipRRect with 6px borderRadius, Container color #181818
     - Square artwork (160x160). If item has artwork path, load it with Image.file. If not, show a gradient container (LinearGradient, begin topCenter, end bottomCenter, colors: [lilyLight, bgSurface]) with a centered icon: Icons.playlist_play (white, 32px) for playlists, Icons.person (white, 32px) for artists.
     - Padding(8) below artwork: title (white, 14px, bold, maxLines 1, TextOverflow.ellipsis)
     - Subtitle: "Playlist" or "Artist" (muted gray, 12px)
     - InkWell wrapping the card. onTap: navigate to that playlist's detail or artist's song list. onHover: container color shifts to hoverBg.
   - If recent_items table is empty: show "Nothing played yet. Start listening!" (muted gray, 14px, centered in a SizedBox height 200)

3. YOUR PLAYLISTS SHELF:
   - Section header Row: "Your playlists" (white, 20px, bold) + Spacer + "Show all" TextButton (lilyLight, 14px)
   - "Show all" onTap: switch to Library tab with Playlists filter active (use a callback or navigation)
   - Horizontal ListView of playlist cards (same 160px width card format as above)
   - Data source: the playlists table from SQLite, limited to 10 items
   - If no playlists exist, hide this entire shelf (use Visibility or if condition)

4. YOUR TOP ARTISTS SHELF:
   - Section header: "Your top artists" (white, 20px, bold)
   - Horizontal ListView of artist cards
   - Data source: query song play counts from the database, group by artist, order by SUM(play_count) DESC, limit 10
   - Each card (width 120):
     - CircleAvatar (radius 40) or ClipRRect with borderRadius 1000 for artwork. Fallback: lilyLight to lilyDark gradient circle with Icons.person.
     - Artist name below, centered, white, 13px, maxLines 1, ellipsis
     - "Artist" label below, centered, muted gray, 11px
   - onTap: navigate to a filtered library view showing that artist's songs
   - If the library has fewer than 5 distinct artists total, hide this shelf entirely

5. EMPTY STATE (if all shelves are empty: no recent items, no playlists, fewer than 5 artists):
   - Column centered, mainAxisAlignment center
   - Icon(Icons.music_note, size 64, color textSecondary)
   - SizedBox(height 16)
   - "Welcome to Melodi" (white, 24px, bold)
   - SizedBox(height 8)
   - "Search for songs and build your library" (muted gray, 16px)
   - SizedBox(height 24)
   - ElevatedButton with lilyDark background, white text "Go to Search"
   - onPressed: switch to the Search tab (index 1 in the bottom nav)

DATA PERSISTENCE:
- Create a new SQLite table: recent_items (id INTEGER PRIMARY KEY, item_type TEXT, item_id TEXT, played_at DATETIME DEFAULT CURRENT_TIMESTAMP)
- Update the playback service: whenever a song starts playing, if it belongs to a playlist, INSERT or UPDATE that playlist in recent_items. If it has an artist, do the same for the artist.
- Cap recent_items at 50 rows, deleting the oldest on insert.
- Add a play_count column to the songs table (INTEGER DEFAULT 0). Increment by 1 each time a song is played past 50% or 4 minutes.

BOTTOM NAVIGATION:
- Ensure the Home tab icon is active (filled home icon, lilyDark color) when on this page
- The mini-player bar at the bottom must still be visible and functional above the nav bar

Do not break: the Library tab, Search tab with yt-dlp, playback service, or the mini-player bar. All existing functionality must remain intact.

# this is the code:

<!DOCTYPE html>

<html class="dark" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Epilogue:wght@400;500;700;800;900&amp;family=Inter:wght@400;500;600;700&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<style>
        .material-symbols-outlined {
            font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
        }
        body {
            background-color: #121317;
            color: #e3e2e7;
        }
        /* Custom scrollbar for immersive feel */
        ::-webkit-scrollbar {
            width: 8px;
        }
        ::-webkit-scrollbar-track {
            background: #121317;
        }
        ::-webkit-scrollbar-thumb {
            background: #282828;
            border-radius: 4px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: #343439;
        }
    </style>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    "colors": {
                        "primary-fixed": "#d9e2ff",
                        "surface-container-lowest": "#0d0e12",
                        "inverse-surface": "#e3e2e7",
                        "inverse-on-surface": "#2f3035",
                        "surface-tint": "#b1c5ff",
                        "surface-container": "#1e1f24",
                        "on-surface-variant": "#c4c6d1",
                        "surface": "#121317",
                        "on-surface": "#e3e2e7",
                        "background": "#121317",
                        "on-tertiary-fixed": "#341100",
                        "on-primary-fixed-variant": "#294580",
                        "tertiary": "#ffb690",
                        "on-tertiary-fixed-variant": "#723611",
                        "on-tertiary-container": "#d6865b",
                        "tertiary-fixed": "#ffdbca",
                        "secondary-fixed-dim": "#b1c5ff",
                        "on-error-container": "#ffdad6",
                        "surface-bright": "#38393d",
                        "on-secondary-fixed": "#001946",
                        "tertiary-container": "#572200",
                        "primary-container": "#0f2f6a",
                        "on-secondary-container": "#9cb7ff",
                        "tertiary-fixed-dim": "#ffb690",
                        "on-primary-container": "#7f99da",
                        "secondary": "#b1c5ff",
                        "inverse-primary": "#425d9a",
                        "secondary-container": "#24468c",
                        "outline-variant": "#444650",
                        "outline": "#8e909b",
                        "surface-dim": "#121317",
                        "primary-fixed-dim": "#b1c5ff",
                        "on-primary": "#0c2d68",
                        "error": "#ffb4ab",
                        "on-secondary": "#002c70",
                        "surface-container-highest": "#343439",
                        "on-tertiary": "#552100",
                        "surface-container-high": "#292a2e",
                        "on-secondary-fixed-variant": "#21448a",
                        "primary": "#b1c5ff",
                        "on-primary-fixed": "#001946",
                        "on-background": "#e3e2e7",
                        "on-error": "#690005",
                        "surface-variant": "#343439",
                        "surface-container-low": "#1a1b20",
                        "error-container": "#93000a",
                        "secondary-fixed": "#dae2ff"
                    },
                    "borderRadius": {
                        "DEFAULT": "0.25rem",
                        "lg": "0.5rem",
                        "xl": "0.75rem",
                        "full": "9999px"
                    },
                    "spacing": {
                        "xl": "32px",
                        "gutter": "16px",
                        "base": "8px",
                        "lg": "24px",
                        "xxl": "48px",
                        "xs": "4px",
                        "sm": "8px",
                        "container-margin": "24px",
                        "md": "16px"
                    },
                    "fontFamily": {
                        "body-lg": ["Inter"],
                        "label-bold": ["Inter"],
                        "body-md": ["Inter"],
                        "display-lg": ["Epilogue"],
                        "headline-sm": ["Epilogue"],
                        "body-sm": ["Inter"],
                        "headline-md": ["Epilogue"],
                        "label-muted": ["Inter"]
                    },
                    "fontSize": {
                        "body-lg": ["18px", {"lineHeight": "1.6", "fontWeight": "400"}],
                        "label-bold": ["12px", {"lineHeight": "1", "letterSpacing": "0.05em", "fontWeight": "700"}],
                        "body-md": ["16px", {"lineHeight": "1.5", "fontWeight": "400"}],
                        "display-lg": ["48px", {"lineHeight": "1.1", "letterSpacing": "-0.02em", "fontWeight": "800"}],
                        "headline-sm": ["24px", {"lineHeight": "1.3", "fontWeight": "700"}],
                        "body-sm": ["14px", {"lineHeight": "1.4", "fontWeight": "400"}],
                        "headline-md": ["32px", {"lineHeight": "1.2", "letterSpacing": "-0.01em", "fontWeight": "700"}],
                        "label-muted": ["12px", {"lineHeight": "1", "fontWeight": "500"}]
                    }
                },
            },
        }
    </script>
</head>
<body class="font-body-md text-on-surface antialiased">
<!-- Top Navigation Bar -->
<header class="bg-[#181818]/95 backdrop-blur-md text-[#0F2F6A] dark:text-blue-500 docked full-width top-0 z-50 border-b border-[#282828] flat no shadows flex justify-between items-center px-6 py-4 w-full">
<div class="text-xl font-black text-white font-['Epilogue'] tracking-tight">Melodi</div>
<div class="flex items-center gap-4">
<button class="hover:bg-[#282828] transition-colors p-2 rounded-full flex items-center justify-center active:scale-95">
<span class="material-symbols-outlined text-white">add</span>
</button>
</div>
</header>
<div class="flex min-h-screen">
<!-- Side Navigation Bar (Desktop) -->
<!-- Main Content Area -->
<main class="flex-1 pt-24 pb-32 px-gutter md:px-lg lg:px-xxl mx-auto max-w-7xl">
<!-- Header Section -->
<div class="flex flex-col md:flex-row md:items-center justify-between mb-xl gap-md">
<h2 class="font-headline-sm text-headline-sm text-white">Your Library</h2>
<div class="flex items-center gap-sm">
<button class="px-md py-xs rounded-full bg-white text-surface font-label-bold text-label-bold transition-all active:scale-95">
                        Playlists
                    </button>
<button class="px-md py-xs rounded-full border border-outline text-white font-label-bold text-label-bold hover:bg-[#282828] transition-all active:scale-95">
                        Artists
                    </button>
<button class="p-2 rounded-full hover:bg-[#282828] transition-colors text-white">
<span class="material-symbols-outlined">add</span>
</button>
</div>
</div>
<!-- Bento-style Grid Layout -->
<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-gutter">
<!-- Playlist Card 1 -->
<div class="group bg-surface-container p-md rounded-lg transition-all duration-300 hover:bg-[#282828] cursor-pointer">
<div class="relative aspect-square mb-md overflow-hidden rounded-lg bg-gradient-to-br from-primary-container to-surface-container-lowest flex items-center justify-center">
<span class="material-symbols-outlined text-4xl text-on-primary-container">music_note</span>
<div class="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
<div class="w-12 h-12 bg-primary-container rounded-full flex items-center justify-center shadow-lg transform translate-y-4 group-hover:translate-y-0 transition-transform">
<span class="material-symbols-outlined text-white" data-weight="fill">play_arrow</span>
</div>
</div>
</div>
<h3 class="font-label-bold text-white text-body-sm truncate mb-xs">Late Night Focus</h3>
<p class="font-label-muted text-label-muted text-gray-500">Playlist • 48 songs</p>
</div>
<!-- Artist Card 1 -->
<div class="group bg-surface-container p-md rounded-lg transition-all duration-300 hover:bg-[#282828] cursor-pointer">
<div class="relative aspect-square mb-md overflow-hidden rounded-full border-2 border-transparent group-hover:border-primary-container transition-all">
<img alt="Artist Portrait" class="w-full h-full object-cover" data-alt="A professional studio portrait of a soulful jazz musician with warm amber lighting. The artist is holding a saxophone against a dark, moody charcoal background with soft bokeh effects. The overall aesthetic is elegant, minimal, and premium, reflecting the high-fidelity sound of the Melodi platform." src="https://lh3.googleusercontent.com/aida-public/AB6AXuDGV7GgBuWciZOFz6DqasA2ICrnUAGbCQAqqCWOydWtMHA5_2Ac9yIJVjn6t23nps9n18AzME2wCmZ_VECAJbZdvfp6pbN8qXBog8TX4Hl2F8FEDiogFss0Tw_ckEy7jt7laZr-Wj9G5-4uH-bb0e1hSUmB63fTYfxn3ksKxdKXWCgU_j3U9gKCS4mDIwCtmwwiBA_m1JdtWDkHTejMEsNlIO3OzBpt47kW5a4dZ7afHzCwWMVVk772HG0MNIxpUj9sTaIpOkj-4FA"/>
</div>
<h3 class="font-label-bold text-white text-body-sm truncate mb-xs">The Midnight Echo</h3>
<p class="font-label-muted text-label-muted text-gray-500 text-center">Artist</p>
</div>
<!-- Playlist Card 2 -->
<div class="group bg-surface-container p-md rounded-lg transition-all duration-300 hover:bg-[#282828] cursor-pointer">
<div class="relative aspect-square mb-md overflow-hidden rounded-lg bg-gradient-to-br from-[#0F2F6A] to-[#121317] flex items-center justify-center">
<span class="material-symbols-outlined text-4xl text-primary">favorite</span>
</div>
<h3 class="font-label-bold text-white text-body-sm truncate mb-xs">Liked Songs</h3>
<p class="font-label-muted text-label-muted text-gray-500">Playlist • 1,204 songs</p>
</div>
<!-- Artist Card 2 -->
<div class="group bg-surface-container p-md rounded-lg transition-all duration-300 hover:bg-[#282828] cursor-pointer">
<div class="relative aspect-square mb-md overflow-hidden rounded-full border-2 border-transparent group-hover:border-primary-container transition-all">
<img alt="Artist Portrait" class="w-full h-full object-cover" data-alt="A minimalist overhead shot of high-end vintage audio equipment, featuring a turntable needle resting on a vinyl record. The lighting is low-key with sharp cyan highlights, creating a sophisticated nocturnal atmosphere. The image communicates a deep passion for high-fidelity audio and artisanal music production." src="https://lh3.googleusercontent.com/aida-public/AB6AXuAvRvaC_Ge8xV-sbFKx5ULvSVjFlkzd7O8VvT-9mVcUyc-SJ3HprLGGuOtRHh3EXlju1rE6NsD0h668s_boYCfr-Bf6T8HKc-Pe9g_1HpeoHhO2Cmy_M9zQ-eENs8X1iBuin4i3bMSl9XSAPph3Z6dNjG91TpjKDK38MWNysf9wmPJxvgNGwSKYFlGNYIvyfEJVoQ3g8zsR1DZJNCXGChIVlHkyG4PFZ8k7NJmGrDu4fAqGuwCZEC0hwZMgiI_1sgsCQiHWFpiCJCI"/>
</div>
<h3 class="font-label-bold text-white text-body-sm truncate mb-xs">Ethereal Beats</h3>
<p class="font-label-muted text-label-muted text-gray-500 text-center">Artist</p>
</div>
<!-- Playlist Card 3 -->
<div class="group bg-surface-container p-md rounded-lg transition-all duration-300 hover:bg-[#282828] cursor-pointer">
<div class="relative aspect-square mb-md overflow-hidden rounded-lg bg-gradient-to-tr from-[#153A80] to-[#181818] flex items-center justify-center">
<span class="material-symbols-outlined text-4xl text-on-primary-container">auto_awesome</span>
</div>
<h3 class="font-label-bold text-white text-body-sm truncate mb-xs">Deep Techno Journey</h3>
<p class="font-label-muted text-label-muted text-gray-500">Playlist • 24 songs</p>
</div>
<!-- Playlist Card 4 -->
<div class="group bg-surface-container p-md rounded-lg transition-all duration-300 hover:bg-[#282828] cursor-pointer">
<div class="relative aspect-square mb-md overflow-hidden rounded-lg bg-gradient-to-bl from-[#0c2d68] to-[#294580] flex items-center justify-center">
<span class="material-symbols-outlined text-4xl text-white">album</span>
</div>
<h3 class="font-label-bold text-white text-body-sm truncate mb-xs">Ambient Rain</h3>
<p class="font-label-muted text-label-muted text-gray-500">Playlist • 112 songs</p>
</div>
</div>
</main>
</div>
<!-- Bottom Navigation Bar (Mobile Only) -->
<footer class="md:hidden fixed bottom-0 w-full z-50 border-t border-[#282828] bg-[#181818] shadow-[0_-4px_10px_rgba(0,0,0,0.3)] flex justify-around items-center h-16 pb-safe">
<a class="flex flex-col items-center justify-center text-gray-500 hover:text-gray-200" href="#">
<span class="material-symbols-outlined">home</span>
<span class="font-['Epilogue'] text-[10px] font-bold uppercase tracking-wider mt-1">Home</span>
</a>
<a class="flex flex-col items-center justify-center text-gray-500 hover:text-gray-200" href="#">
<span class="material-symbols-outlined">search</span>
<span class="font-['Epilogue'] text-[10px] font-bold uppercase tracking-wider mt-1">Search</span>
</a>
<a class="flex flex-col items-center justify-center text-[#0F2F6A] scale-110" href="#">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1;">library_music</span>
<span class="font-['Epilogue'] text-[10px] font-bold uppercase tracking-wider mt-1">Library</span>
</a>
</footer>
<!-- Persistent Playback Bar (Floating Desktop Style) -->
<div class="hidden md:flex fixed bottom-md right-md bg-[#181818]/90 backdrop-blur-xl h-24 rounded-xl border border-[#282828] z-50 px-lg items-center justify-between shadow-2xl left-md mx-auto max-w-7xl">
<div class="flex items-center gap-md w-1/3">
<div class="w-14 h-14 rounded bg-primary-container overflow-hidden">
<img alt="Now Playing" class="w-full h-full object-cover" data-alt="Close up of a vibrant digital audio waveform in glowing electric blue and deep indigo colors. The visual is sharp and contemporary, representing high-quality digital streaming. The background is a clean, dark surface with subtle metallic reflections, aligning with the premium Melodi player branding." src="https://lh3.googleusercontent.com/aida-public/AB6AXuB2UPfm9UINOyvzotUBdSn3Zbq-WaIY7VUfXfFpWHx3xnk8piE_HKOychXIilQvogInJ8DfKQLQ5DTccSdAsZV2FDi4q33nfEBsergAUGKPEEUi3AcMPvgnnuHclJabnZAp8_wT1nSWGA6B0Zoxf-BMynG5R7cy1oaoL4qenqocmTXcYgIGiE3pse0Y5BXVUup-kC7-xH-YAZMaa09A6p5JBz7K_5Nz9jPIhpwZiWhhrTFRQwExU5MwDT01cC59FoDitXAW6ey-xeE"/>
</div>
<div>
<h4 class="text-white font-label-bold text-body-sm">Nocturnal Wanderer</h4>
<p class="text-gray-500 text-xs">The Midnight Echo</p>
</div>
</div>
<div class="flex flex-col items-center gap-xs w-1/3">
<div class="flex items-center gap-lg">
<button class="text-gray-400 hover:text-white transition-colors"><span class="material-symbols-outlined">shuffle</span></button>
<button class="text-gray-400 hover:text-white transition-colors"><span class="material-symbols-outlined">skip_previous</span></button>
<button class="w-10 h-10 bg-white text-black rounded-full flex items-center justify-center active:scale-90 transition-transform">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1;">play_arrow</span>
</button>
<button class="text-gray-400 hover:text-white transition-colors"><span class="material-symbols-outlined">skip_next</span></button>
<button class="text-gray-400 hover:text-white transition-colors"><span class="material-symbols-outlined">repeat</span></button>
</div>
<div class="w-full flex items-center gap-sm">
<span class="text-[10px] text-gray-500 font-mono">1:24</span>
<div class="flex-1 h-1 bg-[#282828] rounded-full overflow-hidden">
<div class="bg-primary-container h-full w-1/3 rounded-full"></div>
</div>
<span class="text-[10px] text-gray-500 font-mono">3:45</span>
</div>
</div>
<div class="flex items-center justify-end gap-md w-1/3">
<button class="text-gray-400 hover:text-white"><span class="material-symbols-outlined">lyrics</span></button>
<button class="text-gray-400 hover:text-white"><span class="material-symbols-outlined">queue_music</span></button>
<div class="flex items-center gap-xs">
<span class="material-symbols-outlined text-gray-400">volume_up</span>
<div class="w-24 h-1 bg-[#282828] rounded-full overflow-hidden">
<div class="bg-primary-container h-full w-2/3 rounded-full"></div>
</div>
</div>
</div>
</div>
</body></html>