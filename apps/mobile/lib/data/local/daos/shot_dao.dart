// Shot DAO — VSP Mobile App
//
// SQLite Data Access Object for Shot entities.
// Provides CRUD operations on the shots table.
//
// Story 10.3 — Slice 1: Domain + Persistence

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/shot.dart';
import '../../../domain/models/sync_status.dart';
import '../tables/shots_table.dart';

/// Data Access Object for Shot persistence.
/// Uses vsp_shots.db (separate from vsp_round.db).
class ShotDao {
  static const String _dbName = 'vsp_shots.db';
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
    await db.execute(kShotsTableCreateSql);
    await db.execute(kShotsTableRoundIndexSql);
    await db.execute(kShotsTableRoundPlayerIndexSql);
    await db.execute(kShotsTableSyncStatusIndexSql);
  }

  // ─── Create / Update ───────────────────────────────────────────────────

  /// Insert a new shot. Uses REPLACE to handle duplicate IDs.
  Future<void> insert(Shot shot) async {
    final db = await _database;
    await db.insert(
      kShotsTableName,
      shot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing shot by ID.
  Future<void> update(Shot shot) async {
    final db = await _database;
    final updated = shot.copyWith(updatedAt: DateTime.now());
    await db.update(
      kShotsTableName,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [shot.id],
    );
  }

  /// Upsert a shot (insert or replace).
  Future<void> upsert(Shot shot) async {
    final db = await _database;
    await db.insert(
      kShotsTableName,
      shot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Soft-delete a shot by ID (sets merged_into_shot_id and marks pending sync).
  Future<void> softDelete(String id) async {
    final db = await _database;
    await db.rawUpdate(
      '''
      UPDATE $kShotsTableName
      SET merged_into_shot_id = id,
          sync_status = ?,
          updated_at = ?
      WHERE id = ?
    ''',
      [SyncStatus.pending.name, DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  // ─── Read ──────────────────────────────────────────────────────────────

  /// Retrieve a shot by ID.
  Future<Shot?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      kShotsTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Shot.fromMap(rows.first);
  }

  /// Retrieve a shot by idempotency key.
  Future<Shot?> getByIdempotencyKey(String idempotencyKey) async {
    final db = await _database;
    final rows = await db.query(
      kShotsTableName,
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Shot.fromMap(rows.first);
  }

  /// Retrieve all shots for a round, ordered by hole then shot.
  Future<List<Shot>> getByRoundId(String roundId) async {
    final db = await _database;
    final rows = await db.query(
      kShotsTableName,
      where: 'round_id = ?',
      whereArgs: [roundId],
      orderBy: 'hole_number ASC, shot_number ASC',
    );
    return rows.map((row) => Shot.fromMap(row)).toList();
  }

  /// Retrieve all shots for a player in a round.
  Future<List<Shot>> getByRoundAndPlayer(
    String roundId,
    String playerId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kShotsTableName,
      where: 'round_id = ? AND player_id = ?',
      whereArgs: [roundId, playerId],
      orderBy: 'hole_number ASC, shot_number ASC',
    );
    return rows.map((row) => Shot.fromMap(row)).toList();
  }

  /// Retrieve all active (non-ended) shots for a round.
  Future<List<Shot>> getActiveByRoundId(String roundId) async {
    final db = await _database;
    final rows = await db.query(
      kShotsTableName,
      where: 'round_id = ? AND ended_at IS NULL',
      whereArgs: [roundId],
      orderBy: 'hole_number ASC, shot_number ASC',
    );
    return rows.map((row) => Shot.fromMap(row)).toList();
  }

  /// Retrieve all shots with a specific sync status.
  Future<List<Shot>> getBySyncStatus(SyncStatus status) async {
    final db = await _database;
    final rows = await db.query(
      kShotsTableName,
      where: 'sync_status = ?',
      whereArgs: [status.name],
    );
    return rows.map((row) => Shot.fromMap(row)).toList();
  }

  /// Retrieve all pending shots for a round (local changes not yet synced).
  Future<List<Shot>> getPendingByRoundId(String roundId) async {
    final db = await _database;
    final rows = await db.query(
      kShotsTableName,
      where: "round_id = ? AND sync_status IN ('pending', 'failed')",
      whereArgs: [roundId],
      orderBy: 'updated_at ASC',
    );
    return rows.map((row) => Shot.fromMap(row)).toList();
  }

  /// Count shots for a round.
  Future<int> countByRoundId(String roundId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $kShotsTableName WHERE round_id = ?',
      [roundId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
