import 'package:flutter/material.dart';

import '../data/song_model.dart';
import 'm3u_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final _m3u = M3uService();

  List<String> _playlists = [];
  List<String> get playlists => _playlists;

  String? _musicFolder;

  Future<void> load(String musicFolder) async {
    _musicFolder = musicFolder;
    _playlists = await _m3u.listPlaylists(musicFolder);
    notifyListeners();
  }

  Future<void> create(String name) async {
    if (_musicFolder == null || name.trim().isEmpty) return;
    await _m3u.createPlaylist(_musicFolder!, name.trim());
    await load(_musicFolder!);
  }

  Future<void> delete(String name) async {
    if (_musicFolder == null) return;
    await _m3u.deletePlaylist(_musicFolder!, name);
    await load(_musicFolder!);
  }

  Future<void> addSong(String playlistName, Song song, List<Song> allSongs) async {
    if (_musicFolder == null) return;
    await _m3u.addSongToPlaylist(_musicFolder!, playlistName, song, allSongs);
  }

  Future<List<Song>> getSongs(String playlistName, List<Song> allSongs) async {
    if (_musicFolder == null) return [];
    final paths = await _m3u.readPlaylist(_musicFolder!, playlistName);
    return paths
        .map((path) => allSongs.firstWhere(
              (s) => s.filePath == path,
              orElse: () => Song(
                  title: path.split('/').last,
                  artist: '',
                  album: '',
                  filePath: path),
            ))
        .toList();
  }

  Future<void> reorder(
      String playlistName, int oldIndex, int newIndex, List<Song> songs) async {
    if (_musicFolder == null) return;
    final list = List<Song>.from(songs);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await _m3u.writePlaylist(_musicFolder!, playlistName, list);
  }
}
