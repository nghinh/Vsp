// Target Local Store — VSP Mobile App
//
// SQLite-backed local persistence for targets.
// Follows the RoundSyncStore pattern: separate db file (vsp_target.db),
// upsert semantics, indexed by round_id + hole_number.
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'package:sqflite/sqflite.dart';

import '../domain/target_model.dart';

/// SQLite store for target persistence.
///
/// Uses a separate database file (vsp_target.db) to keep target
/// lifecycle independent from round data.
class TargetLocalStore {
  static const String _tableName = 'targets';
  static const String _dbName = 'vsp_target.db';
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
        hole_number INTEGER NOT NULL,
        longitude REAL NOT NULL,
        latitude REAL NOT NULL,
        accuracy TEXT NOT NULL,
        source TEXT NOT NULL,
        placed_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    // Unique index per round + hole: one target per hole per round
    await db.execute('''
      CREATE UNIQUE INDEX idx_target_round_hole
      ON $_tableName (round_id, hole_number)
    ''');
    // Index for fetching all targets in a round
    await db.execute('''
      CREATE INDEX idx_target_round
      ON $_tableName (round_id)
    ''');
  }

  /// Upsert a target. Uses INSERT ... ON CONFLICT DO UPDATE so placing
  /// a new target on the same hole replaces the existing one.
  Future<void> upsertTarget(TargetModel target) async {
    final db = await database;
    final row = target.toRow();
    await db.insert(
      _tableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve the target for a round + hole, or null if none.
  Future<TargetModel?> getTarget(String roundId, int holeNumber) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'round_id = ? AND hole_number = ?',
      whereArgs: [roundId, holeNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TargetModel.fromRow(rows.first);
  }

  /// Delete the target for a round + hole.
  Future<void> deleteTarget(String roundId, int holeNumber) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'round_id = ? AND hole_number = ?',
      whereArgs: [roundId, holeNumber],
    );
  }

  /// Return all targets for a round.
  Future<List<TargetModel>> getTargetsForRound(String roundId) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'round_id = ?',
      whereArgs: [roundId],
      orderBy: 'hole_number ASC',
    );
    return rows.map((row) => TargetModel.fromRow(row)).toList();
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
