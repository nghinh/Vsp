// CorrectionDao — VSP Mobile App
//
// SQLite Data Access Object for CourseCorrection entities.
// Provides CRUD operations on the corrections table.
//
// Per Story 9.1 Slice 1: Domain Model + DTO + SQLite.

import 'package:sqflite/sqflite.dart';

import '../../../features/correction/domain/course_correction.dart';
import '../tables/corrections_table.dart';

/// Data Access Object for CourseCorrection persistence.
class CorrectionDao {
  static const String _dbName = 'vsp_round.db';
  static const int _dbVersion = 1;

  Database? _db;

  /// Constructor for production use — opens the real SQLite database.
  CorrectionDao();

  /// Constructor for testing — accepts an open [Database] directly,
  /// bypassing database initialization so tests can inject an in-memory db.
  CorrectionDao.withDatabase(this._db);

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
    await db.execute(kCorrectionsTableCreateSql);
    await db.execute(kCorrectionsTableCourseIndexSql);
    await db.execute(kCorrectionsTableSyncStateIndexSql);
    await db.execute(kCorrectionsTableIdempotencyIndexSql);
  }

  /// Insert or replace a correction.
  /// Uses REPLACE so that the same idempotency key cannot be duplicated.
  Future<void> upsert(CourseCorrection correction) async {
    final db = await _database;
    await db.insert(
      kCorrectionsTableName,
      correction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve a correction by ID.
  Future<CourseCorrection?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      kCorrectionsTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CourseCorrection.fromMap(rows.first);
  }

  /// Retrieve all corrections with a specific sync state.
  /// Used by the sync worker to find pending corrections.
  Future<List<CourseCorrection>> getBySyncState(
    CorrectionSyncState state,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kCorrectionsTableName,
      where: 'sync_state = ?',
      whereArgs: [state.name],
    );
    return rows.map((row) => CourseCorrection.fromMap(row)).toList();
  }

  /// Retrieve all corrections for a specific course.
  Future<List<CourseCorrection>> getByCourseId(String courseId) async {
    final db = await _database;
    final rows = await db.query(
      kCorrectionsTableName,
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'submitted_at DESC',
    );
    return rows.map((row) => CourseCorrection.fromMap(row)).toList();
  }

  /// Update the sync state of a correction by ID.
  /// Returns the number of rows updated.
  Future<int> updateSyncState(String id, CorrectionSyncState state) async {
    final db = await _database;
    return db.update(
      kCorrectionsTableName,
      {'sync_state': state.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Retrieve a correction by its idempotency key.
  /// Used for deduplication before sending to the server.
  Future<CourseCorrection?> getByIdempotencyKey(String key) async {
    final db = await _database;
    final rows = await db.query(
      kCorrectionsTableName,
      where: 'idempotency_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CourseCorrection.fromMap(rows.first);
  }

  /// Delete a correction by ID.
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete(kCorrectionsTableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
