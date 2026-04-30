import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../data/song_model.dart';
import '../services/m3u_service.dart';
import '../services/music_folder_provider.dart';
import '../services/player_provider.dart';
import '../services/playlist_provider.dart';
import '../theme.dart';
import 'playlist_detail_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToSearch;
  final VoidCallback onGoToLibrary;

  const HomePage({
    super.key,
    required this.onGoToSearch,
    required this.onGoToLibrary,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _db = DatabaseHelper();
  final _m3u = M3uService();

  List<Map<String, dynamic>> _recentItems = [];
  Map<String, Uint8List?> _recentArtCache = {};
  List<Map<String, dynamic>> _topArtists = [];
  Map<String, Uint8List?> _artistArtCache = {};
  Map<String, Uint8List?> _playlistArtCache = {};
  int _distinctArtistCount = 0;
  bool _loading = true;

  Song? _lastTrackedSong;
  late final PlayerProvider _player;
  late final PlaylistProvider _playlists;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerProvider>();
    _playlists = context.read<PlaylistProvider>();
    _player.addListener(_onPlayerChanged);
    _playlists.addListener(_onPlaylistsChanged);
    _loadData();
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _playlists.removeListener(_onPlaylistsChanged);
    super.dispose();
  }

  void _onPlaylistsChanged() {
    if (!mounted) return;
    _loadData();
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    if (_player.currentSong?.filePath != _lastTrackedSong?.filePath) {
      _lastTrackedSong = _player.currentSong;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    // These reads happen synchronously before any await — safe in async context
    final folder = context.read<MusicFolderProvider>().folder;
    final playlists = context.read<PlaylistProvider>().playlists;

    final recent = await _db.getRecentItems();
    // Only show playlists in recently played (artist detail page not yet implemented)
    final recentPlaylists =
        recent.where((i) => i['item_type'] == 'playlist').toList();

    // Preload artwork for recent items
    final recentArt = <String, Uint8List?>{};
    for (final item in recentPlaylists) {
      final type = item['item_type'] as String;
      final id = item['item_id'] as String;
      final key = '$type:$id';
      if (folder != null) {
        final path = await _m3u.coverPath(folder, id);
        if (path != null) {
          try {
            recentArt[key] = await File(path).readAsBytes();
          } catch (_) {}
        }
      }
    }

    // Preload playlist artwork (first 10)
    final playlistArt = <String, Uint8List?>{};
    if (folder != null) {
      for (final name in playlists.take(10)) {
        final path = await _m3u.coverPath(folder, name);
        if (path != null) {
          try {
            playlistArt[name] = await File(path).readAsBytes();
          } catch (_) {}
        }
      }
    }

    // Top artists + artwork
    final artists = await _db.getTopArtists();
    final artistArt = <String, Uint8List?>{};
    for (final a in artists) {
      final name = a['artist'] as String;
      final song = await _db.getSongWithArtByArtist(name);
      artistArt[name] = song?.albumArt;
    }

    final artistCount = await _db.getDistinctArtistCount();

    if (!mounted) return;
    setState(() {
      _recentItems = recentPlaylists;
      _recentArtCache = recentArt;
      _topArtists = artists;
      _artistArtCache = artistArt;
      _playlistArtCache = playlistArt;
      _distinctArtistCount = artistCount;
      _loading = false;
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>().playlists;
    final hasRecent = _recentItems.isNotEmpty;
    final hasPlaylists = playlists.isNotEmpty;
    final hasArtists = _distinctArtistCount >= 5;
    final allEmpty = !hasRecent && !hasPlaylists && !hasArtists;

    return Scaffold(
      backgroundColor: kBgDark,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kLilyLight))
          : allEmpty
              ? _buildEmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const Divider(color: Color(0xFF282828), height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasRecent) ...[
                              const _ShelfHeader(title: 'Recently played'),
                              _buildRecentShelf(),
                            ],
                            if (hasPlaylists) ...[
                              _ShelfHeader(
                                title: 'Your playlists',
                                actionLabel: 'Show all',
                                onAction: widget.onGoToLibrary,
                              ),
                              _buildPlaylistsShelf(playlists),
                            ],
                            if (hasArtists) ...[
                              const _ShelfHeader(title: 'Your top artists'),
                              _buildArtistsShelf(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Row(
          children: [
            Text(
              _greeting,
              style: const TextStyle(
                color: kTextPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            CircleAvatar(
              radius: 20,
              backgroundColor: kLilyLight,
              child: const Text(
                'U',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentShelf() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        itemCount: _recentItems.length,
        itemBuilder: (context, i) {
          final item = _recentItems[i];
          final type = item['item_type'] as String;
          final id = item['item_id'] as String;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HomeCard(
              type: type,
              id: id,
              art: _recentArtCache['$type:$id'],
              onTap: () => _onRecentTap(type, id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsShelf(List<String> playlists) {
    final display = playlists.take(10).toList();
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        itemCount: display.length,
        itemBuilder: (context, i) {
          final name = display[i];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HomeCard(
              type: 'playlist',
              id: name,
              art: _playlistArtCache[name],
              onTap: () => _onPlaylistTap(name),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistsShelf() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        itemCount: _topArtists.length,
        itemBuilder: (context, i) {
          final name = _topArtists[i]['artist'] as String;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ArtistCard(
              name: name,
              art: _artistArtCache[name],
              onTap: widget.onGoToLibrary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, size: 64, color: kTextSecondary),
            const SizedBox(height: 16),
            const Text(
              'Welcome to Melodi',
              style: TextStyle(
                color: kTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for songs and build your library',
              style: TextStyle(color: kTextSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onGoToSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLilyDark,
                foregroundColor: kTextPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Go to Search'),
            ),
          ],
        ),
      ),
    );
  }

  void _onRecentTap(String type, String id) {
    if (type == 'playlist') {
      _onPlaylistTap(id);
    } else {
      widget.onGoToLibrary();
    }
  }

  Future<void> _onPlaylistTap(String name) async {
    final songs = await _db.getAllSongs();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailPage(
          playlistName: name,
          allSongs: songs,
        ),
      ),
    );
    if (mounted) _loadData();
  }
}

// ── Shelf header ───────────────────────────────────────────────────────────

class _ShelfHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ShelfHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (actionLabel != null) ...[
            const Spacer(),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(color: kLilyLight, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Home card (160px wide — recent items + playlists) ─────────────────────

class _HomeCard extends StatefulWidget {
  final String type;
  final String id;
  final Uint8List? art;
  final VoidCallback onTap;

  const _HomeCard({
    required this.type,
    required this.id,
    required this.art,
    required this.onTap,
  });

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 160,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? kHoverBg : kBgSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 144,
                  height: 144,
                  child: widget.art != null
                      ? Image.memory(widget.art!, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [kLilyLight, kBgSurface],
                            ),
                          ),
                          child: Icon(
                            widget.type == 'playlist'
                                ? Icons.playlist_play
                                : Icons.person,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.type == 'playlist' ? 'Playlist' : 'Artist',
                style: const TextStyle(color: kTextSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Artist card (120px wide, circular art) ────────────────────────────────

class _ArtistCard extends StatefulWidget {
  final String name;
  final Uint8List? art;
  final VoidCallback onTap;

  const _ArtistCard({
    required this.name,
    required this.art,
    required this.onTap,
  });

  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? kHoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(1000),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: widget.art != null
                      ? Image.memory(widget.art!, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [kLilyLight, kLilyDark],
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Artist',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
