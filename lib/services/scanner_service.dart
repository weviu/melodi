import 'dart:io';

import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as p;

import '../data/song_model.dart';

class ScannerService {
  Future<List<Song>> scanDirectory(String dirPath) async {
    final songs = <Song>[];
    final dir = Directory(dirPath);

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith('.mp3')) {
        Song song;
        try {
          final metadata = await MetadataGod.readMetadata(file: entity.path);
          song = Song(
            title: (metadata.title?.isNotEmpty == true)
                ? metadata.title!
                : p.basenameWithoutExtension(entity.path),
            artist: (metadata.artist?.isNotEmpty == true)
                ? metadata.artist!
                : 'Unknown Artist',
            album: (metadata.album?.isNotEmpty == true)
                ? metadata.album!
                : 'Unknown Album',
            filePath: entity.path,
            albumArt: metadata.picture?.data,
          );
        } catch (_) {
          song = Song(
            title: p.basenameWithoutExtension(entity.path),
            artist: 'Unknown Artist',
            album: 'Unknown Album',
            filePath: entity.path,
          );
        }
        songs.add(song);
      }
    }

    return songs;
  }
}
