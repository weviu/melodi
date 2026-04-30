import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

    // On Android, auto-set a default folder if none is saved yet
    if (_folder == null && Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final defaultDir = Directory(p.join(extDir.path, 'Music', 'Melodi'));
        await defaultDir.create(recursive: true);
        _folder = defaultDir.path;
        await prefs.setString(_key, _folder!);
      }
    }

    notifyListeners();
  }

  Future<void> setFolder(String path) async {
    _folder = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }
}
