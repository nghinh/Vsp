// Package Manifest Repository — VSP Mobile App
//
// SQLite-backed persistence for course package manifests.
// Implements non-destructive pending/active promotion semantics per Story 4.1 AC-3.
//
// Strategy:
// - saveManifest writes to pending_manifest column first.
// - Only promotes to active_manifest after validateManifest returns valid.
// - On validation failure, pending is discarded and active is untouched.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/course_package_manifest.dart';

/// Repository for persisting and retrieving course package manifests locally.
class PackageManifestRepository {
  static const String _tableName = 'package_manifest';
  static const String _dbName = 'vsp_package_manifest.db';
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
        course_id INTEGER PRIMARY KEY,
        active_manifest TEXT,
        pending_manifest TEXT,
        active_etag TEXT,
        pending_etag TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Save a manifest as pending (not yet validated).
  ///
  /// This writes to the pending column first — does NOT overwrite active.
  /// After the caller validates the downloaded package, it should call
  /// [promotePendingToActive] to confirm or [discardPending] to discard.
  Future<void> savePendingManifest(
    CoursePackageManifest manifest, {
    String? etag,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();
    final json = jsonEncode(manifest.toJson());

    await db.rawInsert(
      '''
      INSERT INTO $_tableName (course_id, pending_manifest, pending_etag, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(course_id) DO UPDATE SET
        pending_manifest = excluded.pending_manifest,
        pending_etag = excluded.pending_etag,
        updated_at = excluded.updated_at
    ''',
      [manifest.courseId, json, etag, now],
    );
  }

  /// Promote the pending manifest to active after successful validation.
  ///
  /// This moves pending_manifest → active_manifest, clearing pending.
  /// Also moves pending_etag → active_etag.
  /// If no pending manifest exists, this is a no-op.
  Future<void> promotePendingToActive(int courseId) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.rawUpdate(
      '''
      UPDATE $_tableName
      SET active_manifest = pending_manifest,
          active_etag = pending_etag,
          pending_manifest = NULL,
          pending_etag = NULL,
          updated_at = ?
      WHERE course_id = ? AND pending_manifest IS NOT NULL
    ''',
      [now, courseId],
    );
  }

  /// Discard the pending manifest after failed validation.
  ///
  /// Clears pending_manifest and pending_etag without touching active_manifest.
  /// This ensures the last valid package remains usable (Story 4.1 AC-3).
  Future<void> discardPending(int courseId) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.rawUpdate(
      '''
      UPDATE $_tableName
      SET pending_manifest = NULL,
          pending_etag = NULL,
          updated_at = ?
      WHERE course_id = ?
    ''',
      [now, courseId],
    );
  }

  /// Get the currently active (validated) manifest for a course.
  ///
  /// Returns null if no active manifest exists.
  Future<CoursePackageManifest?> getActiveManifest(int courseId) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      columns: ['active_manifest'],
      where: 'course_id = ? AND active_manifest IS NOT NULL',
      whereArgs: [courseId],
    );
    if (rows.isEmpty) return null;
    final json = rows.first['active_manifest'] as String;
    return CoursePackageManifest.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Get the pending (not yet validated) manifest for a course.
  Future<CoursePackageManifest?> getPendingManifest(int courseId) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      columns: ['pending_manifest'],
      where: 'course_id = ? AND pending_manifest IS NOT NULL',
      whereArgs: [courseId],
    );
    if (rows.isEmpty) return null;
    final json = rows.first['pending_manifest'] as String;
    return CoursePackageManifest.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// True if an active (validated) manifest exists for this course.
  Future<bool> hasActiveManifest(int courseId) async {
    final db = await _database;
    final result = await db.rawQuery(
      '''
      SELECT 1 FROM $_tableName
      WHERE course_id = ? AND active_manifest IS NOT NULL
      LIMIT 1
    ''',
      [courseId],
    );
    return result.isNotEmpty;
  }

  /// Save the ETag for the active manifest of a course.
  ///
  /// Called after successful manifest fetch to enable conditional fetch on next check.
  Future<void> saveActiveEtag(int courseId, String etag) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.rawUpdate(
      '''
      UPDATE $_tableName
      SET active_etag = ?, updated_at = ?
      WHERE course_id = ?
    ''',
      [etag, now, courseId],
    );
  }

  /// Get the stored ETag for the active manifest of a course.
  ///
  /// Returns null if no ETag is stored (first check, no prior manifest).
  Future<String?> getActiveEtag(int courseId) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      columns: ['active_etag'],
      where: 'course_id = ? AND active_manifest IS NOT NULL',
      whereArgs: [courseId],
    );
    if (rows.isEmpty) return null;
    return rows.first['active_etag'] as String?;
  }

  /// Delete all manifest data (active and pending) for a course.
  ///
  /// Called by Story 4.3 when the user deletes a downloaded course package.
  Future<void> deleteManifest(int courseId) async {
    final db = await _database;
    await db.delete(_tableName, where: 'course_id = ?', whereArgs: [courseId]);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
