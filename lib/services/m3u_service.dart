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
