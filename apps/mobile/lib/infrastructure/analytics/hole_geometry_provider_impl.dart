// HoleGeometryProviderImpl — VSP Mobile App
//
// SQLite-backed implementation of HoleGeometryProvider for Smart Target.
//
// Per slice-plan-11-4.md Slice 4:
// - Reads from downloaded course package (Epic 4/6)
// - Works offline when course package is downloaded
//
// Story 11.4 — Slice 4: Real SQLite Repos + Offline

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/value_objects/lat_lng.dart';
import '../../domain/analytics/smart_target/repositories/hole_geometry_provider.dart';

/// Table definitions for hole geometry.
const String kHoleGeometryTableName = 'hole_geometry';
const String kHoleGeometryTableCreateSql = '''
  CREATE TABLE hole_geometry (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL,
    hole_number INTEGER NOT NULL,
    par INTEGER NOT NULL,
    pin_position_lat REAL NOT NULL,
    pin_position_lon REAL NOT NULL,
    tee_box_lat REAL NOT NULL,
    tee_box_lon REAL NOT NULL,
    fairway_centerline_json TEXT,
    green_polygon_json TEXT,
    hazards_json TEXT,
    UNIQUE(course_id, hole_number)
  )
''';

const String kHoleGeometryCourseIndexSql = '''
  CREATE INDEX idx_hg_course ON hole_geometry (course_id)
''';

/// SQLite-backed implementation of HoleGeometryProvider.
///
/// Reads hole geometry data from local SQLite that was downloaded as part
/// of the course package (Epic 4/6).
class SqliteHoleGeometryProvider implements HoleGeometryProvider {
  static const String _dbName = 'vsp_smart_target.db';
  static const int _dbVersion = 1;

  Database? _db;
  final Database? _injectedDb;

  SqliteHoleGeometryProvider({Database? injectedDb}) : _injectedDb = injectedDb;

  Future<Database> get _database async {
    if (_injectedDb != null) return _injectedDb;
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
    await db.execute(kHoleGeometryTableCreateSql);
    await db.execute(kHoleGeometryCourseIndexSql);
  }

  @override
  Future<HoleContext?> getHoleContext(String holeId) async {
    final db = await _database;
    final rows = await db.query(
      kHoleGeometryTableName,
      where: 'id = ?',
      whereArgs: [holeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  @override
  Future<HoleContext?> getHoleContextByNumber(
    String courseId,
    int holeNumber,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kHoleGeometryTableName,
      where: 'course_id = ? AND hole_number = ?',
      whereArgs: [courseId, holeNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  @override
  Future<bool> hasGeometry(String holeId) async {
    final db = await _database;
    final rows = await db.query(
      kHoleGeometryTableName,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [holeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  HoleContext _fromMap(Map<String, dynamic> map) {
    // Parse fairway centerline
    final fairwayCenterline = <LatLng>[];
    if (map['fairway_centerline_json'] != null &&
        (map['fairway_centerline_json'] as String).isNotEmpty) {
      try {
        final coords = jsonDecode(map['fairway_centerline_json'] as String);
        for (final coord in coords as List<dynamic>) {
          if (coord is List && coord.length >= 2) {
            fairwayCenterline.add(
              LatLng(
                latitude: (coord[1] as num).toDouble(),
                longitude: (coord[0] as num).toDouble(),
              ),
            );
          }
        }
      } catch (_) {
        // Ignore parse errors
      }
    }

    // Parse green polygon
    final greenPolygon = <LatLng>[];
    if (map['green_polygon_json'] != null &&
        (map['green_polygon_json'] as String).isNotEmpty) {
      try {
        final coords = jsonDecode(map['green_polygon_json'] as String);
        for (final coord in coords as List<dynamic>) {
          if (coord is List && coord.length >= 2) {
            greenPolygon.add(
              LatLng(
                latitude: (coord[1] as num).toDouble(),
                longitude: (coord[0] as num).toDouble(),
              ),
            );
          }
        }
      } catch (_) {
        // Ignore parse errors
      }
    }

    // Parse hazards
    final hazards = <HoleHazardSummary>[];
    if (map['hazards_json'] != null &&
        (map['hazards_json'] as String).isNotEmpty) {
      try {
        final hazardList = jsonDecode(map['hazards_json'] as String);
        for (final hazard in hazardList as List<dynamic>) {
          if (hazard is Map<String, dynamic>) {
            final polygon = <LatLng>[];
            if (hazard['polygon'] is List) {
              for (final coord in hazard['polygon'] as List) {
                if (coord is List && coord.length >= 2) {
                  polygon.add(
                    LatLng(
                      latitude: (coord[1] as num).toDouble(),
                      longitude: (coord[0] as num).toDouble(),
                    ),
                  );
                }
              }
            }
            hazards.add(
              HoleHazardSummary(
                id: hazard['id'] as String? ?? '',
                name: hazard['name'] as String? ?? '',
                type: hazard['type'] as String? ?? 'unknown',
                polygon: polygon,
              ),
            );
          }
        }
      } catch (_) {
        // Ignore parse errors
      }
    }

    return HoleContext(
      holeId: map['id'] as String,
      holeNumber: (map['hole_number'] as num).toInt(),
      par: (map['par'] as num).toInt(),
      pinPosition: LatLng(
        latitude: (map['pin_position_lat'] as num).toDouble(),
        longitude: (map['pin_position_lon'] as num).toDouble(),
      ),
      teeBox: LatLng(
        latitude: (map['tee_box_lat'] as num).toDouble(),
        longitude: (map['tee_box_lon'] as num).toDouble(),
      ),
      fairwayCenterline: fairwayCenterline,
      greenPolygon: greenPolygon,
      hazards: hazards,
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
