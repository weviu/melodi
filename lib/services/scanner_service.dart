import 'dart:io';
import 'dart:typed_data';

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
        // MetadataGod native library is not available on Android builds.
        if (!Platform.isAndroid && !Platform.isIOS) {
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
        } else {
          // Android/iOS: MetadataGod unavailable; load sidecar .jpg if present
          Uint8List? sidecarArt;
          try {
            final jpgFile = File(p.withoutExtension(entity.path) + '.jpg');
            if (await jpgFile.exists()) {
              sidecarArt = await jpgFile.readAsBytes();
            }
          } catch (_) {}
          song = Song(
            title: p.basenameWithoutExtension(entity.path),
            artist: 'Unknown Artist',
            album: 'Unknown Album',
            filePath: entity.path,
            albumArt: sidecarArt,
          );
        }
        songs.add(song);
      }
    }

    return songs;
  }
}
