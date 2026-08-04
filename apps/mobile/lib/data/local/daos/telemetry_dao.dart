// Telemetry DAO — VSP Mobile App
//
// SQLite Data Access Object for unified telemetry persistence.
// Stores GPS quality, battery, and map latency telemetry events locally
// before sync to backend.
//
// Story 6.6 — Slice B: Telemetry Service Interface + Local Persistence

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/telemetry/gps_quality_telemetry.dart';
import '../../../domain/models/telemetry/battery_telemetry.dart';
import '../../../domain/models/telemetry/map_latency_telemetry.dart';
import '../tables/telemetry_table.dart';

/// Unified telemetry event type discriminator.
enum TelemetryType { gps, battery, mapLatency }

/// A single telemetry event row stored in SQLite.
class TelemetryEvent {
  final String id;
  final String roundId;
  final TelemetryType eventType;
  final DateTime recordedAt;
  final String jsonPayload;
  final String syncStatus;
  final int version;
  final DateTime updatedAt;

  TelemetryEvent({
    required this.id,
    required this.roundId,
    required this.eventType,
    required this.recordedAt,
    required this.jsonPayload,
    required this.syncStatus,
    required this.version,
    required this.updatedAt,
  });
}

/// Data Access Object for telemetry persistence.
class TelemetryDao {
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
    await db.execute(kTelemetryTableCreateSql);
    await db.execute(kTelemetryTableRoundIndexSql);
    await db.execute(kTelemetryTableEventTypeIndexSql);
    await db.execute(kTelemetryTableSyncStatusIndexSql);
    await db.execute(kTelemetryTableRoundTypeIndexSql);
  }

  // ─── GPS Telemetry ───────────────────────────────────────────────────────

  /// Insert a GPS quality telemetry record.
  Future<void> insertGps(GpsQualityTelemetry gps) async {
    final db = await _database;
    await db.insert(
      kTelemetryTableName,
      _gpsToMap(gps),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all GPS telemetry records for a round.
  Future<List<GpsQualityTelemetry>> getGpsByRoundId(String roundId) async {
    final db = await _database;
    final rows = await db.query(
      kTelemetryTableName,
      where: 'round_id = ? AND event_type = ?',
      whereArgs: [roundId, TelemetryEventTypes.gps],
      orderBy: 'recorded_at ASC',
    );
    return rows.map((row) => _gpsFromRow(row)).toList();
  }

  /// Retrieve GPS telemetry records for a specific hole within a round.
  Future<List<GpsQualityTelemetry>> getGpsByRoundAndHole({
    required String roundId,
    required String holeId,
  }) async {
    final all = await getGpsByRoundId(roundId);
    return all.where((e) => e.holeId == holeId).toList();
  }

  // ─── Battery Telemetry ────────────────────────────────────────────────────

  /// Insert a battery telemetry record.
  Future<void> insertBattery(BatteryTelemetry battery) async {
    final db = await _database;
    await db.insert(
      kTelemetryTableName,
      _batteryToMap(battery),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all battery telemetry records for a round.
  Future<List<BatteryTelemetry>> getBatteryByRoundId(String roundId) async {
    final db = await _database;
    final rows = await db.query(
      kTelemetryTableName,
      where: 'round_id = ? AND event_type = ?',
      whereArgs: [roundId, TelemetryEventTypes.battery],
      orderBy: 'recorded_at ASC',
    );
    return rows.map((row) => _batteryFromRow(row)).toList();
  }

  // ─── Map Latency Telemetry ────────────────────────────────────────────────

  /// Insert a map latency telemetry record.
  Future<void> insertMapLatency(MapLatencyTelemetry mapLatency) async {
    final db = await _database;
    await db.insert(
      kTelemetryTableName,
      _mapLatencyToMap(mapLatency),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all map latency telemetry records for a round.
  Future<List<MapLatencyTelemetry>> getMapLatencyByRoundId(
    String roundId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kTelemetryTableName,
      where: 'round_id = ? AND event_type = ?',
      whereArgs: [roundId, TelemetryEventTypes.mapLatency],
      orderBy: 'recorded_at ASC',
    );
    return rows.map((row) => _mapLatencyFromRow(row)).toList();
  }

  // ─── Unified Queries ──────────────────────────────────────────────────────

  /// Retrieve all telemetry events for a round regardless of type.
  Future<List<TelemetryEvent>> getByRoundId(String roundId) async {
    final db = await _database;
    final rows = await db.query(
      kTelemetryTableName,
      where: 'round_id = ?',
      whereArgs: [roundId],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(_eventFromRow).toList();
  }

  /// Retrieve all telemetry events with a specific sync status.
  Future<List<TelemetryEvent>> getBySyncStatus(String status) async {
    final db = await _database;
    final rows = await db.query(
      kTelemetryTableName,
      where: 'sync_status = ?',
      whereArgs: [status],
    );
    return rows.map(_eventFromRow).toList();
  }

  /// Mark a telemetry event as synced.
  Future<void> markSynced(String id) async {
    final db = await _database;
    await db.update(
      kTelemetryTableName,
      {
        'sync_status': TelemetrySyncStatus.synced,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a telemetry event by ID.
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete(kTelemetryTableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all telemetry events for a round.
  Future<void> deleteByRoundId(String roundId) async {
    final db = await _database;
    await db.delete(
      kTelemetryTableName,
      where: 'round_id = ?',
      whereArgs: [roundId],
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }

  // ─── Row Mappers ─────────────────────────────────────────────────────────

  Map<String, dynamic> _gpsToMap(GpsQualityTelemetry gps) {
    final map = gps.toMap();
    return {
      'id': map['id'],
      'round_id': map['round_id'],
      'event_type': TelemetryEventTypes.gps,
      'recorded_at': map['recorded_at'],
      'json_payload': jsonEncode({
        'hole_id': map['hole_id'],
        'longitude': map['longitude'],
        'latitude': map['latitude'],
        'altitude': map['altitude'],
        'horizontal_accuracy_meters': map['horizontal_accuracy_meters'],
        'vertical_accuracy_meters': map['vertical_accuracy_meters'],
        'fix_quality': map['fix_quality'],
        'speed_meters_per_second': map['speed_meters_per_second'],
        'heading_degrees': map['heading_degrees'],
        'is_stale': map['is_stale'],
        'battery_level': map['battery_level'],
        'battery_saver_active': map['battery_saver_active'],
      }),
      'sync_status': TelemetrySyncStatus.local,
      'version': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  GpsQualityTelemetry _gpsFromRow(Map<String, dynamic> row) {
    final payload =
        jsonDecode(row['json_payload'] as String) as Map<String, dynamic>;
    return GpsQualityTelemetry.fromMap({
      'id': row['id'],
      'round_id': row['round_id'],
      'recorded_at': row['recorded_at'],
      ...payload,
    });
  }

  Map<String, dynamic> _batteryToMap(BatteryTelemetry battery) {
    final map = battery.toMap();
    return {
      'id': map['id'],
      'round_id': map['round_id'],
      'event_type': TelemetryEventTypes.battery,
      'recorded_at': map['recorded_at'],
      'json_payload': jsonEncode({
        'battery_level': map['battery_level'],
        'battery_state': map['battery_state'],
        'temperature_celsius': map['temperature_celsius'],
        'estimated_remaining_seconds': map['estimated_remaining_seconds'],
        'holes_completed': map['holes_completed'],
        'holes_remaining': map['holes_remaining'],
        'gps_polling_frequency_hz': map['gps_polling_frequency_hz'],
        'battery_saver_active': map['battery_saver_active'],
        'screen_state': map['screen_state'],
        'app_in_foreground': map['app_in_foreground'],
      }),
      'sync_status': TelemetrySyncStatus.local,
      'version': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  BatteryTelemetry _batteryFromRow(Map<String, dynamic> row) {
    final payload =
        jsonDecode(row['json_payload'] as String) as Map<String, dynamic>;
    return BatteryTelemetry.fromMap({
      'id': row['id'],
      'round_id': row['round_id'],
      'recorded_at': row['recorded_at'],
      ...payload,
    });
  }

  Map<String, dynamic> _mapLatencyToMap(MapLatencyTelemetry mapLatency) {
    final map = mapLatency.toMap();
    return {
      'id': map['id'],
      'round_id': map['round_id'],
      'event_type': TelemetryEventTypes.mapLatency,
      'recorded_at': map['event_started_at'],
      'json_payload': jsonEncode({
        'hole_id': map['hole_id'],
        'event_completed_at': map['event_completed_at'],
        'event_type': map['event_type'],
        'duration_milliseconds': map['duration_milliseconds'],
        'tiles_rendered': map['tiles_rendered'],
        'symbols_rendered': map['symbols_rendered'],
        'served_from_cache': map['served_from_cache'],
        'zoom_level': map['zoom_level'],
        'device_model': map['device_model'],
        'battery_level': map['battery_level'],
        'memory_usage_mb': map['memory_usage_mb'],
      }),
      'sync_status': TelemetrySyncStatus.local,
      'version': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  MapLatencyTelemetry _mapLatencyFromRow(Map<String, dynamic> row) {
    final payload =
        jsonDecode(row['json_payload'] as String) as Map<String, dynamic>;
    return MapLatencyTelemetry.fromMap({
      'id': row['id'],
      'round_id': row['round_id'],
      'event_started_at': row['recorded_at'],
      ...payload,
    });
  }

  TelemetryEvent _eventFromRow(Map<String, dynamic> row) {
    return TelemetryEvent(
      id: row['id'] as String,
      roundId: row['round_id'] as String,
      eventType: TelemetryType.values.firstWhere(
        (e) => e.name == (row['event_type'] as String).replaceAll('_', ''),
        orElse: () => TelemetryType.gps,
      ),
      recordedAt: DateTime.parse(row['recorded_at'] as String),
      jsonPayload: row['json_payload'] as String,
      syncStatus: row['sync_status'] as String,
      version: row['version'] as int,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
