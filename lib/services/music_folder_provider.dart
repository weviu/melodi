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

    // On Android, validate the saved folder is actually writable.
    // Some devices (custom Android skins) don't expose MANAGE_EXTERNAL_STORAGE,
    // so paths outside the app-specific dir may fail with EPERM.
    if (Platform.isAndroid) {
      if (_folder != null && !await _isWritable(_folder!)) {
        _folder = null;
        await prefs.remove(_key);
      }
      if (_folder == null) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final defaultDir = Directory(p.join(extDir.path, 'Music', 'Melodi'));
          await defaultDir.create(recursive: true);
          _folder = defaultDir.path;
          await prefs.setString(_key, _folder!);
        }
      }
    }

    notifyListeners();
  }

  /// Returns true if [path] is a directory we can create files in.
  Future<bool> _isWritable(String path) async {
    try {
      final dir = Directory(path);
      await dir.create(recursive: true);
      final probe = File(p.join(path, '.melodi_write_test'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setFolder(String path) async {
    _folder = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }
}
