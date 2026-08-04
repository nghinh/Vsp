// StrokesGainedDao Unit Tests — VSP Mobile App
//
// Tests:
//  - upsertSummary inserts and retrieves a summary
//  - upsertSummary replaces an existing summary
//  - getSummaryByRound returns correct summary
//  - getSummaryByRound returns null for non-existent round
//  - getSummaryByDateRange returns correct summary
//  - getSummariesByPlayer returns all summaries for player
//  - deleteSummary removes summary by id
//  - upsertBenchmark inserts and retrieves benchmark
//  - getBenchmark returns correct benchmark
//  - getBenchmarksByType returns all benchmarks for type
//
// Story 11.3 — Slice 2: Repository + OpenAPI

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vsp_mobile/data/local/daos/strokes_gained_dao.dart';
import 'package:vsp_mobile/data/local/tables/strokes_gained_tables.dart';
import 'package:vsp_mobile/domain/models/strokes_gained.dart';

/// Fake path provider for sqflite in tests (in-memory).
class FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp';

  @override
  Future<String?> getTemporaryDirectory() async => '/tmp';
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late StrokesGainedDao dao;

  setUpAll(() {
    PathProviderPlatform.instance = FakePathProvider();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(kStrokesGainedSummariesTableCreateSql);
          await db.execute(kStrokesGainedSummariesPlayerIndexSql);
          await db.execute(kStrokesGainedSummariesRoundIndexSql);
          await db.execute(kSgBenchmarksTableCreateSql);
          await db.execute(kSgBenchmarksPlayerTypeIndexSql);
        },
      ),
    );
    dao = StrokesGainedDao.withDatabase(db);
  });

  tearDown(() async {
    await dao.close();
  });

  // ─── Test Fixtures ────────────────────────────────────────────────────────

  StrokesGainedSummary buildSummary({
    required String playerId,
    String? roundId,
    SGDateRange? dateRange,
    required double overallSG,
    required List<StrokesGainedResult> breakdown,
    List<SGLimitation>? limitations,
  }) {
    return StrokesGainedSummary(
      playerId: playerId,
      roundId: roundId,
      dateRange: dateRange,
      overallStrokesGained: overallSG,
      categoryBreakdown: breakdown,
      limitations: limitations ?? [],
      lastCalculatedAt: DateTime.now(),
    );
  }

  StrokesGainedResult buildResult({
    required SGCategory category,
    required SGBenchmarkType benchmarkType,
    required double sg,
    required int sampleCount,
    SGLimitation? limitation,
  }) {
    return StrokesGainedResult(
      category: category,
      benchmarkType: benchmarkType,
      strokesGained: sg,
      baselineStrokes: 10.0,
      actualStrokes: 10.0 - sg,
      sampleCount: sampleCount,
      limitation: limitation,
      confidence: sampleCount >= 20 ? 0.8 : 0.0,
    );
  }

  SGBenchmarkData buildBenchmark({
    required SGBenchmarkType type,
    required SGCategory category,
    required double baseline,
    int minSample = 20,
  }) {
    return SGBenchmarkData(
      type: type,
      category: category,
      baselineStrokesPerShot: baseline,
      minSampleForCredibility: minSample,
    );
  }

  // ─── Summary Tests ─────────────────────────────────────────────────────────

  group('StrokesGainedDao Summary CRUD', () {
    test('upsertSummary inserts and retrieves a summary', () async {
      final summary = buildSummary(
        playerId: 'player-1',
        roundId: 'round-1',
        overallSG: 2.5,
        breakdown: [
          buildResult(
            category: SGCategory.offTheTee,
            benchmarkType: SGBenchmarkType.similarHandicap,
            sg: 0.5,
            sampleCount: 25,
          ),
        ],
      );

      await dao.upsertSummary(summary);

      final retrieved = await dao.getSummaryByRound('player-1', 'round-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.playerId, equals('player-1'));
      expect(retrieved.roundId, equals('round-1'));
      expect(retrieved.overallStrokesGained, equals(2.5));
      expect(retrieved.categoryBreakdown.length, equals(1));
    });

    test('getSummaryByRound returns null for non-existent round', () async {
      final retrieved = await dao.getSummaryByRound('player-999', 'round-999');
      expect(retrieved, isNull);
    });

    test('getSummariesByPlayer returns all summaries for player', () async {
      final summary1 = buildSummary(
        playerId: 'player-1',
        roundId: 'round-1',
        overallSG: 1.0,
        breakdown: [],
      );
      final summary2 = buildSummary(
        playerId: 'player-1',
        roundId: 'round-2',
        overallSG: 2.0,
        breakdown: [],
      );

      await dao.upsertSummary(summary1);
      await dao.upsertSummary(summary2);

      final summaries = await dao.getSummariesByPlayer('player-1');

      expect(summaries.length, greaterThanOrEqualTo(2));
      expect(summaries.map((s) => s.roundId), contains('round-1'));
      expect(summaries.map((s) => s.roundId), contains('round-2'));
    });

    test('getSummaryByDateRange returns correct summary', () async {
      final now = DateTime.now();
      final dateRange = SGDateRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      );

      final summary = buildSummary(
        playerId: 'player-1',
        dateRange: dateRange,
        overallSG: 3.0,
        breakdown: [],
      );

      await dao.upsertSummary(summary);

      final retrieved = await dao.getSummaryByDateRange(
        'player-1',
        dateRange.start,
        dateRange.end,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.overallStrokesGained, equals(3.0));
    });

    test('deleteSummary removes summary by id', () async {
      final summary = buildSummary(
        playerId: 'player-1',
        roundId: 'round-to-delete',
        overallSG: 1.0,
        breakdown: [],
      );

      await dao.upsertSummary(summary);
      var retrieved = await dao.getSummaryByRound(
        'player-1',
        'round-to-delete',
      );
      expect(retrieved, isNotNull);

      // Delete by constructing an id pattern (player_id_roundid_timestamp)
      final ids = await db.query(kStrokesGainedSummariesTableName);
      if (ids.isNotEmpty) {
        await dao.deleteSummary(ids.first['id'] as String);
      }

      retrieved = await dao.getSummaryByRound('player-1', 'round-to-delete');
      // After delete, should return most recent remaining or null
      expect(retrieved?.roundId, isNot(equals('round-to-delete')));
    });
  });

  // ─── Benchmark Tests ────────────────────────────────────────────────────────

  group('StrokesGainedDao Benchmark CRUD', () {
    test('upsertBenchmark inserts and retrieves benchmark', () async {
      final benchmark = buildBenchmark(
        type: SGBenchmarkType.similarHandicap,
        category: SGCategory.offTheTee,
        baseline: 3.1,
      );

      await dao.upsertBenchmark(benchmark, 'player-1');

      final retrieved = await dao.getBenchmark(
        'player-1',
        SGBenchmarkType.similarHandicap,
        SGCategory.offTheTee,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.baselineStrokesPerShot, equals(3.1));
      expect(retrieved.type, equals(SGBenchmarkType.similarHandicap));
      expect(retrieved.category, equals(SGCategory.offTheTee));
    });

    test('getBenchmark returns null for non-existent benchmark', () async {
      final retrieved = await dao.getBenchmark(
        'player-999',
        SGBenchmarkType.professional,
        SGCategory.putting,
      );
      expect(retrieved, isNull);
    });

    test('getBenchmarksByType returns all benchmarks for type', () async {
      await dao.upsertBenchmark(
        buildBenchmark(
          type: SGBenchmarkType.similarHandicap,
          category: SGCategory.offTheTee,
          baseline: 3.1,
        ),
        'player-1',
      );
      await dao.upsertBenchmark(
        buildBenchmark(
          type: SGBenchmarkType.similarHandicap,
          category: SGCategory.approach,
          baseline: 3.7,
        ),
        'player-1',
      );
      await dao.upsertBenchmark(
        buildBenchmark(
          type: SGBenchmarkType.professional,
          category: SGCategory.offTheTee,
          baseline: 3.0,
        ),
        'player-1',
      );

      final results = await dao.getBenchmarksByType(
        'player-1',
        SGBenchmarkType.similarHandicap,
      );

      expect(results.length, equals(2));
      expect(results.map((b) => b.category), contains(SGCategory.offTheTee));
      expect(results.map((b) => b.category), contains(SGCategory.approach));
    });

    test('upsertBenchmark replaces existing benchmark', () async {
      final original = buildBenchmark(
        type: SGBenchmarkType.similarHandicap,
        category: SGCategory.offTheTee,
        baseline: 3.1,
      );
      await dao.upsertBenchmark(original, 'player-1');

      final updated = buildBenchmark(
        type: SGBenchmarkType.similarHandicap,
        category: SGCategory.offTheTee,
        baseline: 3.2,
      );
      await dao.upsertBenchmark(updated, 'player-1');

      final retrieved = await dao.getBenchmark(
        'player-1',
        SGBenchmarkType.similarHandicap,
        SGCategory.offTheTee,
      );

      expect(retrieved!.baselineStrokesPerShot, equals(3.2));
    });
  });
}
