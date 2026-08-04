// Course Package Repository — VSP Mobile App
//
// Handles API calls for course package operations and persists download state
// for app-restart recovery.
//
// Story 4.3 AC-1: persists download progress so downloads can resume after
// app restart.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/download_progress.dart';
import '../../domain/models/download_state.dart';
import '../../core/network/api_client.dart';

/// Repository for course package operations.
///
/// Handles:
/// - API calls to fetch course package manifests from the backend
/// - Persisting download state for app restart recovery
/// - Querying active manifest status (offline-ready check)
class CoursePackageRepository {
  static const String _downloadStateTable = 'download_state';
  static const String _dbName = 'vsp_download_state.db';
  static const int _dbVersion = 1;

  final ApiClient _apiClient;
  Database? _db;

  CoursePackageRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

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
      CREATE TABLE $_downloadStateTable (
        course_id INTEGER PRIMARY KEY,
        state TEXT NOT NULL,
        total_bytes INTEGER NOT NULL DEFAULT 0,
        downloaded_bytes INTEGER NOT NULL DEFAULT 0,
        current_file TEXT,
        current_file_index INTEGER NOT NULL DEFAULT 0,
        total_files INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        error TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Fetch the current manifest for a course from the backend API.
  ///
  /// Calls GET /courses/{courseId}/packages/current
  /// Returns the manifest JSON map, or null if not available.
  Future<Map<String, dynamic>?> fetchManifest(int courseId) async {
    try {
      final data = await _apiClient.get('/courses/$courseId/packages/current');
      return data as Map<String, dynamic>?;
    } catch (e) {
      // Return null if no package available or network error
      return null;
    }
  }

  /// Persist download state for a course (for app restart recovery).
  ///
  /// Called during download to save progress. After app restart,
  /// [getDownloadState] can retrieve this to allow resume.
  Future<void> saveDownloadState(
    int courseId,
    DownloadProgress progress,
  ) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.rawInsert(
      '''
      INSERT INTO $_downloadStateTable
        (course_id, state, total_bytes, downloaded_bytes, current_file,
         current_file_index, total_files, error_message, error, retry_count, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(course_id) DO UPDATE SET
        state = excluded.state,
        total_bytes = excluded.total_bytes,
        downloaded_bytes = excluded.downloaded_bytes,
        current_file = excluded.current_file,
        current_file_index = excluded.current_file_index,
        total_files = excluded.total_files,
        error_message = excluded.error_message,
        error = excluded.error,
        retry_count = excluded.retry_count,
        updated_at = excluded.updated_at
    ''',
      [
        courseId,
        progress.state.name,
        progress.totalBytes,
        progress.downloadedBytes,
        progress.currentFile,
        progress.currentFileIndex,
        progress.totalFiles,
        progress.errorMessage,
        progress.error?.name,
        progress.retryCount,
        now,
      ],
    );
  }

  /// Retrieve persisted download state for a course.
  ///
  /// Returns null if no download state is persisted.
  Future<DownloadProgress?> getDownloadState(int courseId) async {
    final db = await _database;
    final rows = await db.query(
      _downloadStateTable,
      where: 'course_id = ?',
      whereArgs: [courseId],
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    final stateName = row['state'] as String;
    final state = DownloadServiceState.values.firstWhere(
      (s) => s.name == stateName,
      orElse: () => DownloadServiceState.idle,
    );

    final errorName = row['error'] as String?;
    DownloadError? error;
    if (errorName != null) {
      error = DownloadError.values.cast<DownloadError?>().firstWhere(
        (e) => e?.name == errorName,
        orElse: () => null,
      );
    }

    return DownloadProgress(
      courseId: courseId,
      state: state,
      totalBytes: row['total_bytes'] as int,
      downloadedBytes: row['downloaded_bytes'] as int,
      currentFile: row['current_file'] as String?,
      currentFileIndex: row['current_file_index'] as int,
      totalFiles: row['total_files'] as int,
      errorMessage: row['error_message'] as String?,
      error: error,
      retryCount: row['retry_count'] as int,
    );
  }

  /// Clear persisted download state for a course (after completion or delete).
  Future<void> clearDownloadState(int courseId) async {
    final db = await _database;
    await db.delete(
      _downloadStateTable,
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
