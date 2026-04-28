import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import '../data/song_model.dart';
import '../services/player_provider.dart';
import '../services/playlist_provider.dart';
import '../widgets/mini_player.dart';
import 'now_playing_page.dart';
import '../widgets/mini_player.dart';
import 'now_playing_page.dart';

class PlaylistDetailPage extends StatefulWidget {
  final String playlistName;
  final List<Song> allSongs;

  const PlaylistDetailPage({
    super.key,
    required this.playlistName,
    required this.allSongs,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  List<Song> _songs = [];
  bool _loading = true;
  Color _dominantColor = const Color(0xFF1a1a2e);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await context
        .read<PlaylistProvider>()
        .getSongs(widget.playlistName, widget.allSongs);
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
    _extractColor(songs.isNotEmpty ? songs.first.albumArt : null);
  }

  Future<void> _extractColor(Uint8List? artBytes) async {
    if (artBytes == null) return;
    try {
      final pg = await PaletteGenerator.fromImageProvider(
        MemoryImage(artBytes),
        maximumColorCount: 8,
      );
      final color = pg.dominantColor?.color ??
          pg.vibrantColor?.color ??
          const Color(0xFF1a1a2e);
      if (mounted) setState(() => _dominantColor = color);
    } catch (_) {}
  }

  Future<void> _remove(int index) async {
    final removed = _songs[index];
    final before = List<Song>.from(_songs);
    setState(() => _songs = List<Song>.from(_songs)..removeAt(index));
    await context
        .read<PlaylistProvider>()
        .removeSong(widget.playlistName, index, before);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${removed.title}" removed'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _playAll(BuildContext context) {
    if (_songs.isEmpty) return;
    context.read<PlayerProvider>().playFromSource(
          _songs.first,
          source: _songs,
          index: 0,
          sourceName: widget.playlistName,
        );
  }

  void _shufflePlay(BuildContext context) {
    if (_songs.isEmpty) return;
    final player = context.read<PlayerProvider>();
    if (!player.isShuffled) player.toggleShuffle();
    player.playFromSource(
      _songs.first,
      source: _songs,
      index: 0,
      sourceName: widget.playlistName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      bottomNavigationBar: MiniPlayer(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NowPlayingPage()),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(context),
                if (_songs.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.queue_music,
                              size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text('No songs yet',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 16)),
                          SizedBox(height: 8),
                          Text(
                              'Right-click songs in the library to add them',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _SongRow(
                        song: _songs[index],
                        trackNumber: index + 1,
                        onTap: () => context
                            .read<PlayerProvider>()
                            .playFromSource(
                              _songs[index],
                              source: _songs,
                              index: index,
                              sourceName: widget.playlistName,
                            ),
                        onRemove: () => _remove(index),
                        onAddToQueue: () => context
                            .read<PlayerProvider>()
                            .addToQueue(_songs[index]),
                      ),
                      childCount: _songs.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final coverArt = _songs.isNotEmpty ? _songs.first.albumArt : null;

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: _dominantColor.withAlpha(230),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.playlistName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _SmallPlayButton(onTap: () => _playAll(context)),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _PlaylistHeader(
          name: widget.playlistName,
          songCount: _songs.length,
          coverArt: coverArt,
          dominantColor: _dominantColor,
          onPlay: () => _playAll(context),
          onShuffle: () => _shufflePlay(context),
        ),
      ),
    );
  }
}

// ── Gradient header ────────────────────────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  final String name;
  final int songCount;
  final Uint8List? coverArt;
  final Color dominantColor;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  const _PlaylistHeader({
    required this.name,
    required this.songCount,
    required this.coverArt,
    required this.dominantColor,
    required this.onPlay,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.7, 1.0],
          colors: [
            dominantColor.withAlpha(230),
            dominantColor.withAlpha(120),
            const Color(0xFF121212),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover art
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(130),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: coverArt != null
                        ? Image.memory(coverArt!, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFF282828),
                            child: const Icon(Icons.queue_music,
                                size: 64, color: Colors.white24),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'PLAYLIST',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              Text(
                '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),

              const SizedBox(height: 16),

              // Action row
              Row(
                children: [
                  GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1DB954),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.black, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Consumer<PlayerProvider>(
                    builder: (_, player, __) => IconButton(
                      iconSize: 28,
                      icon: Icon(
                        Icons.shuffle,
                        color: player.isShuffled
                            ? const Color(0xFF6060ff)
                            : Colors.white70,
                      ),
                      tooltip: 'Shuffle play',
                      onPressed: onShuffle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact play button shown in collapsed app bar ─────────────────────────

class _SmallPlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SmallPlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFF1DB954),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow, color: Colors.black, size: 20),
      ),
    );
  }
}

// ── Song row ───────────────────────────────────────────────────────────────

class _SongRow extends StatelessWidget {
  final Song song;
  final int trackNumber;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onAddToQueue;

  const _SongRow({
    required this.song,
    required this.trackNumber,
    required this.onTap,
    required this.onRemove,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.currentSong?.filePath == song.filePath;
    final isPlaying = isCurrent && player.isPlaying;

    return GestureDetector(
      onSecondaryTap: () => _showContextMenu(context),
      onLongPress: () => _showContextMenu(context),
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.white.withAlpha(13),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Track number or speaker icon
              SizedBox(
                width: 28,
                child: isPlaying
                    ? const Icon(Icons.volume_up,
                        color: Color(0xFF1DB954), size: 16)
                    : Text(
                        '$trackNumber',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isCurrent
                              ? const Color(0xFF1DB954)
                              : Colors.white54,
                          fontSize: 14,
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              // Album art thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: song.albumArt != null
                      ? Image.memory(song.albumArt!, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFF282828),
                          child: const Icon(Icons.music_note,
                              color: Colors.white24, size: 20),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // Title + artist + album
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF1DB954)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${song.artist}${song.album.isNotEmpty ? ' • ${song.album}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: song.albumArt != null
                          ? Image.memory(song.albumArt!, fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFF383838),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white24, size: 22),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text(song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading:
                  const Icon(Icons.add_to_queue, color: Colors.white70),
              title: const Text('Add to Queue',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                onAddToQueue();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${song.title}" added to queue'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline,
                  color: Colors.red),
              title: const Text('Remove from playlist',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
