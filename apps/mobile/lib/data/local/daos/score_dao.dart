// Score DAO — VSP Mobile App
//
// SQLite Data Access Object for Score entities.
// Provides CRUD operations on the scores table.
// UNIQUE constraint: exactly one Score per (flightId, holeId, playerId).
//
// Story 5.3 — Slice 2: Score SQLite Persistence

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/score.dart';
import '../../../domain/models/score_value_objects.dart';
import '../tables/scores_table.dart';

/// Data Access Object for Score persistence.
class ScoreDao {
  static const String _dbName = 'vsp_round.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
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
    await db.execute(kScoresTableCreateSql);
    await db.execute(kScoresTableFlightHoleIndexSql);
    await db.execute(kScoresTableFlightPlayerIndexSql);
  }

  /// Insert a new score. Uses REPLACE to handle the UNIQUE constraint
  /// (upsert behavior for (flightId, holeId, playerId) tuple).
  Future<void> upsert(Score score) async {
    final db = await _database;
    await db.insert(
      kScoresTableName,
      score.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing score by ID with optimistic concurrency.
  /// Returns the number of rows updated (0 if version mismatch).
  Future<int> update(Score score) async {
    final db = await _database;
    final updated = score.copyWith(
      updatedAt: DateTime.now(),
      version: score.version + 1,
    );
    return db.update(
      kScoresTableName,
      updated.toMap(),
      where: 'id = ? AND version = ?',
      whereArgs: [score.id, score.version],
    );
  }

  /// Delete a score by ID.
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete(kScoresTableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Retrieve a score by ID.
  Future<Score?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      kScoresTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Score.fromMap(rows.first);
  }

  /// Retrieve the score for a specific player on a specific hole within a flight.
  /// Returns null if no score exists yet.
  Future<Score?> getByFlightHolePlayer({
    required String flightId,
    required String holeId,
    required String playerId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      kScoresTableName,
      where: 'flight_id = ? AND hole_id = ? AND player_id = ?',
      whereArgs: [flightId, holeId, playerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Score.fromMap(rows.first);
  }

  /// Retrieve all scores for a flight and a specific hole.
  Future<List<Score>> getByFlightAndHole({
    required String flightId,
    required String holeId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      kScoresTableName,
      where: 'flight_id = ? AND hole_id = ?',
      whereArgs: [flightId, holeId],
    );
    return rows.map((row) => Score.fromMap(row)).toList();
  }

  /// Retrieve all scores for a flight and a specific player.
  Future<List<Score>> getByFlightAndPlayer({
    required String flightId,
    required String playerId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      kScoresTableName,
      where: 'flight_id = ? AND player_id = ?',
      whereArgs: [flightId, playerId],
      orderBy: 'updated_at ASC',
    );
    return rows.map((row) => Score.fromMap(row)).toList();
  }

  /// Retrieve all scores for a flight.
  Future<List<Score>> getByFlightId(String flightId) async {
    final db = await _database;
    final rows = await db.query(
      kScoresTableName,
      where: 'flight_id = ?',
      whereArgs: [flightId],
      orderBy: 'updated_at ASC',
    );
    return rows.map((row) => Score.fromMap(row)).toList();
  }

  /// Retrieve all scores with a specific sync status.
  Future<List<Score>> getBySyncStatus(ScoreSyncStatus status) async {
    final db = await _database;
    final rows = await db.query(
      kScoresTableName,
      where: 'sync_status = ?',
      whereArgs: [status.name],
    );
    return rows.map((row) => Score.fromMap(row)).toList();
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
