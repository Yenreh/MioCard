import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single SQLite database shared by every local data source.
class AppDatabase {
  static const int _version = 2;
  static Database? _database;

  static Future<Database> get instance async {
    return _database ??= await _open();
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'miocard.db');

    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await _createCards(db);
        await _createFavoriteStops(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createFavoriteStops(db);
      },
    );
  }

  static Future<void> _createCards(Database db) {
    return db.execute('''
      CREATE TABLE cards (
        internal_id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        prefix TEXT,
        suffix TEXT,
        name TEXT NOT NULL,
        position INTEGER DEFAULT 0,
        balance REAL,
        last_update INTEGER
      )
    ''');
  }

  static Future<void> _createFavoriteStops(Database db) {
    return db.execute('''
      CREATE TABLE favorite_stops (
        stop_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        anchor_latitude REAL NOT NULL,
        anchor_longitude REAL NOT NULL,
        position INTEGER DEFAULT 0
      )
    ''');
  }
}
