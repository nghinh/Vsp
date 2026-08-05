// Player Repository — VSP Mobile App
//
// SQLite-backed persistence for Player entities in a round.
// Shares vsp_round.db with RoundRepository and HoleScoreRepository.
//
// Story 5.2: Persist Round Locally

import 'package:sqflite/sqflite.dart';

import '../../domain/models/player.dart';
import '../local/round_database.dart';

/// Repository for persisting and retrieving Player entities locally.
class PlayerRepository {
  static const String _tableName = 'players';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    // `players` lives in the shared `vsp_round.db`; open via the shared helper
    // so the full schema exists regardless of open order.
    _db = await openRoundDatabase();
    return _db!;
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
