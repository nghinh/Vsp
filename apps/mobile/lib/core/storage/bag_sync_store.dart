// Bag Sync Store — VSP Mobile App
//
// SQLite-backed offline queue for bag and club edits.
// Mirrors the ProfileSyncStore pattern from Story 2-3-B.

import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Operation types for the bag sync queue.
enum BagSyncOperation {
  createBag,
  updateBag,
  deleteBag,
  setActiveBag,
  createClub,
  updateClub,
  deleteClub,
}

/// A queued bag/club operation entry.
class QueuedBagUpdate {
  final String idempotencyKey;
  final BagSyncOperation operation;
  final int? bagId;
  final int? clubId;
  final String payload;
  final DateTime createdAt;
  final DateTime? syncedAt;

  const QueuedBagUpdate({
    required this.idempotencyKey,
    required this.operation,
    this.bagId,
    this.clubId,
    required this.payload,
    required this.createdAt,
    this.syncedAt,
  });

  factory QueuedBagUpdate.fromRow(Map<String, dynamic> row) {
    return QueuedBagUpdate(
      idempotencyKey: row['idempotency_key'] as String,
      operation: BagSyncOperation.values.firstWhere(
        (e) => e.name == row['operation'],
        orElse: () => BagSyncOperation.createBag,
      ),
      bagId: row['bag_id'] as int?,
      clubId: row['club_id'] as int?,
      payload: row['payload'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      syncedAt: row['synced_at'] != null
          ? DateTime.parse(row['synced_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> get payloadMap =>
      jsonDecode(payload) as Map<String, dynamic>;

  bool get isSynced => syncedAt != null;
}

/// SQLite-backed store for bag/club sync queue.
class BagSyncStore {
  static const String _tableName = 'bag_sync_queue';
  static const String _dbName = 'vsp_bag_sync.db';
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
    await db.execute('''
      CREATE TABLE $_tableName (
        idempotency_key TEXT PRIMARY KEY,
        operation TEXT NOT NULL,
        bag_id INTEGER,
        club_id INTEGER,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_bag_sync_pending
      ON $_tableName (created_at)
      WHERE synced_at IS NULL
    ''');
  }

  /// Enqueue a bag operation.
  Future<void> enqueueBagOp({
    required String idempotencyKey,
    required BagSyncOperation operation,
    required int bagId,
    String? payload,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawInsert(
      '''
      INSERT INTO $_tableName (idempotency_key, operation, bag_id, club_id, payload, created_at, synced_at)
      VALUES (?, ?, ?, NULL, ?, ?, NULL)
      ON CONFLICT(idempotency_key) DO UPDATE SET
        payload = excluded.payload,
        created_at = excluded.created_at,
        synced_at = NULL
    ''',
      [idempotencyKey, operation.name, bagId, payload ?? '{}', now],
    );
  }

  /// Enqueue a club operation.
  Future<void> enqueueClubOp({
    required String idempotencyKey,
    required BagSyncOperation operation,
    required int bagId,
    required int clubId,
    String? payload,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawInsert(
      '''
      INSERT INTO $_tableName (idempotency_key, operation, bag_id, club_id, payload, created_at, synced_at)
      VALUES (?, ?, ?, ?, ?, ?, NULL)
      ON CONFLICT(idempotency_key) DO UPDATE SET
        payload = excluded.payload,
        created_at = excluded.created_at,
        synced_at = NULL
    ''',
      [idempotencyKey, operation.name, bagId, clubId, payload ?? '{}', now],
    );
  }

  /// Return all pending queue entries ordered by creation time.
  Future<List<QueuedBagUpdate>> dequeueAll() async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => QueuedBagUpdate.fromRow(row)).toList();
  }

  /// Mark a queue entry as synced.
  Future<void> markSynced(String idempotencyKey) async {
    final db = await _database;
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
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT 1 FROM $_tableName WHERE synced_at IS NULL LIMIT 1
    ''');
    return result.isNotEmpty;
  }

  /// Number of pending entries.
  Future<int> pendingCount() async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM $_tableName WHERE synced_at IS NULL
    ''');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Remove all synced entries.
  Future<int> purgeSynced() async {
    final db = await _database;
    return db.delete(_tableName, where: 'synced_at IS NOT NULL');
  }

  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
