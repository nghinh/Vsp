// Strokes Gained DAO — VSP Mobile App
//
// SQLite Data Access Object for Strokes Gained summary and benchmark entities.
// Provides CRUD operations on the strokes_gained_summaries and sg_benchmarks tables.
//
// Story 11.3 — Slice 2: Repository + OpenAPI

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/strokes_gained.dart';
import '../round_database.dart';
import '../tables/strokes_gained_tables.dart';

/// Data Access Object for Strokes Gained persistence.
/// Uses vsp_round.db (shares database with score/shot data).
class StrokesGainedDao {
  Database? _db;
  final Database? _injectedDb;

  /// Constructor for production use (creates own database connection).
  StrokesGainedDao({Database? injectedDb}) : _injectedDb = injectedDb;

  /// Named constructor for test injection.
  StrokesGainedDao.withDatabase(this._injectedDb);

  Future<Database> get _database async {
    if (_injectedDb != null) return _injectedDb;
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  // `vsp_round.db` is shared across round DAOs; open it through the shared
  // helper so the full schema exists regardless of open order.
  Future<Database> _initDb() => openRoundDatabase();

  // ─── Summary CRUD ───────────────────────────────────────────────────────

  /// Insert or replace a StrokesGainedSummary.
  Future<void> upsertSummary(StrokesGainedSummary summary) async {
    final db = await _database;
    final now = DateTime.now();
    final id =
        '${summary.playerId}_${summary.roundId ?? 'dateRange'}_${summary.lastCalculatedAt.millisecondsSinceEpoch}';

    await db.insert(
      kStrokesGainedSummariesTableName,
      {
        'id': id,
        'player_id': summary.playerId,
        'round_id': summary.roundId,
        'date_range_start': summary.dateRange?.start.toIso8601String(),
        'date_range_end': summary.dateRange?.end.toIso8601String(),
        'overall_sg': summary.overallStrokesGained,
        'category_breakdown_json': jsonEncode(
          summary.categoryBreakdown.map((r) => r.toJson()).toList(),
        ),
        'limitations_json': jsonEncode(
          summary.limitations.map((l) => l.toApiValue()).toList(),
        ),
        'confidence': _averageConfidence(summary.categoryBreakdown),
        'last_calculated_at': summary.lastCalculatedAt.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the most recent summary for a player and round.
  Future<StrokesGainedSummary?> getSummaryByRound(
    String playerId,
    String roundId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kStrokesGainedSummariesTableName,
      where: 'player_id = ? AND round_id = ?',
      whereArgs: [playerId, roundId],
      orderBy: 'last_calculated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _summaryFromMap(rows.first);
  }

  /// Get the most recent summary for a player within a date range.
  Future<StrokesGainedSummary?> getSummaryByDateRange(
    String playerId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kStrokesGainedSummariesTableName,
      where: 'player_id = ? AND date_range_start = ? AND date_range_end = ?',
      whereArgs: [playerId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'last_calculated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _summaryFromMap(rows.first);
  }

  /// Get all summaries for a player.
  Future<List<StrokesGainedSummary>> getSummariesByPlayer(
    String playerId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kStrokesGainedSummariesTableName,
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'last_calculated_at DESC',
    );
    return rows.map((row) => _summaryFromMap(row)).toList();
  }

  /// Delete a summary by ID.
  Future<void> deleteSummary(String id) async {
    final db = await _database;
    await db.delete(
      kStrokesGainedSummariesTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Benchmark CRUD ─────────────────────────────────────────────────────

  /// Upsert a benchmark data entry.
  Future<void> upsertBenchmark(
    SGBenchmarkData benchmark,
    String playerId,
  ) async {
    final db = await _database;
    final now = DateTime.now();
    final id = '${playerId}_${benchmark.type.name}_${benchmark.category.name}';

    await db.insert(kSgBenchmarksTableName, {
      'id': id,
      'player_id': playerId,
      'benchmark_type': benchmark.type.toApiValue(),
      'category': benchmark.category.toApiValue(),
      'baseline_strokes': benchmark.baselineStrokesPerShot,
      'sample_count': benchmark.minSampleForCredibility,
      'updated_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get benchmark data for a player, type, and category.
  Future<SGBenchmarkData?> getBenchmark(
    String playerId,
    SGBenchmarkType type,
    SGCategory category,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kSgBenchmarksTableName,
      where: 'player_id = ? AND benchmark_type = ? AND category = ?',
      whereArgs: [playerId, type.toApiValue(), category.toApiValue()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _benchmarkFromMap(rows.first);
  }

  /// Get all benchmarks for a player and type.
  Future<List<SGBenchmarkData>> getBenchmarksByType(
    String playerId,
    SGBenchmarkType type,
  ) async {
    final db = await _database;
    final rows = await db.query(
      kSgBenchmarksTableName,
      where: 'player_id = ? AND benchmark_type = ?',
      whereArgs: [playerId, type.toApiValue()],
    );
    return rows.map((row) => _benchmarkFromMap(row)).toList();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  StrokesGainedSummary _summaryFromMap(Map<String, dynamic> map) {
    final categoryBreakdownJson =
        jsonDecode(map['category_breakdown_json'] as String) as List;
    final limitationsJson =
        jsonDecode(map['limitations_json'] as String) as List;

    SGDateRange? dateRange;
    if (map['date_range_start'] != null && map['date_range_end'] != null) {
      dateRange = SGDateRange(
        start: DateTime.parse(map['date_range_start'] as String),
        end: DateTime.parse(map['date_range_end'] as String),
      );
    }

    return StrokesGainedSummary(
      playerId: map['player_id'] as String,
      roundId: map['round_id'] as String?,
      dateRange: dateRange,
      overallStrokesGained: (map['overall_sg'] as num).toDouble(),
      categoryBreakdown: categoryBreakdownJson
          .map(
            (json) =>
                StrokesGainedResult.fromJson(json as Map<String, dynamic>),
          )
          .toList(),
      limitations: limitationsJson
          .map(
            (l) =>
                SGLimitation.fromString(l as String) ??
                SGLimitation.insufficientSample,
          )
          .toList(),
      lastCalculatedAt: DateTime.parse(map['last_calculated_at'] as String),
    );
  }

  SGBenchmarkData _benchmarkFromMap(Map<String, dynamic> map) {
    return SGBenchmarkData(
      type:
          SGBenchmarkType.fromString(map['benchmark_type'] as String) ??
          SGBenchmarkType.similarHandicap,
      category:
          SGCategory.fromString(map['category'] as String) ??
          SGCategory.offTheTee,
      baselineStrokesPerShot: (map['baseline_strokes'] as num).toDouble(),
      minSampleForCredibility: (map['sample_count'] as num?)?.toInt() ?? 20,
    );
  }

  double _averageConfidence(List<StrokesGainedResult> breakdown) {
    if (breakdown.isEmpty) return 0.0;
    return breakdown.fold<double>(0.0, (sum, r) => sum + r.confidence) /
        breakdown.length;
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
