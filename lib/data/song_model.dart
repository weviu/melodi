import 'dart:typed_data';

class Song {
  final int? id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Uint8List? albumArt;

  const Song({
    this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    this.albumArt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'file_path': filePath,
        'album_art': albumArt,
      };

  static Song fromMap(Map<String, dynamic> map) => Song(
        id: map['id'] as int?,
        title: map['title'] as String? ?? 'Unknown Title',
        artist: map['artist'] as String? ?? 'Unknown Artist',
        album: map['album'] as String? ?? 'Unknown Album',
        filePath: map['file_path'] as String,
        albumArt: map['album_art'] as Uint8List?,
      );
}
