import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import '../services/player_provider.dart';
import 'queue_page.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  Color _dominantColor = const Color(0xFF121212);
  Uint8List? _lastArtBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerProvider>();
      player.addListener(_onPlayerChanged);
      _onPlayerChanged();
    });
  }

  @override
  void dispose() {
    context.read<PlayerProvider>().removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    final song = context.read<PlayerProvider>().currentSong;
    if (song?.albumArt != _lastArtBytes) {
      _lastArtBytes = song?.albumArt;
      _extractColor(song?.albumArt);
    }
  }

  Future<void> _extractColor(Uint8List? artBytes) async {
    if (artBytes == null) {
      if (mounted) setState(() => _dominantColor = const Color(0xFF121212));
      return;
    }
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        MemoryImage(artBytes),
        size: const Size(100, 100),
      );
      final color = generator.dominantColor?.color ?? const Color(0xFF121212);
      final hsl = HSLColor.fromColor(color);
      final darkened =
          hsl.withLightness((hsl.lightness * 0.4).clamp(0.05, 0.35)).toColor();
      if (mounted) setState(() => _dominantColor = darkened);
    } catch (_) {
      if (mounted) setState(() => _dominantColor = const Color(0xFF121212));
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
        appBar: AppBar(title: const Text('Now Playing')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.queue_music, size: 72, color: Colors.white24),
              SizedBox(height: 16),
              Text(
                'Nothing playing yet',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Tap a song in the Library to start',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final progress = player.duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / player.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.6],
            colors: [_dominantColor, const Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
              // Top bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        'NOW PLAYING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Album art — fills all remaining vertical space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: song.albumArt != null
                            ? Image.memory(song.albumArt!, fit: BoxFit.cover)
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

              const SizedBox(height: 24),

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
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Seek slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (value) {
                          if (player.duration.inMilliseconds > 0) {
                            player.seek(Duration(
                                milliseconds:
                                    (value * player.duration.inMilliseconds)
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
                                  color: Colors.white54, fontSize: 12)),
                          Text(_fmt(player.duration),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Playback controls
              Row(
                children: [
                  // Left: Shuffle
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          iconSize: 26,
                          icon: Icon(
                            Icons.shuffle,
                            color: player.isShuffled
                                ? const Color(0xFF6060ff)
                                : Colors.white54,
                          ),
                          onPressed: () => player.toggleShuffle(),
                          tooltip: player.isShuffled
                              ? 'Shuffle on'
                              : 'Shuffle off',
                        ),
                      ],
                    ),
                  ),

                  // Center: Prev / Play-Pause / Next
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white),
                        onPressed: () => player.previous(),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 40,
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.black,
                          ),
                          onPressed: () => player.togglePlayPause(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.skip_next,
                            color: Colors.white),
                        onPressed: () => player.next(),
                      ),
                    ],
                  ),

                  // Right: Loop
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          iconSize: 26,
                          icon: Icon(
                            player.loopMode == LoopMode.loopSong
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: player.loopMode == LoopMode.off
                                ? Colors.white54
                                : const Color(0xFF6060ff),
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
                  ),
                ],
              ),

              // Second row: Queue button under loop (right-aligned)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    iconSize: 26,
                    icon: const Icon(Icons.queue_music,
                        color: Colors.white54),
                    tooltip: 'Queue',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const QueuePage()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
