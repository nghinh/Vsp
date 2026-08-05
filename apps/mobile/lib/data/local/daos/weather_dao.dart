// WeatherDao — VSP Mobile App
//
// Story 7.1 Wave 2: SQLite Data Access Object
// Per slice plan §2.4 — one snapshot per course_id (UNIQUE constraint).
//
// Provides CRUD operations on the weather_snapshots table.
// Uses the database from ScoreDao (vsp_round.db) to keep all round-related
// data in one database file.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/weather_snapshot.dart';
import '../round_database.dart';
import '../tables/weather_snapshots_table.dart';

/// Data Access Object for WeatherSnapshot persistence.
class WeatherDao {
  Database? _db;

  /// Singleton instance.
  static final WeatherDao instance = WeatherDao._();

  WeatherDao._();

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  // `vsp_round.db` is shared across round DAOs; open it through the shared
  // helper so the full schema exists regardless of open order.
  Future<Database> _initDb() => openRoundDatabase();

  /// Upsert a weather snapshot for a course (replaces existing by course_id).
  Future<void> upsert(String courseId, WeatherSnapshot snapshot) async {
    final db = await _database;
    final jsonData = jsonEncode(snapshot.toJson());
    await db.insert(kWeatherSnapshotsTableName, {
      'id': snapshot.id,
      'course_id': courseId,
      'captured_at': snapshot.timestamp.millisecondsSinceEpoch,
      'expires_at': snapshot.expiresAt?.millisecondsSinceEpoch ?? 0,
      'is_forecast': snapshot.source.measurementType.isForecast ? 1 : 0,
      'provider': snapshot.source.provider,
      'source_name': snapshot.source.name,
      'source_timestamp': snapshot.timestamp.toUtc().toIso8601String(),
      'json_data': jsonData,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get the cached weather snapshot for a course.
  /// Returns null if no cached snapshot exists.
  Future<WeatherSnapshot?> getByCourseId(String courseId) async {
    final db = await _database;
    final rows = await db.query(
      kWeatherSnapshotsTableName,
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'captured_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToSnapshot(rows.first);
  }

  /// Get all cached weather snapshots ordered by capture time.
  Future<List<WeatherSnapshot>> getAll() async {
    final db = await _database;
    final rows = await db.query(
      kWeatherSnapshotsTableName,
      orderBy: 'captured_at DESC',
    );
    return rows.map(_rowToSnapshot).toList();
  }

  /// Get snapshots that have expired (captured_at older than [maxAge]).
  Future<List<WeatherSnapshot>> getExpired(Duration maxAge) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    final rows = await db.query(
      kWeatherSnapshotsTableName,
      where: 'captured_at < ?',
      whereArgs: [cutoff],
      orderBy: 'captured_at ASC',
    );
    return rows.map(_rowToSnapshot).toList();
  }

  /// Delete the cached snapshot for a course.
  Future<void> delete(String courseId) async {
    final db = await _database;
    await db.delete(
      kWeatherSnapshotsTableName,
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }

  /// Delete all cached weather snapshots.
  Future<void> deleteAll() async {
    final db = await _database;
    await db.delete(kWeatherSnapshotsTableName);
  }

  WeatherSnapshot _rowToSnapshot(Map<String, dynamic> row) {
    final jsonData = row['json_data'] as String;
    final json = jsonDecode(jsonData) as Map<String, dynamic>;
    return WeatherSnapshot.fromJson(json);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
