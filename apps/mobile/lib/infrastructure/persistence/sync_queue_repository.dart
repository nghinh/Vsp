// SyncQueueRepository — VSP Mobile App
//
// SQLite-backed persistence layer for the sync event queue.
// Events survive app restart — guaranteeing offline durability.
//
// Story 5.4: Synchronize Round Idempotently — Slice 3

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/sync_event.dart';
import '../../domain/models/sync_status.dart';

/// Repository for persisting and retrieving [SyncEvent] entities locally.
///
/// Uses its own SQLite database (`vsp_sync.db`) to keep the sync queue
/// independent from the round data store.
class SyncQueueRepository {
  static const String _tableName = 'sync_events';
  static const String _dbName = 'vsp_sync.db';
  static const int _dbVersion = 1;

  Database? _db;
  final Uuid _uuid = const Uuid();

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
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_attempt_at INTEGER,
        error_message TEXT
      )
    ''');

    // Index for fetching pending events in order.
    await db.execute('''
      CREATE INDEX idx_sync_events_pending
      ON $_tableName (created_at)
      WHERE state = 'pending'
    ''');

    // Index for entity-level queries (e.g., all events for a round).
    await db.execute('''
      CREATE INDEX idx_sync_events_entity
      ON $_tableName (type, entity_id)
    ''');
  }

  // -------------------------------------------------------------------------
  // Event lifecycle
  // -------------------------------------------------------------------------

  /// Generate a new UUID v4 idempotency key.
  String generateIdempotencyKey() => _uuid.v4();

  /// Append a new sync event with state = pending.
  ///
  /// Uses INSERT ... ON CONFLICT DO UPDATE so duplicate keys
  /// refresh the payload rather than creating duplicate entries.
  Future<void> append(SyncEvent event) async {
    final db = await _database;
    await db.rawInsert(
      '''
      INSERT INTO $_tableName (id, type, entity_id, payload, state, attempt_count, created_at, last_attempt_at, error_message)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        payload = excluded.payload,
        state = excluded.state,
        attempt_count = excluded.attempt_count,
        last_attempt_at = excluded.last_attempt_at,
        error_message = excluded.error_message
    ''',
      [
        event.id,
        event.type.name,
        event.entityId,
        event.payload,
        SyncStatus.pending.name,
        0,
        event.createdAt.millisecondsSinceEpoch,
        null,
        null,
      ],
    );
  }

  /// Mark an event as currently syncing.
  Future<void> markSyncing(String id) async {
    final db = await _database;
    await db.update(
      _tableName,
      {
        'state': SyncStatus.syncing.name,
        'last_attempt_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark an event as successfully synced.
  Future<void> markSynced(String id) async {
    final db = await _database;
    await db.update(
      _tableName,
      {
        'state': SyncStatus.synced.name,
        'last_attempt_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark an event as permanently failed with an error message.
  Future<void> markFailed(String id, String error) async {
    final db = await _database;
    await db.update(
      _tableName,
      {
        'state': SyncStatus.failed.name,
        'error_message': error,
        'last_attempt_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increment the attempt count for an event (without changing state).
  Future<void> incrementAttemptCount(String id) async {
    final db = await _database;
    await db.rawUpdate(
      '''
      UPDATE $_tableName
      SET attempt_count = attempt_count + 1,
          last_attempt_at = ?
      WHERE id = ?
    ''',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  // -------------------------------------------------------------------------
  // Queries
  // -------------------------------------------------------------------------

  /// Return all pending (and in-flight) events ordered by creation time.
  Future<List<SyncEvent>> getPending() async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: "state IN ('pending', 'syncing')",
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => _fromRow(row)).toList();
  }

  /// Return all events for a specific entity.
  Future<List<SyncEvent>> getForEntity(
    SyncEventType type,
    String entityId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'type = ? AND entity_id = ?',
      whereArgs: [type.name, entityId],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => _fromRow(row)).toList();
  }

  /// Return all events.
  Future<List<SyncEvent>> getAll() async {
    final db = await _database;
    final rows = await db.query(_tableName, orderBy: 'created_at ASC');
    return rows.map((row) => _fromRow(row)).toList();
  }

  /// Number of pending events.
  Future<int> pendingCount() async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM $_tableName
      WHERE state IN ('pending', 'syncing')
    ''');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// True if there is at least one pending event.
  Future<bool> hasPending() async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT 1 FROM $_tableName
      WHERE state IN ('pending', 'syncing')
      LIMIT 1
    ''');
    return result.isNotEmpty;
  }

  /// True if any pending event has reached max attempts.
  Future<bool> hasFailedEvents({required int maxAttempts}) async {
    final db = await _database;
    final result = await db.rawQuery(
      '''
      SELECT 1 FROM $_tableName
      WHERE state = 'pending' AND attempt_count >= ?
      LIMIT 1
    ''',
      [maxAttempts],
    );
    return result.isNotEmpty;
  }

  /// Remove all synced events to free up space.
  Future<int> purgeSynced() async {
    final db = await _database;
    return db.delete(
      _tableName,
      where: 'state = ?',
      whereArgs: [SyncStatus.synced.name],
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  SyncEvent _fromRow(Map<String, dynamic> row) {
    return SyncEvent(
      id: row['id'] as String,
      type: SyncEventType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => SyncEventType.scoreUpdate,
      ),
      entityId: row['entity_id'] as String,
      payload: row['payload'] as String,
      state: SyncStatus.values.firstWhere(
        (e) => e.name == row['state'],
        orElse: () => SyncStatus.pending,
      ),
      attemptCount: ((row['attempt_count'] as num?)?.toInt()) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as num).toInt()),
      lastAttemptAt: row['last_attempt_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((row['last_attempt_at'] as num).toInt())
          : null,
      errorMessage: row['error_message'] as String?,
    );
  }
}
