// SQLite Strokes Gained Repository — VSP Mobile App
//
// SQLite-backed implementation of StrokesGainedRepository for Smart Target.
//
// Per slice-plan-11-4.md Slice 4:
// - Reads from local SQLite (written by 11.3)
// - Offline-first: works without network when data available locally
//
// Story 11.4 — Slice 4: Real SQLite Repos + Offline

import 'package:sqflite/sqflite.dart';

import '../../domain/analytics/smart_target/repositories/strokes_gained_repository.dart';

/// Table definition for strokes_gained_results.
const String kStrokesGainedResultsTableName = 'strokes_gained_results';
const String kStrokesGainedResultsTableCreateSql = '''
  CREATE TABLE strokes_gained_results (
    id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    club_id TEXT NOT NULL,
    strokes_gained_per_shot REAL NOT NULL,
    strokes_gained_total REAL NOT NULL,
    shot_count INTEGER NOT NULL,
    benchmark_avg_meters REAL NOT NULL,
    actual_avg_meters REAL NOT NULL,
    benchmark_type TEXT NOT NULL,
    computed_at TEXT NOT NULL,
    UNIQUE(player_id, club_id, benchmark_type)
  )
''';

const String kStrokesGainedResultsPlayerIndexSql = '''
  CREATE INDEX idx_sg_player ON strokes_gained_results (player_id)
''';

/// Table definition for strokes_gained_summary.
const String kStrokesGainedSummaryTableName = 'strokes_gained_summary';
const String kStrokesGainedSummaryTableCreateSql = '''
  CREATE TABLE strokes_gained_summary (
    id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    total_strokes_gained REAL NOT NULL,
    avg_strokes_gained_per_round REAL NOT NULL,
    total_shot_count INTEGER NOT NULL,
    strokes_gained_by_club_json TEXT NOT NULL,
    computed_at TEXT NOT NULL,
    UNIQUE(player_id)
  )
''';

/// SQLite-backed implementation of StrokesGainedRepository.
///
/// Reads strokes gained data from local SQLite that was written by Story 11.3.
/// Provides offline-first behavior: returns cached data when network unavailable.
class SqliteStrokesGainedRepository implements StrokesGainedRepository {
  static const String _dbName = 'vsp_smart_target.db';
  static const int _dbVersion = 1;

  Database? _db;
  final Database? _injectedDb;

  SqliteStrokesGainedRepository({Database? injectedDb})
    : _injectedDb = injectedDb;

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
    await db.execute(kStrokesGainedResultsTableCreateSql);
    await db.execute(kStrokesGainedResultsPlayerIndexSql);
    await db.execute(kStrokesGainedSummaryTableCreateSql);
  }

  @override
  Future<StrokesGainedResult?> getByClub(String playerId, String clubId) async {
    final db = await _database;
    final rows = await db.query(
      kStrokesGainedResultsTableName,
      where: 'player_id = ? AND club_id = ?',
      whereArgs: [playerId, clubId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _resultFromMap(rows.first);
  }

  @override
  Future<List<StrokesGainedResult>> getAllForPlayer(String playerId) async {
    final db = await _database;
    final rows = await db.query(
      kStrokesGainedResultsTableName,
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
    return rows.map((row) => _resultFromMap(row)).toList();
  }

  @override
  Future<StrokesGainedSummary?> getSummaryForPlayer(String playerId) async {
    final db = await _database;
    final rows = await db.query(
      kStrokesGainedSummaryTableName,
      where: 'player_id = ?',
      whereArgs: [playerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _summaryFromMap(rows.first);
  }

  StrokesGainedResult _resultFromMap(Map<String, dynamic> map) {
    return StrokesGainedResult(
      playerId: map['player_id'] as String,
      clubId: map['club_id'] as String,
      strokesGainedPerShot: (map['strokes_gained_per_shot'] as num).toDouble(),
      strokesGainedTotal: (map['strokes_gained_total'] as num).toDouble(),
      shotCount: (map['shot_count'] as num).toInt(),
      benchmarkAvgMeters: (map['benchmark_avg_meters'] as num).toDouble(),
      actualAvgMeters: (map['actual_avg_meters'] as num).toDouble(),
      benchmarkType: map['benchmark_type'] as String,
    );
  }

  StrokesGainedSummary _summaryFromMap(Map<String, dynamic> map) {
    // Parse strokes_gained_by_club_json
    final sgByClub = <String, double>{};
    final serialized = map['strokes_gained_by_club_json'] as String? ?? '';
    for (final entry in serialized.split(',')) {
      final separator = entry.indexOf(':');
      if (separator <= 0) continue;
      final value = double.tryParse(entry.substring(separator + 1));
      if (value != null) {
        sgByClub[entry.substring(0, separator)] = value;
      }
    }

    return StrokesGainedSummary(
      playerId: map['player_id'] as String,
      totalStrokesGained: (map['total_strokes_gained'] as num).toDouble(),
      avgStrokesGainedPerRound: (map['avg_strokes_gained_per_round'] as num)
          .toDouble(),
      totalShotCount: (map['total_shot_count'] as num).toInt(),
      strokesGainedByClub: sgByClub,
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
