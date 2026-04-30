import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../data/song_model.dart';

class M3uService {
  /// Returns the Playlists directory, creating it if needed.
  Future<Directory> playlistsDir(String musicFolder) async {
    final dir = Directory(p.join(musicFolder, 'Playlists'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Lists all playlist names (without .m3u extension).
  Future<List<String>> listPlaylists(String musicFolder) async {
    final dir = await playlistsDir(musicFolder);
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.m3u'))
        .toList();
    return files
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList()
      ..sort();
  }

  /// Reads a playlist and returns the list of file paths.
  Future<List<String>> readPlaylist(String musicFolder, String name) async {
    final dir = await playlistsDir(musicFolder);
    final file = File(p.join(dir.path, '$name.m3u'));
    if (!await file.exists()) return [];
    final lines = await file.readAsLines();
    return lines.where((l) => l.isNotEmpty && !l.startsWith('#')).toList();
  }

  /// Writes a playlist from a list of Songs.
  Future<void> writePlaylist(
      String musicFolder, String name, List<Song> songs) async {
    final dir = await playlistsDir(musicFolder);
    final file = File(p.join(dir.path, '$name.m3u'));
    final buf = StringBuffer('#EXTM3U\n');
    for (final s in songs) {
      buf.writeln(
          '#EXTINF:${s.title} - ${s.artist}');
      buf.writeln(s.filePath);
    }
    await file.writeAsString(buf.toString());
  }

  /// Creates an empty playlist file.
  Future<void> createPlaylist(String musicFolder, String name) async {
    await writePlaylist(musicFolder, name, []);
  }

  /// Deletes a playlist file.
  Future<void> deletePlaylist(String musicFolder, String name) async {
    final dir = await playlistsDir(musicFolder);
    final file = File(p.join(dir.path, '$name.m3u'));
    if (await file.exists()) await file.delete();
  }

  // ── Sidecar metadata (description + cover path) ──────────────────────────

  Future<Map<String, dynamic>> readMeta(
      String musicFolder, String name) async {
    final dir = await playlistsDir(musicFolder);
    final file = File(p.join(dir.path, '$name.json'));
    if (!await file.exists()) return {};
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> writeMeta(
      String musicFolder, String name, Map<String, dynamic> meta) async {
    final dir = await playlistsDir(musicFolder);
    final file = File(p.join(dir.path, '$name.json'));
    await file.writeAsString(jsonEncode(meta));
  }

  /// Renames the .m3u and any sidecar files (.json, .jpg).
  Future<void> renamePlaylist(
      String musicFolder, String oldName, String newName) async {
    final dir = await playlistsDir(musicFolder);
    for (final ext in ['.m3u', '.json', '.jpg', '.png']) {
      final old = File(p.join(dir.path, '$oldName$ext'));
      if (await old.exists()) {
        await old.rename(p.join(dir.path, '$newName$ext'));
      }
    }
  }

  /// Returns the path of the cover image if it exists, else null.
  Future<String?> coverPath(String musicFolder, String name) async {
    final dir = await playlistsDir(musicFolder);
    for (final ext in ['.jpg', '.png']) {
      final f = File(p.join(dir.path, '$name$ext'));
      if (await f.exists()) return f.path;
    }
    return null;
  }

  /// Saves an image file as the playlist cover (copies to Playlists/).
  Future<void> saveCover(
      String musicFolder, String name, String sourcePath) async {
    final dir = await playlistsDir(musicFolder);
    final ext = p.extension(sourcePath).toLowerCase();
    final dest = File(p.join(dir.path, '$name$ext'));
    await File(sourcePath).copy(dest.path);
  }

  /// Appends a song to an existing playlist.
  Future<void> addSongToPlaylist(
      String musicFolder, String name, Song song, List<Song> allSongs) async {
    final paths = await readPlaylist(musicFolder, name);
    if (paths.contains(song.filePath)) return;
    final existing = paths
        .map((path) => allSongs.firstWhere(
              (s) => s.filePath == path,
              orElse: () => Song(
                  title: p.basename(path),
                  artist: '',
                  album: '',
                  filePath: path),
            ))
        .toList();
    existing.add(song);
    await writePlaylist(musicFolder, name, existing);
  }
}
