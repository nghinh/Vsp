// Tournament Repository — VSP Mobile App
//
// Per Story 12.1 Slice H:
// - Persists tournament data for offline access
// - Caches tournament policy locally for offline restricted feature checks
//
// Story 12.1 Slice H

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/tournament/models.dart';

/// Repository for persisting tournament data locally.
class TournamentRepository {
  static const String _tableName = 'tournaments';
  static const String _dbName = 'vsp_tournament.db';
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
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        format TEXT NOT NULL,
        status TEXT NOT NULL,
        course_id INTEGER NOT NULL,
        course_name TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        tournament_policy_id TEXT,
        registration_deadline TEXT,
        max_players INTEGER,
        description TEXT,
        created_at TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        leaderboard_version INTEGER NOT NULL DEFAULT 0,
        cached_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_tournaments_status ON $_tableName (status)',
    );
  }

  /// Save a tournament to local cache.
  Future<void> saveTournament(Tournament tournament) async {
    final db = await _database;
    await db.insert(
      _tableName,
      _toMap(tournament),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a tournament by ID from local cache.
  Future<Tournament?> getTournament(String id) async {
    final db = await _database;
    final rows = await db.query(_tableName, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  /// List cached tournaments.
  Future<List<Tournament>> listTournaments({TournamentStatus? status}) async {
    final db = await _database;
    final rows = status != null
        ? await db.query(
            _tableName,
            where: 'status = ?',
            whereArgs: [status.name.toUpperCase()],
            orderBy: 'start_date DESC',
          )
        : await db.query(_tableName, orderBy: 'start_date DESC');
    return rows.map(_fromMap).toList();
  }

  /// Invalidate cached tournament (e.g., when tournament is updated).
  Future<void> invalidate(String tournamentId) async {
    final db = await _database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [tournamentId]);
  }

  Map<String, dynamic> _toMap(Tournament t) {
    return {
      'id': t.id,
      'name': t.name,
      'format': t.format.name,
      'status': t.status.name.toUpperCase(),
      'course_id': t.courseId,
      'course_name': t.courseName,
      'start_date': t.startDate.toUtc().toIso8601String(),
      'end_date': t.endDate.toUtc().toIso8601String(),
      'tournament_policy_id': t.tournamentPolicyId,
      'registration_deadline': t.registrationDeadline
          ?.toUtc()
          .toIso8601String(),
      'max_players': t.maxPlayers,
      'description': t.description,
      'created_at': t.createdAt.toUtc().toIso8601String(),
      'created_by': t.createdBy,
      'version': t.version,
      'leaderboard_version': t.leaderboardVersion,
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Tournament _fromMap(Map<String, dynamic> map) {
    return Tournament(
      id: map['id'] as String,
      name: map['name'] as String,
      format: TournamentFormatExtension.fromString(map['format'] as String),
      status: TournamentStatusExtension.fromString(map['status'] as String),
      courseId: map['course_id'] as int,
      courseName: map['course_name'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      tournamentPolicyId: map['tournament_policy_id'] as String?,
      registrationDeadline: map['registration_deadline'] != null
          ? DateTime.parse(map['registration_deadline'] as String)
          : null,
      maxPlayers: map['max_players'] as int?,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      createdBy: map['created_by'] as int,
      version: map['version'] as int? ?? 1,
      leaderboardVersion: map['leaderboard_version'] as int? ?? 0,
    );
  }

  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
