import 'dart:typed_data';

import '../data/song_model.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import '../services/player_provider.dart';
import '../services/playlist_provider.dart';
import 'queue_page.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  Color _bgColor = const Color(0xFF191C23);
  Uint8List? _lastArtBytes;
  final FocusNode _focusNode = FocusNode();
  late final PlayerProvider _player;

  static const _accent = Color(0xFF1E4A9E);

  @override
  void initState() {
    super.initState();
    // Cache provider reference — safe to use in dispose() and listener callbacks
    // without touching `context` after deactivation.
    _player = context.read<PlayerProvider>();
    _player.addListener(_onPlayerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPlayerChanged();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      _player.togglePlayPause();
    }
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    final song = _player.currentSong;
    if (song?.albumArt != _lastArtBytes) {
      _lastArtBytes = song?.albumArt;
      _extractColor(song?.albumArt);
    }
  }

  Future<void> _extractColor(Uint8List? artBytes) async {
    if (artBytes == null) {
      if (mounted) setState(() => _bgColor = const Color(0xFF191C23));
      return;
    }
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        MemoryImage(artBytes),
        size: const Size(80, 80),
      );
      final color = generator.dominantColor?.color ?? const Color(0xFF191C23);
      final hsl = HSLColor.fromColor(color);
      final darkened =
          hsl.withLightness((hsl.lightness * 0.3).clamp(0.03, 0.25)).toColor();
      if (mounted) setState(() => _bgColor = darkened);
    } catch (_) {
      if (mounted) setState(() => _bgColor = const Color(0xFF191C23));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF191C23),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.queue_music, size: 72, color: Colors.white24),
              SizedBox(height: 16),
              Text('Nothing playing yet',
                  style: TextStyle(color: Colors.white54, fontSize: 18)),
              SizedBox(height: 8),
              Text('Tap a song in the Library to start',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final progress = player.duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / player.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred art background ────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  _bgColor,
                  const Color(0xFF191C23),
                  const Color(0xFF121212),
                ],
              ),
            ),
          ),

          // ── Page content ─────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar: X button (left) + NOW PLAYING (center) + spacer (right)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Row(
                    children: [
                      // X button — top-left corner
                      IconButton(
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 40, minHeight: 40),
                        icon: const Icon(Icons.close, color: Colors.white54),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                      // Centered label + handle
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'NOW PLAYING',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Balancing spacer so label stays truly centered
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Album art
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 20),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(140),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: song.albumArt != null
                                ? Image.memory(song.albumArt!,
                                    fit: BoxFit.cover)
                                : Container(
                                    color: const Color(0xFF282828),
                                    child: const Icon(Icons.music_note,
                                        size: 80, color: Colors.white24),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Title & artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFB0B0B0), fontSize: 17),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: _accent,
                          inactiveTrackColor: Colors.white.withAlpha(46),
                          thumbColor: Colors.white,
                          overlayColor: _accent.withAlpha(50),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (v) {
                            if (player.duration.inMilliseconds > 0) {
                              player.seek(Duration(
                                  milliseconds: (v *
                                          player.duration.inMilliseconds)
                                      .round()));
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(player.position),
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                            Text(_fmt(player.duration),
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Playback controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle
                    IconButton(
                      iconSize: 26,
                      icon: Icon(Icons.shuffle,
                          color: player.isShuffled
                              ? _accent
                              : Colors.white54),
                      onPressed: () => player.toggleShuffle(),
                      tooltip: player.isShuffled ? 'Shuffle on' : 'Shuffle off',
                    ),
                    const SizedBox(width: 16),

                    // Previous
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.skip_previous,
                          color: Colors.white),
                      onPressed: () => player.previous(),
                    ),
                    const SizedBox(width: 12),

                    // Play / Pause
                    GestureDetector(
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white24,
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          player.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: _accent,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Next
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: () => player.next(),
                    ),
                    const SizedBox(width: 16),

                    // Loop
                    IconButton(
                      iconSize: 26,
                      icon: Icon(
                        player.loopMode == LoopMode.loopSong
                            ? Icons.repeat_one
                            : Icons.repeat,
                        color: player.loopMode == LoopMode.off
                            ? Colors.white54
                            : _accent,
                      ),
                      onPressed: () => player.cycleLoopMode(),
                      tooltip: switch (player.loopMode) {
                        LoopMode.off => 'Loop off',
                        LoopMode.loopPlaylist => 'Loop playlist',
                        LoopMode.loopSong => 'Loop song',
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Queue
                    IconButton(
                      iconSize: 26,
                      icon: const Icon(Icons.queue_music,
                          color: Color(0xFF888888)),
                      tooltip: 'Queue',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const QueuePage()),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Add to playlist
                    IconButton(
                      iconSize: 26,
                      icon: const Icon(Icons.playlist_add,
                          color: Color(0xFF888888)),
                      tooltip: 'Add to playlist',
                      onPressed: () => _showAddToPlaylistSheet(context, song),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, Song song) {
    final playlists = context.read<PlaylistProvider>().playlists;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playlists yet. Create one first.')),
      );
      return;
    }
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add to playlist',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            const Divider(color: Colors.white12, height: 1),
            ...playlists.map(
              (name) => ListTile(
                leading: const Icon(Icons.queue_music, color: Colors.white54),
                title: Text(name,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  final allSongs = <Song>[];
                  context
                      .read<PlaylistProvider>()
                      .addSong(name, song, allSongs);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Added to "$name"'),
                        duration: const Duration(seconds: 2)),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
