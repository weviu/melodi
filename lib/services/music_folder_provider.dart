import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicFolderProvider extends ChangeNotifier {
  static const _key = 'music_folder';

  String? _folder;
  String? get folder => _folder;

  MusicFolderProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _folder = prefs.getString(_key);
    notifyListeners();
  }

  Future<void> setFolder(String path) async {
    _folder = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }
}
