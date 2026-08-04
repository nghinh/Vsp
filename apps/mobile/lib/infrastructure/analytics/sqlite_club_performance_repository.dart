// SQLite Club Performance Repository — VSP Mobile App
//
// SQLite-backed implementation of ClubPerformanceRepository for Smart Target.
//
// Per slice-plan-11-4.md Slice 4:
// - Reads from local SQLite (written by 11.1)
// - Offline-first: works without network when data available locally
//
// Story 11.4 — Slice 4: Real SQLite Repos + Offline

import 'package:sqflite/sqflite.dart';

import '../../domain/analytics/smart_target/repositories/club_performance_repository.dart';

/// Table definition for club_performance_stats.
const String kClubPerformanceTableName = 'club_performance_stats';
const String kClubPerformanceTableCreateSql = '''
  CREATE TABLE club_performance_stats (
    id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    club_id TEXT NOT NULL,
    club_name TEXT NOT NULL,
    loft_degrees REAL,
    avg_carry_meters REAL NOT NULL,
    median_carry_meters REAL NOT NULL,
    dispersion_meters REAL NOT NULL,
    left_bias_meters REAL NOT NULL DEFAULT 0,
    right_bias_meters REAL NOT NULL DEFAULT 0,
    sample_count INTEGER NOT NULL DEFAULT 0,
    confidence REAL NOT NULL DEFAULT 0,
    computed_at TEXT NOT NULL,
    UNIQUE(player_id, club_id)
  )
''';

const String kClubPerformancePlayerIndexSql = '''
  CREATE INDEX idx_cp_player ON club_performance_stats (player_id)
''';

/// SQLite-backed implementation of ClubPerformanceRepository.
///
/// Reads club performance data from local SQLite that was written by Story 11.1.
/// Provides offline-first behavior: returns cached data when network unavailable.
class SqliteClubPerformanceRepository implements ClubPerformanceRepository {
  static const String _dbName = 'vsp_smart_target.db';
  static const int _dbVersion = 1;

  Database? _db;
  final Database? _injectedDb;

  SqliteClubPerformanceRepository({Database? injectedDb})
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
    await db.execute(kClubPerformanceTableCreateSql);
    await db.execute(kClubPerformancePlayerIndexSql);
  }

  @override
  Future<ClubPerformanceStats?> getByClubId(String clubId) async {
    final db = await _database;
    final rows = await db.query(
      kClubPerformanceTableName,
      where: 'club_id = ?',
      whereArgs: [clubId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  @override
  Future<List<ClubPerformanceStats>> getAllForPlayer(String playerId) async {
    final db = await _database;
    final rows = await db.query(
      kClubPerformanceTableName,
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
    return rows.map((row) => _fromMap(row)).toList();
  }

  @override
  Future<List<ClubPerformanceStats>> getReliableClubs(
    String playerId, {
    int minSampleCount = 5,
  }) async {
    final db = await _database;
    final rows = await db.query(
      kClubPerformanceTableName,
      where: 'player_id = ? AND sample_count >= ?',
      whereArgs: [playerId, minSampleCount],
    );
    return rows.map((row) => _fromMap(row)).toList();
  }

  @override
  Future<bool> hasSufficientData(String playerId, {int minClubs = 3}) async {
    final clubs = await getReliableClubs(playerId, minSampleCount: 3);
    return clubs.length >= minClubs;
  }

  ClubPerformanceStats _fromMap(Map<String, dynamic> map) {
    return ClubPerformanceStats(
      clubId: map['club_id'] as String,
      clubName: map['club_name'] as String,
      loftDegrees: (map['loft_degrees'] as num?)?.toDouble(),
      avgCarryMeters: (map['avg_carry_meters'] as num).toDouble(),
      medianCarryMeters: (map['median_carry_meters'] as num).toDouble(),
      dispersionMeters: (map['dispersion_meters'] as num).toDouble(),
      leftBiasMeters: (map['left_bias_meters'] as num).toDouble(),
      rightBiasMeters: (map['right_bias_meters'] as num).toDouble(),
      sampleCount: map['sample_count'] as int,
      confidence: (map['confidence'] as num).toDouble(),
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
