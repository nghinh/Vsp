// Profile Sync Store — VSP Mobile App
//
// SQLite-backed offline queue for profile edits.
// Stores pending UpdateProfileRequest payloads with idempotency keys so they
// can be flushed to the server when connectivity is restored.
//
// Conflict policy (per architecture.md §8.3):
//   Profile edits follow "latest client edit wins" — the server accepts
//   the most recent write based on idempotency key timestamp.
//   The sync queue is ordered by created_at; older entries are synced first.

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../features/profile/data/profile_dto.dart';

/// A queued profile update entry.
class QueuedProfileUpdate {
  /// Unique idempotency key — also serves as the SQLite row primary key.
  final String idempotencyKey;

  /// JSON payload of UpdateProfileRequest.
  final String payload;

  /// When this entry was queued (UTC).
  final DateTime createdAt;

  /// When this entry was successfully synced (null = pending).
  final DateTime? syncedAt;

  const QueuedProfileUpdate({
    required this.idempotencyKey,
    required this.payload,
    required this.createdAt,
    this.syncedAt,
  });

  /// Parse from a SQLite row map.
  factory QueuedProfileUpdate.fromRow(Map<String, dynamic> row) {
    return QueuedProfileUpdate(
      idempotencyKey: row['idempotency_key'] as String,
      payload: row['payload'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      syncedAt: row['synced_at'] != null
          ? DateTime.parse(row['synced_at'] as String)
          : null,
    );
  }

  /// Decode the payload JSON into an UpdateProfileRequest.
  UpdateProfileRequest get request {
    return UpdateProfileRequest.fromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
  }

  /// True if this entry has been synced.
  bool get isSynced => syncedAt != null;
}

/// SQLite-backed store for profile sync queue.
class ProfileSyncStore {
  static const String _tableName = 'profile_sync_queue';
  static const String _dbName = 'vsp_profile_sync.db';
  static const int _dbVersion = 1;

  Database? _db;

  /// Lazily initialize the database.
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
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');
    // Index for fast pending-queue queries
    await db.execute('''
      CREATE INDEX idx_profile_sync_pending
      ON $_tableName (created_at)
      WHERE synced_at IS NULL
    ''');
  }

  // ─── Enqueue ───────────────────────────────────────────────────────────────

  /// Add a profile update to the offline queue.
  ///
  /// If an entry with the same idempotency key already exists (synced or
  /// pending), this is a no-op — the existing entry is kept.
  /// This prevents duplicate queuing when the same edit is submitted multiple
  /// times (e.g. user taps save repeatedly while offline).
  Future<void> enqueue(
    String idempotencyKey,
    UpdateProfileRequest request,
  ) async {
    final db = await _database;
    final payload = jsonEncode(request.toJson());
    final now = DateTime.now().toUtc().toIso8601String();

    // Upsert — insert or replace; SQLite UPSERT syntax
    await db.rawInsert(
      '''
      INSERT INTO $_tableName (idempotency_key, payload, created_at, synced_at)
      VALUES (?, ?, ?, NULL)
      ON CONFLICT(idempotency_key) DO UPDATE SET
        payload = excluded.payload,
        created_at = excluded.created_at,
        synced_at = NULL
    ''',
      [idempotencyKey, payload, now],
    );
  }

  // ─── Dequeue ───────────────────────────────────────────────────────────────

  /// Return all pending (not yet synced) queue entries ordered by creation time.
  Future<List<QueuedProfileUpdate>> dequeueAll() async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => QueuedProfileUpdate.fromRow(row)).toList();
  }

  // ─── Mark Synced ───────────────────────────────────────────────────────────

  /// Mark a queue entry as synced by idempotency key.
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

  // ─── Has Pending ───────────────────────────────────────────────────────────

  /// True if there is at least one pending (un-synced) entry.
  Future<bool> hasPending() async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT 1 FROM $_tableName WHERE synced_at IS NULL LIMIT 1
    ''');
    return result.isNotEmpty;
  }

  // ─── Count ────────────────────────────────────────────────────────────────

  /// Number of pending entries in the queue.
  Future<int> pendingCount() async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM $_tableName WHERE synced_at IS NULL
    ''');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ─── Purge Synced ─────────────────────────────────────────────────────────

  /// Remove all successfully synced entries from the queue.
  /// Called periodically to keep the table lean.
  Future<int> purgeSynced() async {
    final db = await _database;
    return db.delete(_tableName, where: 'synced_at IS NOT NULL');
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
