import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/song_model.dart';
import '../services/music_folder_provider.dart';
import '../services/m3u_service.dart';
import '../services/player_provider.dart';
import '../services/playlist_provider.dart';
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
  final Set<String> _likedPaths = {};

  late String _name;
  String _description = '';
  Uint8List? _coverImageBytes; // custom cover picked by user

  final _m3u = M3uService();

  @override
  void initState() {
    super.initState();
    _name = widget.playlistName;
    _load();
    _loadMeta();
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
  }

  Future<void> _loadMeta() async {
    final folder = context.read<MusicFolderProvider>().folder;
    if (folder == null) return;
    final meta = await _m3u.readMeta(folder, _name);
    final coverPath = await _m3u.coverPath(folder, _name);
    if (!mounted) return;
    setState(() {
      _description = (meta['description'] as String?) ?? '';
      if (coverPath != null) {
        _coverImageBytes = File(coverPath).readAsBytesSync();
      }
    });
  }

  Future<void> _saveMeta() async {
    final folder = context.read<MusicFolderProvider>().folder;
    if (folder == null) return;
    await _m3u.writeMeta(folder, _name, {'description': _description});
  }

  void _showMoreSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF252830),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline,
                  color: Colors.white70),
              title: const Text('Edit name',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _editName(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notes, color: Colors.white70),
              title: const Text('Edit description',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _editDescription(ctx);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.image_outlined, color: Colors.white70),
              title: const Text('Edit cover',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _editCover();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_copy_outlined,
                  color: Colors.white70),
              title: const Text('Copy playlist path',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final folder = context.read<MusicFolderProvider>().folder;
                if (folder != null) {
                  final path = '$folder/Playlists/$_name.m3u';
                  await Clipboard.setData(ClipboardData(text: path));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path copied to clipboard')),
                    );
                  }
                }
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete playlist',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deletePlaylist(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editName(BuildContext ctx) {
    final ctrl = TextEditingController(text: _name);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Edit name',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _kAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty || newName == _name) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              final folder = context.read<MusicFolderProvider>().folder;
              if (folder != null) {
                await context
                    .read<PlaylistProvider>()
                    .rename(_name, newName);
              }
              if (!mounted) return;
              setState(() => _name = newName);
            },
            child: const Text('Save',
                style: TextStyle(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  void _editDescription(BuildContext ctx) {
    final ctrl = TextEditingController(text: _description);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Edit description',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Add a description…',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final desc = ctrl.text.trim();
              Navigator.pop(ctx);
              if (!mounted) return;
              setState(() => _description = desc);
              await _saveMeta();
            },
            child: const Text('Save',
                style: TextStyle(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _editCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Choose cover image',
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;
    final srcPath = result.files.single.path!;
    final folder = context.read<MusicFolderProvider>().folder;
    if (folder == null) return;
    await _m3u.saveCover(folder, _name, srcPath);
    if (!mounted) return;
    final bytes = await File(srcPath).readAsBytes();
    setState(() => _coverImageBytes = bytes);
  }

  void _deletePlaylist(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: Text('Delete "$_name"?',
            style: const TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete the playlist.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<PlaylistProvider>().delete(_name);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(int index) async {
    final removed = _songs[index];
    final before = List<Song>.from(_songs);
    setState(() => _songs = List<Song>.from(_songs)..removeAt(index));
    await context
        .read<PlaylistProvider>()
        .removeSong(_name, index, before);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${removed.title}" removed'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    context.read<PlayerProvider>().playFromSource(
          _songs.first,
          source: _songs,
          index: 0,
          sourceName: _name,
        );
  }

  void _shufflePlay() {
    if (_songs.isEmpty) return;
    final player = context.read<PlayerProvider>();
    if (!player.isShuffled) player.toggleShuffle();
    player.playFromSource(
      _songs.first,
      source: _songs,
      index: 0,
      sourceName: _name,
    );
  }

  void _showAddToPlaylistSheet(BuildContext ctx, Song song) {
    final playlists = context
        .read<PlaylistProvider>()
        .playlists
        .where((p) => p != _name)
        .toList();
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('No other playlists available.')),
      );
      return;
    }
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF252830),
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
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('Add to playlist',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            const Divider(color: Colors.white12, height: 1),
            ...playlists.map((name) => ListTile(
                  leading:
                      const Icon(Icons.queue_music, color: Colors.white54),
                  title:
                      Text(name, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    context
                        .read<PlaylistProvider>()
                        .addSong(name, song, widget.allSongs);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Added to "$name"')),
                    );
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isShuffled = context.watch<PlayerProvider>().isShuffled;
    // Prefer user-picked cover, else fall back to first song's embedded art
    final coverArt = _coverImageBytes ?? (_songs.isNotEmpty ? _songs.first.albumArt : null);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          FocusScope.of(context).unfocus();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF121319),
      bottomNavigationBar: MiniPlayer(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NowPlayingPage()),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kAccent),
            )
          : CustomScrollView(
              slivers: [
                // ── Collapsing header ──────────────────────────────
                SliverAppBar(
                  expandedHeight: isMobile ? 260.0 : 340.0,
                  pinned: true,
                  stretch: true,
                  backgroundColor: _kAccent.withAlpha(230),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      Navigator.pop(context);
                    },
                  ),
                  title: Text(
                    _name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: _playAll,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: _kAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _PlaylistHeader(
                      name: _name,
                      description: _description,
                      songCount: _songs.length,
                      coverArt: coverArt,
                    ),
                  ),
                ),

                // ── Sticky action bar ──────────────────────────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ActionBarDelegate(
                    songCount: _songs.length,
                    isShuffled: isShuffled,
                    onPlay: _playAll,
                    onShuffle: _shufflePlay,
                    onMore: () => _showMoreSheet(context),
                  ),
                ),

                if (_songs.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else ...[
                  // ── Table column headers ─────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      color: const Color(0xFF121319),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                            child: Builder(
                              builder: (context) {
                                final isMobile = MediaQuery.of(context).size.width < 600;
                                return Row(
                                  children: [
                                    const SizedBox(
                                      width: 40,
                                      child: Text('#',
                                          textAlign: TextAlign.center,
                                          style: _kColHeader),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                        flex: 2,
                                        child: Text('TITLE', style: _kColHeader)),
                                    if (!isMobile) ...[
                                      const Expanded(
                                          flex: 1,
                                          child: Text('ARTIST', style: _kColHeader)),
                                      const Expanded(
                                          flex: 1,
                                          child: Text('ALBUM', style: _kColHeader)),
                                    ],
                                    const SizedBox(width: 40),
                                  ],
                                );
                              },
                            ),
                          ),
                          const Divider(color: Color(0xFF2A2D35), height: 1),
                        ],
                      ),
                    ),
                  ),

                  // ── Song rows ────────────────────────────────────
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _songs[index];
                        return _SongRow(
                          song: song,
                          trackNumber: index + 1,
                          isLiked: _likedPaths.contains(song.filePath),
                          onTap: () =>
                              context.read<PlayerProvider>().playFromSource(
                                    song,
                                    source: _songs,
                                    index: index,
                                    sourceName: widget.playlistName,
                                  ),
                          onLikeToggle: () => setState(() {
                            final p = song.filePath;
                            _likedPaths.contains(p)
                                ? _likedPaths.remove(p)
                                : _likedPaths.add(p);
                          }),
                          onRemove: () => _remove(index),
                          onAddToQueue: () =>
                              context.read<PlayerProvider>().addToQueue(song),
                          onAddToPlaylist: () =>
                              _showAddToPlaylistSheet(context, song),
                        );
                      },
                      childCount: _songs.length,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    ),
    );
  }
}

// ── Constants ──────────────────────────────────────────────────────────────

const _kAccent = Color(0xFF0F2F6A);

const _kColHeader = TextStyle(
  color: Color(0xFF888888),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.0,
);

// ── Playlist header ────────────────────────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  final String name;
  final String description;
  final int songCount;
  final Uint8List? coverArt;

  const _PlaylistHeader({
    required this.name,
    required this.description,
    required this.songCount,
    required this.coverArt,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final coverSize = isMobile ? 140.0 : 220.0;

    final coverWidget = Container(
      width: coverSize,
      height: coverSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(160),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: coverArt != null
            ? Image.memory(coverArt!, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFF1A2340),
                child: const Icon(Icons.queue_music,
                    size: 80, color: Colors.white24),
              ),
      ),
    );

    final metaWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PLAYLIST',
          style: TextStyle(
            color: Color(0xFFB1C5FF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 28.0 : 36.0,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        if (description.isNotEmpty) ...[
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Text('My Library',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const Text(' • ',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            Text(
              '$songCount ${songCount == 1 ? 'song' : 'songs'}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.65, 1.0],
          colors: [
            Color(0xFF0F2F6A),
            Color(0x990F2F6A),
            Color(0xFF121319),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 20 : 32,
            isMobile ? 56 : 60,
            isMobile ? 20 : 32,
            20,
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    coverWidget,
                    const SizedBox(height: 16),
                    metaWidget,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    coverWidget,
                    const SizedBox(width: 32),
                    Expanded(child: metaWidget),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Sticky action bar delegate ─────────────────────────────────────────────

class _ActionBarDelegate extends SliverPersistentHeaderDelegate {
  final int songCount;
  final bool isShuffled;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onMore;

  const _ActionBarDelegate({
    required this.songCount,
    required this.isShuffled,
    required this.onPlay,
    required this.onShuffle,
    required this.onMore,
  });

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 72;

  @override
  bool shouldRebuild(_ActionBarDelegate old) =>
      old.isShuffled != isShuffled || old.songCount != songCount;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: const Color(0xFF191C23).withAlpha(242),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: Row(
            children: [
              // Play — large filled circle
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _kAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withAlpha(90),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 30),
                ),
              ),

              const SizedBox(width: 20),

              // Shuffle — outlined circle
              GestureDetector(
                onTap: onShuffle,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isShuffled ? _kAccent : const Color(0xFF323745),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.shuffle,
                    color: isShuffled ? _kAccent : Colors.white54,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // More options
              IconButton(
                iconSize: 22,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz, color: Color(0xFF888888)),
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text('No songs yet',
              style: TextStyle(color: Colors.white54, fontSize: 18)),
          SizedBox(height: 8),
          Text('Right-click songs in the library to add them',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Song row ───────────────────────────────────────────────────────────────

class _SongRow extends StatefulWidget {
  final Song song;
  final int trackNumber;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onLikeToggle;
  final VoidCallback onRemove;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToPlaylist;

  const _SongRow({
    required this.song,
    required this.trackNumber,
    required this.isLiked,
    required this.onTap,
    required this.onLikeToggle,
    required this.onRemove,
    required this.onAddToQueue,
    required this.onAddToPlaylist,
  });

  @override
  State<_SongRow> createState() => _SongRowState();
}

class _SongRowState extends State<_SongRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.currentSong?.filePath == widget.song.filePath;
    final isPlaying = isCurrent && player.isPlaying;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTap: () => _showContextMenu(context),
        onLongPress: () => _showContextMenu(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 56,
          decoration: BoxDecoration(
            color:
                _hovered ? const Color(0xFF2A2D35) : Colors.transparent,
            border: isCurrent
                ? const Border(
                    left: BorderSide(color: _kAccent, width: 2))
                : null,
          ),
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Track # / equalizer / play arrow
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: isPlaying
                          ? const Icon(Icons.equalizer,
                              color: _kAccent, size: 18)
                          : isCurrent
                              ? const Icon(Icons.volume_up,
                                  color: _kAccent, size: 16)
                              : _hovered
                                  ? const Icon(Icons.play_arrow,
                                      color: Colors.white, size: 20)
                                  : Text(
                                      '${widget.trackNumber}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF888888),
                                        fontSize: 14,
                                      ),
                                    ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Art + Title + Artist stacked (flex 2)
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: widget.song.albumArt != null
                                ? Image.memory(widget.song.albumArt!,
                                    fit: BoxFit.cover)
                                : Container(
                                    color: const Color(0xFF282828),
                                    child: const Icon(Icons.music_note,
                                        color: Colors.white24, size: 20),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? _kAccent : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                widget.song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Artist column (flex 1)
                  if (!isMobile)
                    Expanded(
                      flex: 1,
                      child: Text(
                        widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 13),
                      ),
                    ),

                  // Album column (flex 1)
                  if (!isMobile)
                    Expanded(
                      flex: 1,
                      child: Text(
                        widget.song.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 13),
                      ),
                    ),

                  // Heart icon (visible on hover or when liked)
                  SizedBox(
                    width: 40,
                    child: AnimatedOpacity(
                      opacity: _hovered || widget.isLiked ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          widget.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: widget.isLiked
                              ? _kAccent
                              : const Color(0xFF888888),
                        ),
                        onPressed: widget.onLikeToggle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF252830),
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
                      child: widget.song.albumArt != null
                          ? Image.memory(widget.song.albumArt!,
                              fit: BoxFit.cover)
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
                        Text(widget.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text(widget.song.artist,
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
            _ContextOption(
              icon: Icons.playlist_add,
              label: 'Add to Queue',
              onTap: () {
                widget.onAddToQueue();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('"${widget.song.title}" added to queue'),
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
            _ContextOption(
              icon: Icons.add_box_outlined,
              label: 'Add to Playlist',
              onTap: () {
                Navigator.pop(context);
                widget.onAddToPlaylist();
              },
            ),
            _ContextOption(
              icon: Icons.share_outlined,
              label: 'Share Track',
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: Colors.white12, height: 1),
            _ContextOption(
              icon: Icons.delete_outline,
              label: 'Remove from playlist',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                widget.onRemove();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Context menu option ────────────────────────────────────────────────────

class _ContextOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ContextOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c.withAlpha(200), size: 20),
      title: Text(label, style: TextStyle(color: c, fontSize: 14)),
      hoverColor: _kAccent.withAlpha(40),
      onTap: onTap,
    );
  }
}
