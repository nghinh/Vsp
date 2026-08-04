// HoleSelectionLogDao — VSP Mobile App
//
// SQLite Data Access Object for ManualHoleSelection entities.
// Provides append-only audit log operations on the hole_selection_log table.
//
// Story 6.2 — Wave D: Manual Override & Audit

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/manual_hole_selection.dart';
import '../../../domain/models/qualified_location.dart';
import '../../local/tables/hole_selection_log_table.dart';

/// Data Access Object for ManualHoleSelection persistence.
/// Append-only: inserts new records, never updates or deletes.
class HoleSelectionLogDao {
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
    await db.execute(kHoleSelectionLogTableCreateSql);
    await db.execute(kHoleSelectionLogTableRoundIdIndexSql);
    await db.execute(kHoleSelectionLogTableSyncStatusIndexSql);
  }

  /// Append a new hole selection log entry.
  /// Append-only: each selection is a new record.
  Future<void> append(ManualHoleSelection selection) async {
    final db = await _database;
    await db.insert(
      kHoleSelectionLogTableName,
      selection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Query all selections for a round.
  /// Returns ordered by selectedAt descending (most recent first).
  Future<List<ManualHoleSelection>> queryByRound(String roundId) async {
    final db = await _database;
    final rows = await db.query(
      kHoleSelectionLogTableName,
      where: 'round_id = ?',
      whereArgs: [roundId],
      orderBy: 'selected_at DESC',
    );

    return rows.map((row) => _fromMap(row)).toList();
  }

  /// Query selections by sync status.
  /// Used for sync worker to find pending uploads.
  Future<List<ManualHoleSelection>> queryBySyncStatus(
    ManualHoleSelectionSyncStatus status,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kHoleSelectionLogTableName,
      where: 'sync_status = ?',
      whereArgs: [status.name],
      orderBy: 'selected_at ASC',
    );

    return rows.map((row) => _fromMap(row)).toList();
  }

  /// Update sync status for a selection.
  Future<void> updateSyncStatus(
    String id,
    ManualHoleSelectionSyncStatus status,
  ) async {
    final db = await _database;
    await db.update(
      kHoleSelectionLogTableName,
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count pending sync entries.
  Future<int> countPending() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_dbName.$kHoleSelectionLogTableName WHERE sync_status = ?',
      [ManualHoleSelectionSyncStatus.pending.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }

  /// Convert a SQLite row to ManualHoleSelection.
  ManualHoleSelection _fromMap(Map<String, dynamic> map) {
    return ManualHoleSelection(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      detectedHoleId: map['detected_hole_id'] as String?,
      selectedHoleId: map['selected_hole_id'] as String,
      reason: ManualSelectionReason.values.firstWhere(
        (r) => r.name == map['reason'],
        orElse: () => ManualSelectionReason.userChoice,
      ),
      confidenceBefore: map['confidence_before'] as double?,
      locationAtSelection: QualifiedLocation(
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        isStale: false,
        accuracyMeters: map['accuracy_meters'] as double?,
        heading: map['heading'] as double?,
        source: LocationSource.values.firstWhere(
          (s) => s.name == map['location_source'],
          orElse: () => LocationSource.gps,
        ),
        timestamp: DateTime.parse(map['location_timestamp'] as String),
      ),
      selectedAt: DateTime.parse(map['selected_at'] as String),
      syncStatus: ManualHoleSelectionSyncStatus.fromString(
        map['sync_status'] as String? ?? 'local',
      ),
    );
  }
}
