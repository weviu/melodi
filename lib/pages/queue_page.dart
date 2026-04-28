import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/song_model.dart';
import '../services/player_provider.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final current = player.currentSong;
    final manual = player.manualQueue;
    final sourceNext = player.sourceUpcoming;
    final hasUpcoming = manual.isNotEmpty || sourceNext.isNotEmpty;

    // Combined upcoming list for reorder/remove operations
    final upcoming = player.upcomingQueue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          if (hasUpcoming)
            TextButton(
              onPressed: player.clearUpcoming,
              child: const Text('Clear',
                  style: TextStyle(color: Colors.white60)),
            ),
        ],
      ),
      body: ListView(
        children: [
          // ── Now Playing ───────────────────────────────────────────────
          const _SectionHeader(label: 'NOW PLAYING'),
          if (current != null) _QueueTile(song: current, isCurrent: true),

          // ── Next Up (manual queue) ─────────────────────────────────────
          if (manual.isNotEmpty) ...[
            const _SectionHeader(label: 'NEXT UP'),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: manual.length,
              onReorder: (oldIndex, newIndex) =>
                  player.reorderUpcoming(oldIndex, newIndex),
              proxyDecorator: (child, index, animation) => Material(
                color: const Color(0xFF282828),
                elevation: 4,
                child: child,
              ),
              itemBuilder: (context, index) {
                final song = manual[index];
                return _QueueTile(
                  key: ValueKey('manual_${song.filePath}_$index'),
                  song: song,
                  showRemove: true,
                  onRemove: () => player.removeFromUpcoming(index),
                  onTap: () {
                    player.skipToUpcoming(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],

          // ── Next from source ───────────────────────────────────────────
          if (sourceNext.isNotEmpty) ...[
            _SectionHeader(label: 'NEXT FROM ${player.sourceName.toUpperCase()}'),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sourceNext.length,
              onReorder: (oldIndex, newIndex) {
                // Offset indices by manual queue length
                player.reorderUpcoming(
                  manual.length + oldIndex,
                  manual.length + newIndex,
                );
              },
              proxyDecorator: (child, index, animation) => Material(
                color: const Color(0xFF282828),
                elevation: 4,
                child: child,
              ),
              itemBuilder: (context, index) {
                final song = sourceNext[index];
                final combinedIndex = manual.length + index;
                return _QueueTile(
                  key: ValueKey('source_${song.filePath}_$index'),
                  song: song,
                  showRemove: true,
                  onRemove: () =>
                      player.removeFromUpcoming(combinedIndex),
                  onTap: () {
                    player.skipToUpcoming(combinedIndex);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],

          if (!hasUpcoming)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Nothing else in queue',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 14)),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool showRemove;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _QueueTile({
    super.key,
    required this.song,
    this.isCurrent = false,
    this.showRemove = false,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
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
          if (isCurrent && player.isPlaying)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(3),
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
              isCurrent ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: showRemove
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white38, size: 18),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
                const Icon(Icons.drag_handle,
                    color: Colors.white24, size: 20),
              ],
            )
          : null,
      onTap: isCurrent ? null : onTap,
    );
  }
}
