// Conditions Local Datasource — VSP Mobile App
//
// SQLite-backed persistence for course conditions and pin positions.
// Provides offline access with cachedAt timestamp per Story 7.3 AC-3.
//
// Story 7.3 — Slice 2: Repository/Persistence

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/condition_entry.dart';
import '../../hole_map/domain/pin_entity.dart';
import 'conditions_repository.dart';

/// SQLite implementation of ConditionsRepository for offline persistence.
class ConditionsLocalDatasource implements ConditionsRepository {
  static const String _dbName = 'vsp_conditions.db';
  static const int _dbVersion = 1;
  static const String _conditionsTable = 'cached_conditions';
  static const String _pinsTable = 'cached_pins';

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
      CREATE TABLE $_conditionsTable (
        course_id INTEGER NOT NULL,
        condition_type TEXT NOT NULL,
        severity TEXT NOT NULL,
        description TEXT,
        effective_date TEXT,
        accuracy_class TEXT NOT NULL,
        source TEXT,
        confidence REAL,
        expiry_date TEXT,
        cached_at TEXT NOT NULL,
        PRIMARY KEY (course_id, condition_type)
      )
    ''');

    await db.execute('''
      CREATE TABLE $_pinsTable (
        hole_id TEXT PRIMARY KEY,
        course_id INTEGER NOT NULL,
        hole_number INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        source TEXT NOT NULL,
        confidence REAL,
        snapshot_date TEXT,
        effective_date TEXT,
        expiry_date TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_conditions_course ON $_conditionsTable (course_id)',
    );
    await db.execute('CREATE INDEX idx_pins_course ON $_pinsTable (course_id)');
  }

  @override
  Future<List<ConditionEntry>> getConditions({
    required int courseId,
    ConditionType? conditionType,
    bool includeExpired = false,
  }) async {
    final db = await _database;

    String whereClause = 'course_id = ?';
    List<dynamic> whereArgs = [courseId];

    if (conditionType != null) {
      whereClause += ' AND condition_type = ?';
      whereArgs.add(conditionType.value);
    }

    if (!includeExpired) {
      whereClause += ' AND (expiry_date IS NULL OR expiry_date > ?)';
      whereArgs.add(DateTime.now().toIso8601String());
    }

    final rows = await db.query(
      _conditionsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'condition_type ASC',
    );

    return rows.map((row) => _conditionEntryFromRow(row)).toList();
  }

  @override
  Future<PinEntity?> getActivePin({required String holeId}) async {
    final db = await _database;

    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      _pinsTable,
      where: 'hole_id = ? AND (expiry_date IS NULL OR expiry_date > ?)',
      whereArgs: [holeId, now],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _pinEntityFromRow(rows.first);
  }

  @override
  Future<List<PinEntity>> getActivePins({required int courseId}) async {
    final db = await _database;

    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      _pinsTable,
      where: 'course_id = ? AND (expiry_date IS NULL OR expiry_date > ?)',
      whereArgs: [courseId, now],
      orderBy: 'hole_number ASC',
    );

    return rows.map((row) => _pinEntityFromRow(row)).toList();
  }

  @override
  Future<void> cacheConditions({
    required int courseId,
    required List<ConditionEntry> conditions,
    required DateTime cachedAt,
  }) async {
    final db = await _database;

    await db.transaction((txn) async {
      // Clear existing cache for this course
      await txn.delete(
        _conditionsTable,
        where: 'course_id = ?',
        whereArgs: [courseId],
      );

      // Insert new conditions
      for (final condition in conditions) {
        await txn.insert(
          _conditionsTable,
          _conditionToRow(courseId, condition, cachedAt),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<({List<ConditionEntry> conditions, DateTime cachedAt})?>
  getCachedConditions({required int courseId}) async {
    final db = await _database;

    final rows = await db.query(
      _conditionsTable,
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'condition_type ASC',
    );

    if (rows.isEmpty) return null;

    final cachedAtStr = rows.first['cached_at'] as String;
    final cachedAt = DateTime.parse(cachedAtStr);
    final conditions = rows.map((row) => _conditionEntryFromRow(row)).toList();

    return (conditions: conditions, cachedAt: cachedAt);
  }

  @override
  Future<void> clearConditionsCache({required int courseId}) async {
    final db = await _database;

    await db.transaction((txn) async {
      await txn.delete(
        _conditionsTable,
        where: 'course_id = ?',
        whereArgs: [courseId],
      );
      await txn.delete(
        _pinsTable,
        where: 'course_id = ?',
        whereArgs: [courseId],
      );
    });
  }

  /// Cache a pin for a hole.
  Future<void> cachePin({
    required int courseId,
    required PinEntity pin,
    required DateTime cachedAt,
  }) async {
    final db = await _database;
    await db.insert(
      _pinsTable,
      _pinToRow(courseId, pin, cachedAt),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _conditionToRow(
    int courseId,
    ConditionEntry condition,
    DateTime cachedAt,
  ) {
    return {
      'course_id': courseId,
      'condition_type': condition.conditionType.value,
      'severity': condition.severity.value,
      'description': condition.description,
      'effective_date': condition.effectiveDate?.toIso8601String(),
      'accuracy_class': condition.accuracyClass,
      'source': condition.source?.value,
      'confidence': condition.confidence,
      'expiry_date': condition.expiryDate?.toIso8601String(),
      'cached_at': cachedAt.toIso8601String(),
    };
  }

  ConditionEntry _conditionEntryFromRow(Map<String, dynamic> row) {
    return ConditionEntry(
      conditionType: ConditionType.fromString(row['condition_type'] as String),
      severity: ConditionSeverity.fromString(row['severity'] as String),
      description: row['description'] as String?,
      effectiveDate: row['effective_date'] != null
          ? DateTime.tryParse(row['effective_date'] as String)
          : null,
      accuracyClass: row['accuracy_class'] as String,
      source: row['source'] != null
          ? ConditionSource.fromString(row['source'] as String)
          : null,
      confidence: (row['confidence'] as num?)?.toDouble(),
      expiryDate: row['expiry_date'] != null
          ? DateTime.tryParse(row['expiry_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> _pinToRow(
    int courseId,
    PinEntity pin,
    DateTime cachedAt,
  ) {
    return {
      'hole_id': pin.holeId,
      'course_id': courseId,
      'hole_number': pin.holeNumber,
      'latitude': pin.latitude,
      'longitude': pin.longitude,
      'source': pin.source.name,
      'confidence': pin.confidence,
      'snapshot_date': pin.snapshotDate?.toIso8601String(),
      'effective_date': pin.effectiveDate?.toIso8601String(),
      'expiry_date': pin.expiryDate?.toIso8601String(),
      'cached_at': cachedAt.toIso8601String(),
    };
  }

  PinEntity _pinEntityFromRow(Map<String, dynamic> row) {
    return PinEntity(
      holeId: row['hole_id'] as String,
      holeNumber: (row['hole_number'] as num).toInt(),
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      source: PinSource.values.firstWhere(
        (e) => e.name == (row['source'] as String),
        orElse: () => PinSource.manual,
      ),
      confidence: (row['confidence'] as num?)?.toDouble(),
      snapshotDate: row['snapshot_date'] != null
          ? DateTime.tryParse(row['snapshot_date'] as String)
          : null,
      effectiveDate: row['effective_date'] != null
          ? DateTime.tryParse(row['effective_date'] as String)
          : null,
      expiryDate: row['expiry_date'] != null
          ? DateTime.tryParse(row['expiry_date'] as String)
          : null,
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
