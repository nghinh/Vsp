// Round Repository — VSP Mobile App
//
// SQLite-backed persistence for Round entities.
// Uses vsp_round.db, shared with HoleScoreRepository and PlayerRepository.
//
// Story 5.2: Persist Round Locally

import 'package:sqflite/sqflite.dart';

import '../../domain/models/round.dart';

/// Repository for persisting and retrieving Round entities locally.
class RoundRepository {
  static const String _tableName = 'rounds';
  static const String _dbName = 'vsp_round.db';
  static const int _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        course_id INTEGER NOT NULL,
        course_name TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        package_version TEXT NOT NULL,
        tournament_policy_id TEXT,
        tournament_id TEXT,
        tournament_policy_version INTEGER,
        tournament_policy_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Index for active round lookup
    await db.execute('''
      CREATE INDEX idx_rounds_status ON $_tableName (status)
    ''');
    // Index for tournament round lookup
    await db.execute('''
      CREATE INDEX idx_rounds_tournament_policy ON $_tableName (tournament_policy_id)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Per Story 12.1 Slice F: add tournament columns
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN tournament_id TEXT');
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN tournament_policy_version INTEGER',
      );
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN tournament_policy_json TEXT',
      );
      await db.execute('''
        CREATE INDEX idx_rounds_tournament_policy
        ON $_tableName (tournament_policy_id)
      ''');
    }
  }

  /// Insert a new round. Uses ON CONFLICT rollback for atomicity.
  Future<void> createRound(Round round) async {
    final db = await database;
    await db.insert(
      _tableName,
      round.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Update an existing round.
  Future<void> updateRound(Round round) async {
    final db = await database;
    final updated = round.copyWith(updatedAt: DateTime.now());
    await db.update(
      _tableName,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [round.id],
    );
  }

  /// Retrieve a round by ID.
  Future<Round?> getRound(String id) async {
    final db = await database;
    final rows = await db.query(_tableName, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Round.fromMap(rows.first);
  }

  /// Retrieve the currently active round (status = 'inProgress').
  Future<Round?> getActiveRound() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: [RoundStatus.inProgress.name],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Round.fromMap(rows.first);
  }

  /// Retrieve all rounds for a course.
  Future<List<Round>> getRoundsByCourse(int courseId) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'started_at DESC',
    );
    return rows.map((row) => Round.fromMap(row)).toList();
  }

  /// Execute a transaction wrapping multiple table writes atomically.
  Future<T> transactional<T>(Future<T> Function(Transaction) action) async {
    final db = await database;
    return db.transaction(action);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
