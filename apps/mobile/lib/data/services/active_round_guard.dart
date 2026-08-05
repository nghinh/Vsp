// Active Round Guard Service — VSP Mobile App
//
// Prevents package version promotion during active rounds and manages deferred updates.
// Story 4.4 INC-MOBILE-GUARD: AC-3 — active rounds are not silently switched to a new package version.
//
// Guard logic:
// 1. Before promotePendingToActive(), check if an active round exists for this courseId
// 2. If no active round → allow promotion
// 3. If active round exists and its startedWithVersion != currentActiveVersion → block promotion
// 4. When blocked, add to deferredUpdates table to process after round completes
//
// Implementation notes:
// - Local tracking via SQLite tables (round_package_version, deferred_updates)
// - On round start: store activeManifestVersion in round record
// - On round end: check for deferred updates and apply them
// - On app launch: check for deferred updates and apply them

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/deferred_update.dart';
import '../../domain/models/round_package_version.dart';
import '../repositories/package_manifest_repository.dart';

/// Result of checking whether a package update can proceed.
sealed class GuardResult {}

/// Promotion is allowed.
class GuardAllowed extends GuardResult {}

/// Promotion is blocked due to an active round.
class GuardBlocked extends GuardResult {
  final String message;
  final String currentVersion;
  final String activeRoundVersion;

  GuardBlocked({
    required this.message,
    required this.currentVersion,
    required this.activeRoundVersion,
  });
}

/// Service to guard package updates during active rounds.
class ActiveRoundGuard {
  static const String _tableName = 'round_package_version';
  static const String _deferredTable = 'deferred_updates';
  static const String _dbName = 'vsp_active_round.db';
  static const int _dbVersion = 1;

  final PackageManifestRepository _manifestRepo;
  Database? _db;

  ActiveRoundGuard({required PackageManifestRepository manifestRepo})
    : _manifestRepo = manifestRepo;

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
    // Table tracking which package version was active when a round started
    await db.execute('''
      CREATE TABLE $_tableName (
        course_id INTEGER PRIMARY KEY,
        package_version TEXT NOT NULL,
        started_at TEXT NOT NULL,
        round_id TEXT
      )
    ''');

    // Table for deferred updates (blocked due to active round)
    await db.execute('''
      CREATE TABLE $_deferredTable (
        course_id INTEGER PRIMARY KEY,
        new_version TEXT NOT NULL,
        new_etag TEXT NOT NULL,
        deferred_at TEXT NOT NULL,
        round_id TEXT
      )
    ''');
  }

  /// Check if promotion is allowed for a course.
  ///
  /// Returns [GuardAllowed] if no active round or versions match.
  /// Returns [GuardBlocked] if an active round exists with a different package version.
  Future<GuardResult> checkPromotion(int courseId) async {
    // Get the currently active manifest version
    final activeManifest = await _manifestRepo.getActiveManifest(courseId);
    if (activeManifest == null) {
      return GuardAllowed();
    }

    // Check if there's an active round for this course
    final roundVersion = await _getActiveRoundVersion(courseId);
    if (roundVersion == null) {
      // No active round recorded — allow promotion
      return GuardAllowed();
    }

    // There's an active round — check if versions match
    if (roundVersion.packageVersion == activeManifest.version) {
      // Versions match — round was started with this version, allow promotion
      return GuardAllowed();
    }

    // Versions differ — block promotion
    return GuardBlocked(
      message:
          'Update available but cannot apply during active round. '
          'Update will apply after this round.',
      currentVersion: activeManifest.version,
      activeRoundVersion: roundVersion.packageVersion,
    );
  }

  /// Record that a round has started for a course with the current package version.
  ///
  /// Called when user starts a round to lock the package version.
  Future<void> recordRoundStart(int courseId, {String? roundId}) async {
    final activeManifest = await _manifestRepo.getActiveManifest(courseId);
    if (activeManifest == null) return;

    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.rawInsert(
      '''
      INSERT INTO $_tableName (course_id, package_version, started_at, round_id)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(course_id) DO UPDATE SET
        package_version = excluded.package_version,
        started_at = excluded.started_at,
        round_id = excluded.round_id
    ''',
      [courseId, activeManifest.version, now, roundId],
    );
  }

  /// Record that a round has completed for a course.
  ///
  /// Called when a round ends. After calling this, any deferred updates
  /// for this course should be processed.
  Future<void> recordRoundEnd(int courseId) async {
    final db = await _database;

    // Delete the active round record
    await db.delete(_tableName, where: 'course_id = ?', whereArgs: [courseId]);

    // Process deferred updates
    await _processDeferredUpdates(courseId);
  }

  /// Get the active round record for a course.
  Future<RoundPackageVersion?> _getActiveRoundVersion(int courseId) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
    if (rows.isEmpty) return null;

    return RoundPackageVersion(
      courseId: rows.first['course_id'] as int,
      packageVersion: rows.first['package_version'] as String,
      startedAt: DateTime.parse(rows.first['started_at'] as String),
      roundId: rows.first['round_id'] as String?,
    );
  }

  /// Defer an update for a course (called when promotion is blocked).
  Future<void> deferUpdate(
    int courseId,
    String newVersion,
    String newEtag, {
    String? roundId,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.rawInsert(
      '''
      INSERT INTO $_deferredTable (course_id, new_version, new_etag, deferred_at, round_id)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(course_id) DO UPDATE SET
        new_version = excluded.new_version,
        new_etag = excluded.new_etag,
        deferred_at = excluded.deferred_at,
        round_id = excluded.round_id
    ''',
      [courseId, newVersion, newEtag, now, roundId],
    );
  }

  /// Get any deferred updates for a course.
  Future<DeferredUpdate?> getDeferredUpdate(int courseId) async {
    final db = await _database;
    final rows = await db.query(
      _deferredTable,
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
    if (rows.isEmpty) return null;

    return DeferredUpdate(
      courseId: rows.first['course_id'] as int,
      newVersion: rows.first['new_version'] as String,
      newEtag: rows.first['new_etag'] as String,
      deferredAt: DateTime.parse(rows.first['deferred_at'] as String),
      roundId: rows.first['round_id'] as String?,
    );
  }

  /// Clear a deferred update (after it's been applied).
  Future<void> clearDeferredUpdate(int courseId) async {
    final db = await _database;
    await db.delete(
      _deferredTable,
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }

  /// Process any deferred updates for a course.
  ///
  /// Called after a round ends. Returns the deferred update if one exists.
  Future<DeferredUpdate?> _processDeferredUpdates(int courseId) async {
    final deferred = await getDeferredUpdate(courseId);
    if (deferred != null) {
      // Note: The actual application of the deferred update
      // should be done by the CoursePackageUpdateService
      // This just returns the deferred update info
    }
    return deferred;
  }

  /// Check for and return any deferred updates on app launch.
  Future<DeferredUpdate?> checkDeferredUpdatesOnLaunch() async {
    final db = await _database;
    final rows = await db.query(_deferredTable);
    if (rows.isEmpty) return null;

    // Return the most recently deferred update
    final row = rows.first;
    return DeferredUpdate(
      courseId: (row['course_id'] as num).toInt(),
      newVersion: row['new_version'] as String,
      newEtag: row['new_etag'] as String,
      deferredAt: DateTime.parse(row['deferred_at'] as String),
      roundId: row['round_id'] as String?,
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
