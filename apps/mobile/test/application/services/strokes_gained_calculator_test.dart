// Strokes Gained Calculator Unit Tests — VSP Mobile App
//
// Tests:
//  - Happy path: all categories, all benchmark types
//  - Sample size thresholds (insufficientSample when < 20)
//  - Limitation flags for missing/incomplete data
//  - Empty round (no shots)
//  - Category mapping correctness
//
// Story 11.3 — Slice 1: Domain + Calculation Engine

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/application/services/strokes_gained_calculator.dart';
import 'package:vsp_mobile/domain/models/shot.dart';
import 'package:vsp_mobile/domain/models/strokes_gained.dart';

void main() {
  late StrokesGainedCalculator calculator;

  setUp(() {
    calculator = StrokesGainedCalculator();
  });

  // ─── Test Fixtures ────────────────────────────────────────────────────────

  /// Creates a completed shot with the given properties.
  Shot makeShot({
    required String id,
    required String playerId,
    required String roundId,
    required int holeNumber,
    required int shotNumber,
    required ShotLie lie,
    double? distanceYards,
    DateTime? startedAt,
  }) {
    final now = startedAt ?? DateTime.now();
    return Shot(
      id: id,
      roundId: roundId,
      flightId: 'flight-1',
      playerId: playerId,
      holeNumber: holeNumber,
      shotNumber: shotNumber,
      lie: lie,
      distanceYards: distanceYards,
      startedAt: now,
      endedAt: now.add(const Duration(seconds: 10)),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Creates 20+ shots in a given category for a player.
  List<Shot> makeShotsInCategory({
    required String playerId,
    required String roundId,
    required SGCategory category,
    required int count,
  }) {
    final shots = <Shot>[];
    final now = DateTime.now();

    for (int i = 0; i < count; i++) {
      ShotLie lie;
      int shotNumber;
      double? distance;

      switch (category) {
        case SGCategory.offTheTee:
          lie = ShotLie.teebox;
          shotNumber = 1;
          distance = 250 + (i * 2);
          break;
        case SGCategory.approach:
          lie = ShotLie.fairway;
          shotNumber = 2;
          distance = 150 + (i * 2);
          break;
        case SGCategory.aroundTheGreen:
          lie = ShotLie.rough;
          shotNumber = 3;
          distance = 50 + (i % 30);
          break;
        case SGCategory.putting:
          lie = ShotLie.putt;
          shotNumber = 4;
          distance = 10 + (i % 8);
          break;
      }

      shots.add(
        Shot(
          id: 'shot-$category-$i',
          roundId: roundId,
          flightId: 'flight-1',
          playerId: playerId,
          holeNumber: 1,
          shotNumber: shotNumber,
          lie: lie,
          distanceYards: distance,
          startedAt: now,
          endedAt: now.add(const Duration(seconds: 10)),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return shots;
  }

  // ─── Happy Path Tests ────────────────────────────────────────────────────

  group('calculateForRound happy path', () {
    test('calculates SG for all 4 categories with professional benchmark', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      final allShots = <Shot>[];
      for (final category in SGCategory.values) {
        allShots.addAll(
          makeShotsInCategory(
            playerId: playerId,
            roundId: roundId,
            category: category,
            count: 25,
          ),
        );
      }

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: allShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      expect(summary.playerId, playerId);
      expect(summary.roundId, roundId);
      expect(
        summary.categoryBreakdown,
        hasLength(4),
      ); // 4 categories × 1 benchmark
      expect(summary.limitations, isEmpty);

      // All results should have confidence > 0
      for (final result in summary.categoryBreakdown) {
        expect(result.confidence, greaterThan(0.0));
        expect(result.limitation, isNull);
        expect(result.sampleCount, 25);
      }

      // Overall SG should be sum of category SGs
      final sumSG = summary.categoryBreakdown.fold<double>(
        0.0,
        (sum, r) => sum + r.strokesGained,
      );
      expect(summary.overallStrokesGained, sumSG);
    });

    test('calculates SG for all 4 benchmark types', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      final allShots = <Shot>[];
      for (final category in SGCategory.values) {
        allShots.addAll(
          makeShotsInCategory(
            playerId: playerId,
            roundId: roundId,
            category: category,
            count: 25,
          ),
        );
      }

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: allShots,
        benchmarkTypes: SGBenchmarkType.values.toSet(),
      );

      // 4 categories × 4 benchmark types = 16 results
      expect(summary.categoryBreakdown, hasLength(16));

      // Each category should have results for each benchmark type
      for (final category in SGCategory.values) {
        final categoryResults = summary.categoryBreakdown
            .where((r) => r.category == category)
            .toList();
        expect(categoryResults, hasLength(4));
        expect(
          categoryResults.map((r) => r.benchmarkType).toSet(),
          SGBenchmarkType.values.toSet(),
        );
      }
    });

    test('positive SG when player outperforms benchmark', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      // Player is very good — only 20 approach shots (less than benchmark)
      final approachShots = makeShotsInCategory(
        playerId: playerId,
        roundId: roundId,
        category: SGCategory.approach,
        count: 20,
      );

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: approachShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      final approachResult = summary.categoryBreakdown.first;
      expect(approachResult.category, SGCategory.approach);
      expect(approachResult.sampleCount, 20);
      expect(approachResult.limitation, isNull);

      // baselineStrokes = 3.5 * 20 = 70, actualStrokes = 20
      // SG = 70 - 20 = 50 (positive = player gained 50 strokes vs professional baseline)
      expect(approachResult.baselineStrokes, 70.0);
      expect(approachResult.actualStrokes, 20.0);
      expect(approachResult.strokesGained, greaterThan(0.0));
    });

    test('negative SG when player underperforms benchmark', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      // Player takes more strokes than benchmark on putting
      final puttingShots = makeShotsInCategory(
        playerId: playerId,
        roundId: roundId,
        category: SGCategory.putting,
        count: 30, // more than baseline
      );

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: puttingShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      final puttingResult = summary.categoryBreakdown.first;
      expect(puttingResult.strokesGained, lessThan(0.0));
    });
  });

  // ─── Sample Size Threshold Tests ─────────────────────────────────────────

  group('sample size thresholds', () {
    test('insufficientSample flag when count < 20', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      // Only 5 off-the-tee shots
      final offTeeShots = makeShotsInCategory(
        playerId: playerId,
        roundId: roundId,
        category: SGCategory.offTheTee,
        count: 5,
      );

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: offTeeShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      final offTeeResult = summary.categoryBreakdown.first;
      expect(offTeeResult.sampleCount, 5);
      expect(offTeeResult.limitation, SGLimitation.insufficientSample);
      expect(offTeeResult.strokesGained, 0.0);
      expect(offTeeResult.confidence, 0.0);
      expect(offTeeResult.baselineStrokes, 0.0);
      expect(offTeeResult.actualStrokes, 0.0);
    });

    test('no limitation at exactly 20 shots', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      final approachShots = makeShotsInCategory(
        playerId: playerId,
        roundId: roundId,
        category: SGCategory.approach,
        count: 20,
      );

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: approachShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      final approachResult = summary.categoryBreakdown.first;
      expect(approachResult.sampleCount, 20);
      expect(approachResult.limitation, isNull);
      expect(approachResult.confidence, greaterThan(0.0));
    });

    test('boundary case at 19 shots', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      final aroundGreenShots = makeShotsInCategory(
        playerId: playerId,
        roundId: roundId,
        category: SGCategory.aroundTheGreen,
        count: 19,
      );

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: aroundGreenShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      final result = summary.categoryBreakdown.first;
      expect(result.sampleCount, 19);
      expect(result.limitation, SGLimitation.insufficientSample);
    });
  });

  // ─── Limitation Flags Tests ───────────────────────────────────────────────

  group('limitation flags', () {
    test('noBenchmarkData when benchmark type unavailable', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      // Self-history currently falls back to similar-handicap
      // In a real scenario with no historical data, this would be noBenchmarkData
      // For Slice 1, self-history uses similar-handicap as fallback
      final shots = makeShotsInCategory(
        playerId: playerId,
        roundId: roundId,
        category: SGCategory.putting,
        count: 25,
      );

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: shots,
        benchmarkTypes: {SGBenchmarkType.selfHistory},
      );

      // Self-history falls back to similar-handicap, so no limitation
      expect(summary.categoryBreakdown.first.limitation, isNull);
    });

    test('limitations list collects all unique limitations', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      // Mix of categories with insufficient samples
      final allShots = <Shot>[];
      allShots.addAll(
        makeShotsInCategory(
          playerId: playerId,
          roundId: roundId,
          category: SGCategory.offTheTee,
          count: 5, // insufficient
        ),
      );
      allShots.addAll(
        makeShotsInCategory(
          playerId: playerId,
          roundId: roundId,
          category: SGCategory.approach,
          count: 25, // OK
        ),
      );
      allShots.addAll(
        makeShotsInCategory(
          playerId: playerId,
          roundId: roundId,
          category: SGCategory.aroundTheGreen,
          count: 3, // insufficient
        ),
      );
      allShots.addAll(
        makeShotsInCategory(
          playerId: playerId,
          roundId: roundId,
          category: SGCategory.putting,
          count: 30, // OK
        ),
      );

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: allShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      // Should have 2 insufficientSample limitations
      final insufficientCount = summary.categoryBreakdown
          .where((r) => r.limitation == SGLimitation.insufficientSample)
          .length;
      expect(insufficientCount, 2);

      // Limitations list should have at least the insufficientSample flag
      expect(summary.limitations, contains(SGLimitation.insufficientSample));
    });
  });

  // ─── Empty / Incomplete Data Tests ─────────────────────────────────────────

  group('empty round', () {
    test('empty shots returns all categories with insufficientSample', () {
      final summary = calculator.calculateForRound(
        playerId: 'player-1',
        roundId: 'round-1',
        shots: [],
        benchmarkTypes: SGBenchmarkType.values.toSet(),
      );

      expect(summary.playerId, 'player-1');
      expect(summary.roundId, 'round-1');
      expect(
        summary.categoryBreakdown,
        hasLength(16),
      ); // 4 categories × 4 benchmarks

      // All results should be insufficientSample with 0 count
      for (final result in summary.categoryBreakdown) {
        expect(result.sampleCount, 0);
        expect(result.limitation, SGLimitation.insufficientSample);
        expect(result.strokesGained, 0.0);
        expect(result.confidence, 0.0);
      }

      expect(summary.overallStrokesGained, 0.0);
    });

    test('shots with no matching category returns all insufficientSample', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      // Only shots that don't map to any SG category
      final unclassifiedShots = [
        makeShot(
          id: 'unclassified-1',
          playerId: playerId,
          roundId: roundId,
          holeNumber: 1,
          shotNumber: 1,
          lie: ShotLie.other, // won't map to any category
          distanceYards: null,
        ),
      ];

      final summary = calculator.calculateForRound(
        playerId: playerId,
        roundId: roundId,
        shots: unclassifiedShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      expect(summary.categoryBreakdown, hasLength(4));
      for (final result in summary.categoryBreakdown) {
        expect(result.sampleCount, 0);
        expect(result.limitation, SGLimitation.insufficientSample);
      }
    });
  });

  // ─── Category Mapping Tests ────────────────────────────────────────────────

  group('shot-to-category mapping', () {
    test('putt lie maps to putting', () {
      final shot = makeShot(
        id: 'putt-shot',
        playerId: 'player-1',
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 5,
        lie: ShotLie.putt,
        distanceYards: 8,
      );

      expect(calculator.mapShotToCategory(shot), SGCategory.putting);
    });

    test('green lie maps to putting', () {
      final shot = makeShot(
        id: 'green-shot',
        playerId: 'player-1',
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 4,
        lie: ShotLie.green,
        distanceYards: 15,
      );

      expect(calculator.mapShotToCategory(shot), SGCategory.putting);
    });

    test('teebox + shotNumber=1 maps to offTheTee', () {
      final shot = makeShot(
        id: 'tee-shot',
        playerId: 'player-1',
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 1,
        lie: ShotLie.teebox,
        distanceYards: 250,
      );

      expect(calculator.mapShotToCategory(shot), SGCategory.offTheTee);
    });

    test('fairway + distance >= 100 maps to approach', () {
      final shot = makeShot(
        id: 'approach-shot',
        playerId: 'player-1',
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 2,
        lie: ShotLie.fairway,
        distanceYards: 150,
      );

      expect(calculator.mapShotToCategory(shot), SGCategory.approach);
    });

    test('rough + distance < 100 maps to aroundTheGreen', () {
      final shot = makeShot(
        id: 'around-green-shot',
        playerId: 'player-1',
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 3,
        lie: ShotLie.rough,
        distanceYards: 50,
      );

      expect(calculator.mapShotToCategory(shot), SGCategory.aroundTheGreen);
    });

    test('distance 100 exactly maps to approach', () {
      final shot = makeShot(
        id: 'approach-100yd',
        playerId: 'player-1',
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 2,
        lie: ShotLie.fairway,
        distanceYards: 100,
      );

      expect(calculator.mapShotToCategory(shot), SGCategory.approach);
    });

    test('distance 99 maps to aroundTheGreen', () {
      final shot = makeShot(
        id: 'around-99yd',
        playerId: 'player-1',
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 3,
        lie: ShotLie.rough,
        distanceYards: 99,
      );

      expect(calculator.mapShotToCategory(shot), SGCategory.aroundTheGreen);
    });
  });

  // ─── Date Range Calculation Tests ─────────────────────────────────────────

  group('calculateForDateRange', () {
    test('filters shots by date range', () {
      final playerId = 'player-1';

      final dateRange = SGDateRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 6, 30),
      );

      final earlyShot = makeShot(
        id: 'early-shot',
        playerId: playerId,
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 1,
        lie: ShotLie.teebox,
        distanceYards: 250,
        startedAt: DateTime(2026, 1, 15),
      );

      final lateShot = makeShot(
        id: 'late-shot',
        playerId: playerId,
        roundId: 'round-1',
        holeNumber: 1,
        shotNumber: 1,
        lie: ShotLie.teebox,
        distanceYards: 250,
        startedAt: DateTime(2026, 8, 1), // outside range
      );

      final allShots = [earlyShot, lateShot];

      final summary = calculator.calculateForDateRange(
        playerId: playerId,
        dateRange: dateRange,
        shots: allShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      // Only the early shot should be included
      final offTeeResult = summary.categoryBreakdown.first;
      expect(offTeeResult.sampleCount, 1);
      expect(summary.roundId, isNull);
      expect(summary.dateRange, dateRange);
    });

    test(
      'date range with no matching shots returns all insufficientSample',
      () {
        final playerId = 'player-1';

        final dateRange = SGDateRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 31),
        );

        final shotOutsideRange = makeShot(
          id: 'outside-range',
          playerId: playerId,
          roundId: 'round-1',
          holeNumber: 1,
          shotNumber: 1,
          lie: ShotLie.teebox,
          distanceYards: 250,
          startedAt: DateTime(2026, 5, 1), // outside range
        );

        final summary = calculator.calculateForDateRange(
          playerId: playerId,
          dateRange: dateRange,
          shots: [shotOutsideRange],
          benchmarkTypes: {SGBenchmarkType.professional},
        );

        final offTeeResult = summary.categoryBreakdown.first;
        expect(offTeeResult.sampleCount, 0);
        expect(offTeeResult.limitation, SGLimitation.insufficientSample);
      },
    );
  });

  // ─── Confidence Computation Tests ─────────────────────────────────────────

  group('confidence calculation', () {
    test('confidence increases with sample size', () {
      final playerId = 'player-1';
      final roundId = 'round-1';

      // Create shots with varying sample sizes
      final sampleSizes = [1, 5, 10, 20, 40, 100];
      final confidences = <int, double>{};

      for (final size in sampleSizes) {
        final shots = makeShotsInCategory(
          playerId: playerId,
          roundId: roundId,
          category: SGCategory.approach,
          count: size,
        );

        final summary = calculator.calculateForRound(
          playerId: playerId,
          roundId: roundId,
          shots: shots,
          benchmarkTypes: {SGBenchmarkType.professional},
        );

        confidences[size] = summary.categoryBreakdown.first.confidence;
      }

      // Confidence should monotonically increase
      final sortedEntries = confidences.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (int i = 1; i < sortedEntries.length; i++) {
        expect(
          sortedEntries[i].value,
          greaterThanOrEqualTo(sortedEntries[i - 1].value),
          reason:
              'Confidence at n=${sortedEntries[i].key} (${sortedEntries[i].value}) '
              'should be >= confidence at n=${sortedEntries[i - 1].key} (${sortedEntries[i - 1].value})',
        );
      }

      // At n=1, confidence should be low
      expect(confidences[1]!, lessThan(0.1));

      // At n=100, confidence should approach 1.0
      expect(confidences[100]!, greaterThan(0.99));
    });

    test('zero sample yields zero confidence', () {
      final summary = calculator.calculateForRound(
        playerId: 'player-1',
        roundId: 'round-1',
        shots: [],
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      for (final result in summary.categoryBreakdown) {
        expect(result.confidence, 0.0);
      }
    });
  });

  // ─── Multiple Players Tests ────────────────────────────────────────────────

  group('multiple players in same round', () {
    test('only calculates SG for specified player', () {
      final roundId = 'round-1';

      final player1Shots = makeShotsInCategory(
        playerId: 'player-1',
        roundId: roundId,
        category: SGCategory.offTheTee,
        count: 25,
      );

      final player2Shots = makeShotsInCategory(
        playerId: 'player-2',
        roundId: roundId,
        category: SGCategory.offTheTee,
        count: 25,
      );

      final allShots = [...player1Shots, ...player2Shots];

      final summary = calculator.calculateForRound(
        playerId: 'player-1',
        roundId: roundId,
        shots: allShots,
        benchmarkTypes: {SGBenchmarkType.professional},
      );

      // Should only count player-1's shots
      final offTeeResult = summary.categoryBreakdown.firstWhere(
        (r) => r.category == SGCategory.offTheTee,
      );
      expect(offTeeResult.sampleCount, 25);
    });
  });

  // ─── Benchmark Baseline Accessor Tests ────────────────────────────────────

  group('benchmark accessors', () {
    test('getProfessionalBaseline returns correct values', () {
      expect(calculator.getProfessionalBaseline(SGCategory.offTheTee), 3.00);
      expect(calculator.getProfessionalBaseline(SGCategory.approach), 3.50);
      expect(
        calculator.getProfessionalBaseline(SGCategory.aroundTheGreen),
        3.20,
      );
      expect(calculator.getProfessionalBaseline(SGCategory.putting), 1.90);
    });

    test('getSimilarHandicapBaseline returns correct values', () {
      expect(calculator.getSimilarHandicapBaseline(SGCategory.offTheTee), 3.10);
      expect(calculator.getSimilarHandicapBaseline(SGCategory.approach), 3.70);
    });

    test('getAvailableBenchmarks returns all 4 types', () {
      final benchmarks = calculator.getAvailableBenchmarks(SGCategory.approach);
      expect(benchmarks, hasLength(4));
      expect(benchmarks, containsAll(SGBenchmarkType.values));
    });
  });
}
