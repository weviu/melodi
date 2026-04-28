import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_provider.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.queue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          if (queue.isNotEmpty)
            TextButton(
              onPressed: () {
                // Remove all songs after current
                final current = player.currentIndex;
                for (int i = queue.length - 1; i > current; i--) {
                  player.removeFromQueue(i);
                }
              },
              child: const Text('Clear upcoming',
                  style: TextStyle(color: Colors.white60)),
            ),
        ],
      ),
      body: queue.isEmpty
          ? const Center(
              child: Text('Queue is empty',
                  style: TextStyle(color: Colors.white38, fontSize: 16)),
            )
          : ReorderableListView.builder(
              itemCount: queue.length,
              onReorder: player.reorderQueue,
              proxyDecorator: (child, index, animation) => Material(
                color: const Color(0xFF282828),
                elevation: 4,
                child: child,
              ),
              itemBuilder: (context, index) {
                final song = queue[index];
                final isCurrent = index == player.currentIndex;

                return ListTile(
                  key: ValueKey(song.filePath + index.toString()),
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
                      color: isCurrent
                          ? const Color(0xFF6060ff)
                          : Colors.white,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCurrent)
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white38, size: 18),
                          tooltip: 'Remove from queue',
                          onPressed: () => player.removeFromQueue(index),
                        ),
                      const Icon(Icons.drag_handle,
                          color: Colors.white24, size: 20),
                    ],
                  ),
                  onTap: () => player.playSong(song, index: index),
                );
              },
            ),
    );
  }
}
