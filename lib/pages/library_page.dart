import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../data/song_model.dart';
import '../services/download_provider.dart';
import '../services/music_folder_provider.dart';
import '../services/player_provider.dart';
import '../services/scanner_service.dart';

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
    // Reload whenever a download completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadProvider>().addListener(_loadFromDb);
    });
  }

  @override
  void dispose() {
    context.read<DownloadProvider>().removeListener(_loadFromDb);
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
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
                  Icon(Icons.library_music,
                      size: 72, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'No music yet',
                    style: TextStyle(fontSize: 18, color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the folder icon to scan a directory',
                    style: TextStyle(color: Colors.white38),
                  ),
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
          : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                return _SongTile(
                  song: song,
                  onTap: () {
                    context.read<PlayerProvider>().playSong(
                          song,
                          queue: _songs,
                          index: index,
                        );
                  },
                );
              },
            ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
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

