import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'song_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'melodi.db');
    return databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE songs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              album TEXT NOT NULL,
              file_path TEXT NOT NULL UNIQUE,
              album_art BLOB
            )
          ''');
        },
      ),
    );
  }

  Future<void> insertSongs(List<Song> songs) async {
    final db = await database;
    final batch = db.batch();
    for (final song in songs) {
      batch.insert(
        'songs',
        song.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Song>> getAllSongs() async {
    final db = await database;
    final maps = await db.query('songs', orderBy: 'title ASC');
    return maps.map(Song.fromMap).toList();
  }

  Future<void> clearSongs() async {
    final db = await database;
    await db.delete('songs');
  }
}
