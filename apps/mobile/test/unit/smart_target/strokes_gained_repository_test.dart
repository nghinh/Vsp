// StrokesGainedRepository Unit Tests — VSP Mobile App
//
// Tests for InMemoryStrokesGainedRepository stub.
//
// Story 11.4 — Slice 1: Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/repositories/strokes_gained_repository.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/repositories/in_memory_strokes_gained_repository.dart';

void main() {
  late InMemoryStrokesGainedRepository repo;

  final seedResults = [
    const StrokesGainedResult(
      playerId: 'player-1',
      clubId: 'club-7',
      strokesGainedPerShot: 0.15,
      strokesGainedTotal: 7.5,
      shotCount: 50,
      benchmarkAvgMeters: 145.0,
      actualAvgMeters: 150.0,
      benchmarkType: 'scramble_index',
    ),
    const StrokesGainedResult(
      playerId: 'player-1',
      clubId: 'club-5',
      strokesGainedPerShot: -0.05,
      strokesGainedTotal: -0.5,
      shotCount: 10,
      benchmarkAvgMeters: 165.0,
      actualAvgMeters: 170.0,
      benchmarkType: 'scramble_index',
    ),
  ];

  final seedSummary = const StrokesGainedSummary(
    playerId: 'player-1',
    totalStrokesGained: 7.0,
    avgStrokesGainedPerRound: 0.5,
    totalShotCount: 100,
    strokesGainedByClub: {
      'club-7': 0.15,
      'club-5': -0.05,
    },
  );

  setUp(() {
    repo = InMemoryStrokesGainedRepository(
      seeds: seedResults,
      summary: seedSummary,
    );
  });

  group('StrokesGainedResult', () {
    test('fromJson / toJson round-trip is lossless', () {
      const result = StrokesGainedResult(
        playerId: 'player-1',
        clubId: 'club-7',
        strokesGainedPerShot: 0.15,
        strokesGainedTotal: 7.5,
        shotCount: 50,
        benchmarkAvgMeters: 145.0,
        actualAvgMeters: 150.0,
        benchmarkType: 'scramble_index',
      );
      final restored = StrokesGainedResult.fromJson(result.toJson());
      expect(restored, result);
    });
  });

  group('StrokesGainedSummary', () {
    test('fromJson / toJson round-trip is lossless', () {
      final restored = StrokesGainedSummary.fromJson(seedSummary.toJson());
      expect(restored.playerId, seedSummary.playerId);
      expect(restored.totalStrokesGained, seedSummary.totalStrokesGained);
      expect(restored.strokesGainedByClub['club-7'], 0.15);
    });
  });

  group('InMemoryStrokesGainedRepository', () {
    test('getByClub returns correct result', () async {
      final result = await repo.getByClub('player-1', 'club-7');
      expect(result, isNotNull);
      expect(result!.clubId, 'club-7');
      expect(result.strokesGainedPerShot, 0.15);
    });

    test('getByClub returns null for unknown club', () async {
      final result = await repo.getByClub('player-1', 'club-unknown');
      expect(result, isNull);
    });

    test('getAllForPlayer returns all results for player', () async {
      final results = await repo.getAllForPlayer('player-1');
      expect(results.length, 2);
    });

    test('getAllForPlayer returns empty for unknown player', () async {
      final results = await repo.getAllForPlayer('player-unknown');
      expect(results, isEmpty);
    });

    test('getSummaryForPlayer returns summary', () async {
      final summary = await repo.getSummaryForPlayer('player-1');
      expect(summary, isNotNull);
      expect(summary!.totalStrokesGained, 7.0);
    });

    test('getSummaryForPlayer returns null for unknown player', () async {
      final summary = await repo.getSummaryForPlayer('player-unknown');
      expect(summary, isNull);
    });

    test('addResult adds new result', () async {
      repo.addResult(const StrokesGainedResult(
        playerId: 'player-1',
        clubId: 'club-driver',
        strokesGainedPerShot: 0.2,
        strokesGainedTotal: 1.0,
        shotCount: 5,
        benchmarkAvgMeters: 210.0,
        actualAvgMeters: 220.0,
        benchmarkType: 'scramble_index',
      ));

      final result = await repo.getByClub('player-1', 'club-driver');
      expect(result, isNotNull);
      expect(result!.strokesGainedPerShot, 0.2);
    });

    test('setSummary updates summary', () async {
      repo.setSummary(const StrokesGainedSummary(
        playerId: 'player-1',
        totalStrokesGained: 10.0,
        avgStrokesGainedPerRound: 1.0,
        totalShotCount: 200,
        strokesGainedByClub: {},
      ));

      final summary = await repo.getSummaryForPlayer('player-1');
      expect(summary!.totalStrokesGained, 10.0);
    });

    test('clear removes all results and summary', () async {
      repo.clear();
      final results = await repo.getAllForPlayer('player-1');
      final summary = await repo.getSummaryForPlayer('player-1');
      expect(results, isEmpty);
      expect(summary, isNull);
    });
  });
}
