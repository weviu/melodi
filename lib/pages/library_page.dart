import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../data/song_model.dart';
import '../services/download_provider.dart';
import '../services/music_folder_provider.dart';
import '../services/player_provider.dart';
import '../services/playlist_provider.dart';
import '../services/scanner_service.dart';
import 'playlist_detail_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _db = DatabaseHelper();
  final _scanner = ScannerService();

  List<Song> _songs = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadFromDb();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadProvider>().addListener(_loadFromDb);
      _loadPlaylists();
    });
  }

  @override
  void dispose() {
    context.read<DownloadProvider>().removeListener(_loadFromDb);
    super.dispose();
  }

  void _loadPlaylists() {
    final folder = context.read<MusicFolderProvider>().folder;
    if (folder != null) {
      context.read<PlaylistProvider>().load(folder);
    }
  }

  Future<void> _loadFromDb() async {
    final songs = await _db.getAllSongs();
    if (mounted) setState(() => _songs = songs);
  }

  Future<void> _pickAndScan() async {
    String? dir;
    try {
      dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Music Folder',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder picker error: $e')),
        );
      }
      return;
    }

    if (dir == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No folder selected')),
        );
      }
      return;
    }

    // Persist folder so Search page can use it
    if (mounted) {
      await context.read<MusicFolderProvider>().setFolder(dir);
      await context.read<PlaylistProvider>().load(dir);
    }

    setState(() => _isScanning = true);
    try {
      final songs = await _scanner.scanDirectory(dir);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${songs.length} MP3 file(s)')),
        );
      }
      await _db.clearSongs();
      await _db.insertSongs(songs);
      await _loadFromDb();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>().playlists;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        centerTitle: false,
        flexibleSpace: const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _MelodiLogo(),
          ),
        ),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Choose Music Folder',
              onPressed: _pickAndScan,
            ),
        ],
      ),
      body: _songs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.library_music,
                      size: 72, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('No music yet',
                      style:
                          TextStyle(fontSize: 18, color: Colors.white54)),
                  const SizedBox(height: 8),
                  const Text('Tap the folder icon to scan a directory',
                      style: TextStyle(color: Colors.white38)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isScanning ? null : _pickAndScan,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose Music Folder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0b007f),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // ── Playlists section ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Text('Playlists',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add,
                              color: Colors.white54, size: 20),
                          tooltip: 'New playlist',
                          onPressed: () =>
                              _showCreatePlaylistDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),
                if (playlists.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text('No playlists yet',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 13)),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 88,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: playlists.length,
                        itemBuilder: (context, i) => _PlaylistChip(
                          name: playlists[i],
                          allSongs: _songs,
                        ),
                      ),
                    ),
                  ),

                // ── Divider ────────────────────────────────────────────
                const SliverToBoxAdapter(
                  child: Divider(color: Colors.white12, height: 1),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text('Songs',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1)),
                  ),
                ),

                // ── Songs list ─────────────────────────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = _songs[index];
                      return _SongTile(
                        song: song,
                        allSongs: _songs,
                        onTap: () {
                          context.read<PlayerProvider>().playFromSource(
                                song,
                                source: _songs,
                                index: index,
                                sourceName: 'Library',
                              );
                        },
                      );
                    },
                    childCount: _songs.length,
                  ),
                ),
              ],
            ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('New Playlist',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0b007f))),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              context.read<PlaylistProvider>().create(v.trim());
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context
                    .read<PlaylistProvider>()
                    .create(ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Create',
                style: TextStyle(color: Color(0xFF6060ff))),
          ),
        ],
      ),
    );
  }
}

class _PlaylistChip extends StatelessWidget {
  final String name;
  final List<Song> allSongs;
  const _PlaylistChip({required this.name, required this.allSongs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailPage(
            playlistName: name,
            allSongs: allSongs,
          ),
        ),
      ),
      onLongPress: () => _showDeleteDialog(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music,
                color: Colors.white54, size: 26),
            const SizedBox(height: 4),
            Text(name,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: Text('Delete "$name"?',
            style: const TextStyle(color: Colors.white)),
        content: const Text('This will delete the playlist file.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              context.read<PlaylistProvider>().delete(name);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final List<Song> allSongs;
  final VoidCallback onTap;
  const _SongTile(
      {required this.song, required this.allSongs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: () => _showContextMenu(context),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _AlbumArt(albumArt: song.albumArt),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${song.artist} • ${song.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final playlists = context.read<PlaylistProvider>().playlists;

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
            // Handle
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
                  _AlbumArt(albumArt: song.albumArt),
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

            // Add to Queue
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
                    content: Text(
                        '"${song.title}" added to queue'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            // Add to Playlist
            ListTile(
              leading: const Icon(Icons.playlist_add,
                  color: Colors.white70),
              title: const Text('Add to Playlist',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistSheet(context, playlists);
              },
            ),

            // Delete File
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete File',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(
      BuildContext context, List<String> playlists) {
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No playlists yet. Create one first.')),
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
                leading: const Icon(Icons.queue_music,
                    color: Colors.white54),
                title: Text(name,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  context
                      .read<PlaylistProvider>()
                      .addSong(name, song, allSongs);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Added to "$name"'),
                        duration: const Duration(seconds: 2)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Delete file?',
            style: TextStyle(color: Colors.white)),
        content: Text(
            '"${song.title}" will be moved to trash.',
            style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Move to trash by renaming to .trash folder, or just delete
                final f = File(song.filePath);
                if (await f.exists()) await f.delete();
                // Re-scan to refresh library
                final db = DatabaseHelper();
                await db.clearSongs();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Delete failed: $e')),
                );
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final Uint8List? albumArt;
  const _AlbumArt({this.albumArt});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 50,
        height: 50,
        child: albumArt != null
            ? Image.memory(albumArt!, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFF282828),
                child: const Icon(Icons.music_note,
                    color: Colors.white38, size: 28),
              ),
      ),
    );
  }
}

class _MelodiLogo extends StatelessWidget {
  const _MelodiLogo();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF1E4A9E);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'lily.svg',
          width: 64,
          height: 64,
        ),
        const SizedBox(width: 8),
        const Text(
          'MELODI',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            fontFamily: 'Analogue BC',
          ),
        ),
      ],
    );
  }
}

