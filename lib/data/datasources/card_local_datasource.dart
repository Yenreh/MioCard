import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/card_model.dart';

/// Local data source using SQLite
class CardLocalDatasource {
  static Database? _database;
  static const String _tableName = 'cards';

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'miocard.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
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
      },
    );
  }

  /// Get all cards
  Future<List<CardModel>> getAllCards() async {
    final db = await database;
    final maps = await db.query(_tableName, orderBy: 'position ASC, name ASC');
    return maps.map((map) => CardModel.fromMap(map)).toList();
  }

  /// Get card by ID
  Future<CardModel?> getCardById(String cardId) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'card_id = ?',
      whereArgs: [cardId],
    );
    if (maps.isEmpty) return null;
    return CardModel.fromMap(maps.first);
  }

  /// Insert a new card
  Future<void> insertCard(CardModel card) async {
    final db = await database;
    await db.insert(
      _tableName,
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing card
  Future<void> updateCard(CardModel card) async {
    final db = await database;
    await db.update(
      _tableName,
      card.toMap(),
      where: 'internal_id = ?',
      whereArgs: [card.internalId],
    );
  }

  /// Delete a card
  Future<void> deleteCard(String cardId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'card_id = ?',
      whereArgs: [cardId],
    );
  }

  /// Update card balance
  Future<void> updateCardBalance(String cardId, double balance, DateTime lastUpdate) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        'balance': balance,
        'last_update': lastUpdate.millisecondsSinceEpoch,
      },
      where: 'card_id = ?',
      whereArgs: [cardId],
    );
  }
}
