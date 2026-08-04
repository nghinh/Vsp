// Round Sync Store — VSP Mobile App
//
// SQLite-backed offline queue for round operations.
// Mirrors the BagSyncStore pattern from core/storage/bag_sync_store.dart.
//
// Story 5.2: Persist Round Locally

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/queued_round_update.dart';
import '../../domain/models/round_sync_operation.dart';

/// SQLite-backed store for round sync queue.
class RoundSyncStore {
  static const String _tableName = 'round_sync_queue';
  static const String _dbName = 'vsp_round.db';
  static const int _dbVersion = 1;

  Database? _db;
  final Uuid _uuid = const Uuid();

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
        idempotency_key TEXT PRIMARY KEY,
        operation TEXT NOT NULL,
        round_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_round_sync_pending
      ON $_tableName (created_at)
      WHERE synced_at IS NULL
    ''');
  }

  /// Generate an idempotency key for a round operation.
  ///
  /// Format: round_{uuid}_{operation}_{timestamp_ms}
  /// Example: round_770e8400-e29b-41d4-a716_updateHoleScore_7200000
  String generateIdempotencyKey({
    required String roundId,
    required RoundSyncOperation operation,
  }) {
    final uuid = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'round_${uuid}_${operation.name}_$timestamp';
  }

  /// Enqueue a round operation with idempotency dedup.
  ///
  /// Uses INSERT ... ON CONFLICT DO UPDATE so duplicate keys
  /// refresh the payload rather than creating duplicate entries.
  Future<void> enqueueRoundOp({
    required String idempotencyKey,
    required RoundSyncOperation operation,
    required String roundId,
    String? payload,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawInsert(
      '''
      INSERT INTO $_tableName (idempotency_key, operation, round_id, payload, created_at, synced_at, retry_count)
      VALUES (?, ?, ?, ?, ?, NULL, 0)
      ON CONFLICT(idempotency_key) DO UPDATE SET
        operation = excluded.operation,
        round_id = excluded.round_id,
        payload = excluded.payload,
        created_at = excluded.created_at,
        synced_at = NULL,
        retry_count = 0
    ''',
      [idempotencyKey, operation.name, roundId, payload ?? '{}', now],
    );
  }

  /// Return all pending queue entries ordered by creation time.
  Future<List<QueuedRoundUpdate>> dequeueAll() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => QueuedRoundUpdate.fromRow(row)).toList();
  }

  /// Mark a queue entry as synced.
  Future<void> markSynced(String idempotencyKey) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      _tableName,
      {'synced_at': now},
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
    );
  }

  /// True if there is at least one pending entry.
  Future<bool> hasPending() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 1 FROM $_tableName WHERE synced_at IS NULL LIMIT 1
    ''');
    return result.isNotEmpty;
  }

  /// Number of pending entries.
  Future<int> pendingCount() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM $_tableName WHERE synced_at IS NULL
    ''');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Increment the retry count for a queue entry.
  Future<void> incrementRetry(String idempotencyKey) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $_tableName
      SET retry_count = retry_count + 1
      WHERE idempotency_key = ?
    ''',
      [idempotencyKey],
    );
  }

  /// Remove all synced entries.
  Future<int> purgeSynced() async {
    final db = await database;
    return db.delete(_tableName, where: 'synced_at IS NOT NULL');
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
