// HoleScore Repository — VSP Mobile App
//
// SQLite-backed persistence for HoleScore entities.
// Shares vsp_round.db with RoundRepository.
//
// Story 5.2: Persist Round Locally

import 'package:sqflite/sqflite.dart';

import '../../domain/models/hole_score.dart';
import '../local/round_database.dart';

/// Repository for persisting and retrieving HoleScore entities locally.
class HoleScoreRepository {
  static const String _tableName = 'hole_scores';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    // `hole_scores` lives in the shared `vsp_round.db`; open via the shared
    // helper so the full schema exists regardless of open order.
    _db = await openRoundDatabase();
    return _db!;
  }

  /// Insert a new hole score.
  Future<void> createScore(HoleScore score) async {
    final db = await database;
    await db.insert(
      _tableName,
      score.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Update an existing hole score.
  Future<void> updateScore(HoleScore score) async {
    final db = await database;
    final updated = score.copyWith(updatedAt: DateTime.now());
    await db.update(
      _tableName,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [score.id],
    );
  }

  /// Delete a hole score by ID.
  Future<void> deleteScore(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Retrieve all scores for a round.
  Future<List<HoleScore>> getScoresForRound(String roundId) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'round_id = ?',
      whereArgs: [roundId],
      orderBy: 'hole_number ASC',
    );
    return rows.map((row) => HoleScore.fromMap(row)).toList();
  }

  /// Retrieve the score for a specific hole in a round.
  Future<HoleScore?> getScoreForHole(String roundId, int holeNumber) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'round_id = ? AND hole_number = ?',
      whereArgs: [roundId, holeNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HoleScore.fromMap(rows.first);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
