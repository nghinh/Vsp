// Round Setup Store — VSP Mobile App
//
// Local SQLite persistence for round configuration before API sync.
// Stores round config locally so it survives app restart and works offline.
//
// Story 5.1 — Slice G: Integration and Active Round Guard Hook
// Story 5.2: Full transactional SQLite persistence (deferred)

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/round_config.dart';
import '../../domain/models/round_format.dart';
import '../../domain/models/round_mode.dart';
import '../../domain/models/player.dart';

/// Local round config record for offline persistence.
///
/// Stored before API call to ensure round config survives app restart
/// and works offline. Synced to server when connectivity is restored.
class LocalRoundConfigRecord {
  final String localId; // UUID generated locally
  final int courseId;
  final String courseName;
  final int? layoutId;
  final int? teeId;
  final String format; // RoundFormat.value
  final List<String> playerIds;
  final List<Map<String, dynamic>> playersJson;
  final String mode; // RoundMode.value
  final int? bagId;
  final int startHole;
  final String? holes;
  final DateTime startTime;
  final String? packageId;
  final String? tournamentPolicyId;
  final String status; // 'pending' | 'synced' | 'failed'
  final String? serverRoundId; // Populated after successful API sync
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final DateTime? lastAttemptAt;
  final int syncAttempts;

  const LocalRoundConfigRecord({
    required this.localId,
    required this.courseId,
    required this.courseName,
    this.layoutId,
    this.teeId,
    required this.format,
    required this.playerIds,
    required this.playersJson,
    required this.mode,
    this.bagId,
    required this.startHole,
    this.holes,
    required this.startTime,
    this.packageId,
    this.tournamentPolicyId,
    this.status = 'pending',
    this.serverRoundId,
    this.idempotencyKey,
    required this.createdAt,
    this.syncedAt,
    this.lastAttemptAt,
    this.syncAttempts = 0,
  });

  /// Create from a RoundConfig domain model.
  factory LocalRoundConfigRecord.fromRoundConfig({
    required String localId,
    required RoundConfig config,
    required String idempotencyKey,
  }) {
    return LocalRoundConfigRecord(
      localId: localId,
      courseId: config.courseId,
      courseName: config.courseName,
      layoutId: config.layoutId,
      teeId: config.teeId,
      format: config.format.value,
      playerIds: config.playerIds,
      playersJson: config.players.map((p) => p.toJson()).toList(),
      mode: config.mode.value,
      bagId: config.bagId,
      startHole: config.startHole,
      holes: config.holes,
      startTime: config.startTime,
      packageId: config.packageId,
      tournamentPolicyId: config.tournamentPolicyId,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );
  }

  /// Convert to SQLite map.
  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'course_id': courseId,
      'course_name': courseName,
      'layout_id': layoutId,
      'tee_id': teeId,
      'format': format,
      'player_ids': jsonEncode(playerIds),
      'players_json': jsonEncode(playersJson),
      'mode': mode,
      'bag_id': bagId,
      'start_hole': startHole,
      'holes': holes,
      'start_time': startTime.toIso8601String(),
      'package_id': packageId,
      'tournament_policy_id': tournamentPolicyId,
      'status': status,
      'server_round_id': serverRoundId,
      'idempotency_key': idempotencyKey,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'sync_attempts': syncAttempts,
    };
  }

  /// Reconstruct from SQLite row.
  factory LocalRoundConfigRecord.fromMap(Map<String, dynamic> map) {
    return LocalRoundConfigRecord(
      localId: map['local_id'] as String,
      courseId: (map['course_id'] as num).toInt(),
      courseName: map['course_name'] as String,
      layoutId: (map['layout_id'] as num?)?.toInt(),
      teeId: (map['tee_id'] as num?)?.toInt(),
      format: map['format'] as String,
      playerIds: (jsonDecode(map['player_ids'] as String) as List)
          .cast<String>(),
      playersJson: (jsonDecode(map['players_json'] as String) as List)
          .cast<Map<String, dynamic>>(),
      mode: map['mode'] as String,
      bagId: (map['bag_id'] as num?)?.toInt(),
      startHole: (map['start_hole'] as num).toInt(),
      holes: map['holes'] as String?,
      startTime: DateTime.parse(map['start_time'] as String),
      packageId: map['package_id'] as String?,
      tournamentPolicyId: map['tournament_policy_id'] as String?,
      status: map['status'] as String,
      serverRoundId: map['server_round_id'] as String?,
      idempotencyKey: map['idempotency_key'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      lastAttemptAt: map['last_attempt_at'] != null
          ? DateTime.parse(map['last_attempt_at'] as String)
          : null,
      syncAttempts: (map['sync_attempts'] as num?)?.toInt() ?? 0,
    );
  }

  /// Reconstruct RoundConfig domain model.
  RoundConfig toRoundConfig() {
    return RoundConfig(
      courseId: courseId,
      courseName: courseName,
      layoutId: layoutId,
      teeId: teeId,
      format: RoundFormat.fromString(format),
      playerIds: playerIds,
      players: playersJson.map((j) => Player.fromJson(j)).toList(),
      mode: RoundMode.fromString(mode),
      bagId: bagId,
      startHole: startHole,
      holes: holes,
      startTime: startTime,
      packageId: packageId,
      tournamentPolicyId: tournamentPolicyId,
    );
  }

  /// Copy with updated sync status.
  LocalRoundConfigRecord copyWith({
    String? status,
    String? serverRoundId,
    DateTime? syncedAt,
    DateTime? lastAttemptAt,
    int? syncAttempts,
  }) {
    return LocalRoundConfigRecord(
      localId: localId,
      courseId: courseId,
      courseName: courseName,
      layoutId: layoutId,
      teeId: teeId,
      format: format,
      playerIds: playerIds,
      playersJson: playersJson,
      mode: mode,
      bagId: bagId,
      startHole: startHole,
      holes: holes,
      startTime: startTime,
      packageId: packageId,
      tournamentPolicyId: tournamentPolicyId,
      status: status ?? this.status,
      serverRoundId: serverRoundId ?? this.serverRoundId,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
    );
  }
}

/// Local SQLite store for round configuration before API sync.
///
/// Story 5.1 — Slice G: Stores round config locally before API call.
/// Story 5.2: Full transactional persistence (deferred).
class RoundSetupStore {
  static const String _tableName = 'local_round_configs';
  static const String _dbName = 'vsp_round_setup.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
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
        local_id TEXT PRIMARY KEY,
        course_id INTEGER NOT NULL,
        course_name TEXT NOT NULL,
        layout_id INTEGER,
        tee_id INTEGER,
        format TEXT NOT NULL,
        player_ids TEXT NOT NULL,
        players_json TEXT NOT NULL,
        mode TEXT NOT NULL,
        bag_id INTEGER,
        start_hole INTEGER NOT NULL,
        holes TEXT,
        start_time TEXT NOT NULL,
        package_id TEXT,
        tournament_policy_id TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        server_round_id TEXT,
        idempotency_key TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        last_attempt_at TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Index for pending sync lookup
    await db.execute('''
      CREATE INDEX idx_round_configs_status ON $_tableName (status)
    ''');

    // Index for course lookup
    await db.execute('''
      CREATE INDEX idx_round_configs_course ON $_tableName (course_id)
    ''');
  }

  /// Save a round config locally (before API call).
  Future<void> saveLocalRoundConfig(LocalRoundConfigRecord record) async {
    final db = await _database;
    await db.insert(
      _tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a pending round config (for sync recovery).
  Future<LocalRoundConfigRecord?> getPendingRoundConfig() async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return LocalRoundConfigRecord.fromMap(rows.first);
  }

  /// Get all pending round configs (for sync queue).
  Future<List<LocalRoundConfigRecord>> getAllPendingRoundConfigs() async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );

    return rows.map((row) => LocalRoundConfigRecord.fromMap(row)).toList();
  }

  /// Mark round config as synced (after successful API call).
  Future<void> markSynced(String localId, String serverRoundId) async {
    final db = await _database;
    await db.update(
      _tableName,
      {
        'status': 'synced',
        'server_round_id': serverRoundId,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Mark round config sync as failed (after API error).
  Future<void> markSyncFailed(String localId) async {
    final db = await _database;
    await db.rawUpdate(
      '''
      UPDATE $_tableName
      SET status = 'failed',
          last_attempt_at = ?,
          sync_attempts = sync_attempts + 1
      WHERE local_id = ?
    ''',
      [DateTime.now().toUtc().toIso8601String(), localId],
    );
  }

  /// Get a round config by local ID.
  Future<LocalRoundConfigRecord?> getByLocalId(String localId) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return LocalRoundConfigRecord.fromMap(rows.first);
  }

  /// Delete a synced round config (cleanup).
  Future<void> deleteSynced() async {
    final db = await _database;
    await db.delete(_tableName, where: 'status = ?', whereArgs: ['synced']);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
