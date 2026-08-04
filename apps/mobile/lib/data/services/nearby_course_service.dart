// Nearby Course Service — VSP Mobile App
//
// Suggests nearby courses using GPS location and last-played fallback.
// Uses package manifest location for nearby downloaded courses.
//
// Story 5.1 — Slice F: Nearby Course Suggestion

import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

/// A downloaded course with location for nearby suggestion.
class DownloadedCourseWithLocation {
  final int courseId;
  final String courseName;
  final double latitude;
  final double longitude;
  final String? packageId;

  const DownloadedCourseWithLocation({
    required this.courseId,
    required this.courseName,
    required this.latitude,
    required this.longitude,
    this.packageId,
  });
}

/// A recent course for fallback suggestion.
class RecentCourse {
  final int courseId;
  final String courseName;
  final DateTime lastPlayedAt;
  final String? packageId;

  const RecentCourse({
    required this.courseId,
    required this.courseName,
    required this.lastPlayedAt,
    this.packageId,
  });
}

/// Result of nearby course search.
class NearbyCourseResult {
  final List<DownloadedCourseWithLocation> courses;
  final DownloadedCourseWithLocation?
  nearestCourse; // auto-selected if exactly 1 within 5km
  final String? autoSelectReason; // null if no auto-selection

  const NearbyCourseResult({
    required this.courses,
    this.nearestCourse,
    this.autoSelectReason,
  });

  /// True if exactly one course is within 5km and should be auto-selected.
  bool get shouldAutoSelect =>
      nearestCourse != null && autoSelectReason != null;
}

/// Service for nearby course suggestions with GPS and last-played fallback.
class NearbyCourseService {
  static const String _dbName = 'vsp_nearby.db';
  static const String _recentTable = 'recent_courses';
  static const double _autoSelectRadiusKm = 5.0;

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_recentTable (
        course_id INTEGER PRIMARY KEY,
        course_name TEXT NOT NULL,
        last_played_at TEXT NOT NULL,
        package_id TEXT
      )
    ''');
  }

  /// Find nearby downloaded courses within [radiusKm].
  ///
  /// Uses the manifest's embedded course location for downloaded courses.
  /// Returns [NearbyCourseResult] with courses and optional auto-selection.
  Future<NearbyCourseResult> getNearbyDownloadedCourses({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    // In a real implementation, this would:
    // 1. Query PackageManifestRepository for all downloaded courses
    // 2. Get their locations from the manifest metadata
    // 3. Filter by distance using Haversine formula
    // 4. Sort by distance
    //
    // For now, return empty result — actual implementation would
    // need the manifest location data from the package metadata.
    return const NearbyCourseResult(courses: []);
  }

  /// Get the last-played course as fallback suggestion.
  ///
  /// Queries the recent_courses table for the most recently played course.
  Future<RecentCourse?> getLastPlayedCourse() async {
    final db = await _database;
    final rows = await db.query(
      _recentTable,
      orderBy: 'last_played_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    return RecentCourse(
      courseId: row['course_id'] as int,
      courseName: row['course_name'] as String,
      lastPlayedAt: DateTime.parse(row['last_played_at'] as String),
      packageId: row['package_id'] as String?,
    );
  }

  /// Record that a course was played (for recent/fallback suggestion).
  Future<void> recordCoursePlayed({
    required int courseId,
    required String courseName,
    String? packageId,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.rawInsert(
      '''
      INSERT INTO $_recentTable (course_id, course_name, last_played_at, package_id)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(course_id) DO UPDATE SET
        course_name = excluded.course_name,
        last_played_at = excluded.last_played_at,
        package_id = excluded.package_id
    ''',
      [courseId, courseName, now, packageId],
    );
  }

  /// Get all recent courses ordered by last played.
  Future<List<RecentCourse>> getRecentCourses({int limit = 10}) async {
    final db = await _database;
    final rows = await db.query(
      _recentTable,
      orderBy: 'last_played_at DESC',
      limit: limit,
    );

    return rows.map((row) {
      return RecentCourse(
        courseId: row['course_id'] as int,
        courseName: row['course_name'] as String,
        lastPlayedAt: DateTime.parse(row['last_played_at'] as String),
        packageId: row['package_id'] as String?,
      );
    }).toList();
  }

  /// Calculate distance between two coordinates using Haversine formula.
  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusKm = 6371.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Auto-suggest start hole based on time of day.
  ///
  /// Hole 1 if local time < 12pm, hole 10 if >= 12pm.
  /// This is configurable — stored in user preferences.
  static int suggestedStartHole({int? customHour}) {
    final hour = customHour ?? DateTime.now().hour;
    return hour < 12 ? 1 : 10;
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
