import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/song_model.dart';
import '../services/player_provider.dart';
import '../services/playlist_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await context
        .read<PlaylistProvider>()
        .getSongs(widget.playlistName, widget.allSongs);
    if (mounted) setState(() { _songs = songs; _loading = false; });
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _songs.removeAt(oldIndex);
    _songs.insert(newIndex, item);
    setState(() {});
    await context
        .read<PlaylistProvider>()
        .reorder(widget.playlistName, oldIndex, newIndex, List.from(_songs));
  }

  Future<void> _remove(int index) async {
    final removed = _songs[index];
    setState(() => _songs.removeAt(index));
    // Re-write the playlist without that song
    await context
        .read<PlaylistProvider>()
        .reorder(widget.playlistName, index, index, List.from(_songs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${removed.title}" removed from playlist'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        actions: [
          if (_songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Play all',
              onPressed: () {
                player.playFromSource(
                  _songs.first,
                  source: _songs,
                  index: 0,
                  sourceName: widget.playlistName,
                );
                Navigator.pop(context);
              },
            ),
          if (_songs.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.shuffle,
                color: player.isShuffled
                    ? const Color(0xFF6060ff)
                    : null,
              ),
              tooltip: 'Shuffle play',
              onPressed: () {
                if (!player.isShuffled) player.toggleShuffle();
                player.playFromSource(
                  _songs.first,
                  source: _songs,
                  index: 0,
                  sourceName: widget.playlistName,
                );
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.queue_music,
                          size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('No songs in this playlist',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Right-click songs in the library to add them',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: _songs.length,
                  onReorder: _reorder,
                  proxyDecorator: (child, _, __) => Material(
                    color: const Color(0xFF282828),
                    elevation: 4,
                    child: child,
                  ),
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    final isCurrent =
                        player.currentSong?.filePath == song.filePath;
                    return _PlaylistSongTile(
                      key: ValueKey('pl_${song.filePath}_$index'),
                      song: song,
                      isCurrent: isCurrent,
                      isPlaying: isCurrent && player.isPlaying,
                      onTap: () => player.playFromSource(
                        song,
                        source: _songs,
                        index: index,
                        sourceName: widget.playlistName,
                      ),
                      onRemove: () => _remove(index),
                    );
                  },
                ),
    );
  }
}

class _PlaylistSongTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PlaylistSongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: () => _showContextMenu(context),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 44,
                height: 44,
                child: song.albumArt != null
                    ? Image.memory(song.albumArt!, fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFF282828),
                        child: const Icon(Icons.music_note,
                            color: Colors.white24, size: 22),
                      ),
              ),
            ),
            if (isPlaying)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.volume_up,
                    color: Colors.white, size: 18),
              ),
          ],
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? const Color(0xFF6060ff) : Colors.white,
            fontWeight:
                isCurrent ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${song.artist} • ${song.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.drag_handle,
            color: Colors.white24, size: 20),
        onTap: onTap,
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                                fontWeight: FontWeight.bold)),
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
              leading: const Icon(Icons.add_to_queue,
                  color: Colors.white70),
              title: const Text('Add to Queue',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                context.read<PlayerProvider>().addToQueue(song);
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
          ],
        ),
      ),
    );
  }
}
