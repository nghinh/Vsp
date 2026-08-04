// Player Repository — VSP Mobile App
//
// SQLite-backed persistence for Player entities in a round.
// Shares vsp_round.db with RoundRepository and HoleScoreRepository.
//
// Story 5.2: Persist Round Locally

import 'package:sqflite/sqflite.dart';

import '../../domain/models/player.dart';

/// Repository for persisting and retrieving Player entities locally.
class PlayerRepository {
  static const String _tableName = 'players';
  static const String _dbName = 'vsp_round.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        round_id TEXT NOT NULL,
        name TEXT NOT NULL,
        handicap REAL,
        is_current_user INTEGER NOT NULL
      )
    ''');

    // Index for round lookup
    await db.execute('''
      CREATE INDEX idx_players_round ON $_tableName (round_id)
    ''');
  }

  /// Add a player to a round.
  Future<void> addPlayer(Player player, String roundId) async {
    final db = await database;
    await db.insert(
      _tableName,
      player.toMap(roundId),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Retrieve all players for a round.
  Future<List<Player>> getPlayersForRound(String roundId) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'round_id = ?',
      whereArgs: [roundId],
    );
    return rows.map((row) => Player.fromMap(row)).toList();
  }

  /// Remove a player by ID.
  Future<void> removePlayer(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
