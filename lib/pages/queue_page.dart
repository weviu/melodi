import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/song_model.dart';
import '../services/player_provider.dart';

// ── Internal item model ────────────────────────────────────────────────────

enum _ItemType { song, divider, repeatInfo }

class _Item {
  final _ItemType type;
  final Song? song;
  final int combinedIndex;
  final String? label;

  _Item._({required this.type, this.song, this.combinedIndex = -1, this.label});

  factory _Item.song(Song s, int ci) =>
      _Item._(type: _ItemType.song, song: s, combinedIndex: ci);
  factory _Item.divider() => _Item._(type: _ItemType.divider);
  factory _Item.repeatInfo(String l) =>
      _Item._(type: _ItemType.repeatInfo, label: l);
}

// ── Page ───────────────────────────────────────────────────────────────────

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  final ScrollController _scroll = ScrollController();
  int _visibleSourceCount = 32;
  static const int _pageSize = 32;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      final player = context.read<PlayerProvider>();
      final canLoad = player.loopMode == LoopMode.loopPlaylist ||
          _visibleSourceCount < player.sourceUpcoming.length;
      if (canLoad) setState(() => _visibleSourceCount += _pageSize);
    }
  }

  List<_Item> _buildSourceItems(PlayerProvider player) {
    final mode = player.loopMode;
    final manual = player.manualQueue;
    final sourceNext = player.sourceUpcoming.toList();
    final source = player.source;

    if (mode == LoopMode.loopSong) {
      return [_Item.repeatInfo('↩  This song repeats indefinitely')];
    }

    final result = <_Item>[];

    for (int i = 0; i < sourceNext.length && result.length < _visibleSourceCount; i++) {
      result.add(_Item.song(sourceNext[i], manual.length + i));
    }

    if (mode == LoopMode.loopPlaylist && source.isNotEmpty) {
      if (result.length < _visibleSourceCount) {
        result.add(_Item.divider());
      }
      int i = 0;
      while (result.length < _visibleSourceCount) {
        result.add(_Item.song(source[i % source.length], -1));
        i++;
      }
    }

    return result;
  }

  bool _hasMore(PlayerProvider player) {
    if (player.loopMode == LoopMode.loopSong) return false;
    if (player.loopMode == LoopMode.loopPlaylist) return player.source.isNotEmpty;
    return _visibleSourceCount < player.sourceUpcoming.length;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final current = player.currentSong;
    final manual = player.manualQueue.toList();
    final sourceItems = _buildSourceItems(player);
    final hasUpcoming = manual.isNotEmpty || sourceItems.isNotEmpty;

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
        controller: _scroll,
        children: [
          const _SectionHeader(label: 'NOW PLAYING'),
          if (current != null) _QueueTile(song: current, isCurrent: true),

          if (manual.isNotEmpty) ...[
            const _SectionHeader(label: 'NEXT UP'),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: manual.length,
              onReorder: (o, n) => player.reorderUpcoming(o, n),
              proxyDecorator: (child, _, __) => Material(
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

          if (sourceItems.isNotEmpty) ...[
            _SectionHeader(
              label: 'NEXT FROM ${player.sourceName.toUpperCase()}',
              loopMode: player.loopMode,
            ),
            for (final item in sourceItems) _buildSourceRow(context, player, item),
          ],

          if (_hasMore(player))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white24),
                ),
              ),
            ),

          if (!hasUpcoming)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Nothing else in queue',
                    style: TextStyle(color: Colors.white38, fontSize: 14)),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSourceRow(
      BuildContext context, PlayerProvider player, _Item item) {
    switch (item.type) {
      case _ItemType.divider:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(child: Divider(color: Colors.white12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('↩  repeating',
                  style: TextStyle(color: Color(0xFF6060ff), fontSize: 11)),
            ),
            Expanded(child: Divider(color: Colors.white12)),
          ]),
        );

      case _ItemType.repeatInfo:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            const Icon(Icons.repeat_one, size: 16, color: Color(0xFF6060ff)),
            const SizedBox(width: 8),
            Text(item.label ?? '',
                style: const TextStyle(color: Color(0xFF6060ff), fontSize: 13)),
          ]),
        );

      case _ItemType.song:
        final ci = item.combinedIndex;
        final canManipulate = ci >= 0;
        return _QueueTile(
          key: ValueKey('src_${item.song!.filePath}_$ci'),
          song: item.song!,
          showRemove: canManipulate,
          onRemove: canManipulate ? () => player.removeFromUpcoming(ci) : null,
          onTap: canManipulate
              ? () {
                  player.skipToUpcoming(ci);
                  Navigator.pop(context);
                }
              : null,
        );
    }
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final LoopMode? loopMode;
  const _SectionHeader({required this.label, this.loopMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          if (loopMode != null && loopMode != LoopMode.off) ...[
            const SizedBox(width: 6),
            Icon(
              loopMode == LoopMode.loopSong ? Icons.repeat_one : Icons.repeat,
              size: 13,
              color: const Color(0xFF6060ff),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Queue tile ─────────────────────────────────────────────────────────────

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
              child: const Icon(Icons.volume_up, color: Colors.white, size: 18),
            ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? const Color(0xFF6060ff) : Colors.white,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
                const Icon(Icons.drag_handle, color: Colors.white24, size: 20),
              ],
            )
          : null,
      onTap: isCurrent ? null : onTap,
    );
  }
}
