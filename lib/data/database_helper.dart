import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE songs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              album TEXT NOT NULL,
              file_path TEXT NOT NULL UNIQUE,
              album_art BLOB,
              play_count INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE recent_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              item_type TEXT NOT NULL,
              item_id TEXT NOT NULL,
              played_at TEXT NOT NULL,
              UNIQUE(item_type, item_id)
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE songs ADD COLUMN play_count INTEGER DEFAULT 0',
            );
            await db.execute('''
              CREATE TABLE IF NOT EXISTS recent_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                item_type TEXT NOT NULL,
                item_id TEXT NOT NULL,
                played_at TEXT NOT NULL,
                UNIQUE(item_type, item_id)
              )
            ''');
          }
        },
      ),
    );
  }

  // ── Songs ──────────────────────────────────────────────────────────────────

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

  Future<void> deleteSong(String filePath) async {
    final db = await database;
    await db.delete('songs', where: 'file_path = ?', whereArgs: [filePath]);
  }

  Future<void> incrementPlayCount(String filePath) async {
    final db = await database;
    await db.execute(
      'UPDATE songs SET play_count = play_count + 1 WHERE file_path = ?',
      [filePath],
    );
  }

  /// Returns one Song with album art for the given artist, or null.
  Future<Song?> getSongWithArtByArtist(String artist) async {
    final db = await database;
    final maps = await db.query(
      'songs',
      where: 'artist = ? AND album_art IS NOT NULL',
      whereArgs: [artist],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Song.fromMap(maps.first);
  }

  // ── Recent items ───────────────────────────────────────────────────────────

  Future<void> insertOrUpdateRecentItem(String type, String id) async {
    final db = await database;
    // Delete existing entry then re-insert to update played_at
    await db.delete(
      'recent_items',
      where: 'item_type = ? AND item_id = ?',
      whereArgs: [type, id],
    );
    await db.insert('recent_items', {
      'item_type': type,
      'item_id': id,
      'played_at': DateTime.now().toUtc().toIso8601String(),
    });
    // Cap at 50 rows — remove oldest beyond limit
    await db.execute('''
      DELETE FROM recent_items
      WHERE id NOT IN (
        SELECT id FROM recent_items ORDER BY played_at DESC LIMIT 50
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getRecentItems({int limit = 8}) async {
    final db = await database;
    return db.query('recent_items', orderBy: 'played_at DESC', limit: limit);
  }

  // ── Artists / stats ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTopArtists({int limit = 10}) async {
    final db = await database;
    return db.rawQuery('''
      SELECT artist, SUM(play_count) AS total_plays, COUNT(*) AS song_count
      FROM songs
      WHERE artist != '' AND artist != 'Unknown Artist'
      GROUP BY artist
      ORDER BY total_plays DESC, song_count DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<int> getDistinctArtistCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(DISTINCT artist) AS cnt FROM songs "
      "WHERE artist != '' AND artist != 'Unknown Artist'",
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
