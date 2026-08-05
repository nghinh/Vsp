// Round Repository — VSP Mobile App
//
// SQLite-backed persistence for Round entities.
// Uses vsp_round.db, shared with HoleScoreRepository and PlayerRepository.
//
// Story 5.2: Persist Round Locally

import 'package:sqflite/sqflite.dart';

import '../../domain/models/round.dart';
import '../local/round_database.dart';

/// Repository for persisting and retrieving Round entities locally.
class RoundRepository {
  static const String _tableName = 'rounds';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    // `rounds` lives in the shared `vsp_round.db`; the shared opener owns the
    // full schema and the v1→v2 tournament-column migration.
    _db = await openRoundDatabase();
    return _db!;
  }

  /// Insert a new round. Uses ON CONFLICT rollback for atomicity.
  Future<void> createRound(Round round) async {
    final db = await database;
    await db.insert(
      _tableName,
      round.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Update an existing round.
  Future<void> updateRound(Round round) async {
    final db = await database;
    final updated = round.copyWith(updatedAt: DateTime.now());
    await db.update(
      _tableName,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [round.id],
    );
  }

  /// Retrieve a round by ID.
  Future<Round?> getRound(String id) async {
    final db = await database;
    final rows = await db.query(_tableName, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Round.fromMap(rows.first);
  }

  /// Retrieve the currently active round (status = 'inProgress').
  Future<Round?> getActiveRound() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: [RoundStatus.inProgress.name],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Round.fromMap(rows.first);
  }

  /// Retrieve all rounds for a course.
  Future<List<Round>> getRoundsByCourse(int courseId) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'started_at DESC',
    );
    return rows.map((row) => Round.fromMap(row)).toList();
  }

  /// Execute a transaction wrapping multiple table writes atomically.
  Future<T> transactional<T>(Future<T> Function(Transaction) action) async {
    final db = await database;
    return db.transaction(action);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
