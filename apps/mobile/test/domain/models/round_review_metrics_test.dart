// Round Review Metrics Model Tests — VSP Mobile App
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/round_review_metrics.dart';
import 'package:vsp_mobile/domain/models/shot_metrics.dart';
import 'package:vsp_mobile/domain/models/incomplete_data_warning.dart';

void main() {
  group('RoundScoringSummary', () {
    test('girPercentage calculates correctly when girCount and girTotal are set', () {
      const summary = RoundScoringSummary(
        roundId: 'round-1',
        playerId: 'player-1',
        totalGrossScore: 80,
        girCount: 12,
        girTotal: 14,
      );
      expect(summary.girPercentage, closeTo(85.71, 0.01));
    });

    test('girPercentage returns null when girTotal is 0', () {
      const summary = RoundScoringSummary(
        roundId: 'round-1',
        playerId: 'player-1',
        totalGrossScore: 80,
        girCount: 0,
        girTotal: 0,
      );
      expect(summary.girPercentage, isNull);
    });

    test('firPercentage calculates correctly', () {
      const summary = RoundScoringSummary(
        roundId: 'round-1',
        playerId: 'player-1',
        totalGrossScore: 80,
        firCount: 10,
        firTotal: 14,
      );
      expect(summary.firPercentage, closeTo(71.43, 0.01));
    });

    test('upAndDownPercentage calculates correctly', () {
      const summary = RoundScoringSummary(
        roundId: 'round-1',
        playerId: 'player-1',
        totalGrossScore: 80,
        upAndDownCount: 3,
        upAndDownTotal: 5,
      );
      expect(summary.upAndDownPercentage, closeTo(60.0, 0.01));
    });

    test('upAndDownPercentage returns null when upAndDownTotal is 0', () {
      const summary = RoundScoringSummary(
        roundId: 'round-1',
        playerId: 'player-1',
        totalGrossScore: 80,
        upAndDownCount: 0,
        upAndDownTotal: 0,
      );
      expect(summary.upAndDownPercentage, isNull);
    });

    test('sandSavePercentage calculates correctly', () {
      const summary = RoundScoringSummary(
        roundId: 'round-1',
        playerId: 'player-1',
        totalGrossScore: 80,
        sandSaveCount: 2,
        sandSaveTotal: 3,
      );
      expect(summary.sandSavePercentage, closeTo(66.67, 0.01));
    });

    test('toJson and fromJson round-trip correctly', () {
      const original = RoundScoringSummary(
        roundId: 'round-1',
        playerId: 'player-1',
        totalGrossScore: 80,
        totalPutts: 32,
        totalPenalties: 2,
        girCount: 12,
        girTotal: 14,
        firCount: 10,
        firTotal: 14,
        scoreToPar: -2,
      );
      final json = original.toJson();
      final restored = RoundScoringSummary.fromJson(json);
      expect(restored.roundId, original.roundId);
      expect(restored.totalGrossScore, original.totalGrossScore);
      expect(restored.totalPutts, original.totalPutts);
      expect(restored.girCount, original.girCount);
      expect(restored.scoreToPar, original.scoreToPar);
    });
  });

  group('RoundReviewMetrics', () {
    test('hasInsufficientData returns true when warning is present', () {
      final metrics = RoundReviewMetrics(
        scoring: const RoundScoringSummary(
          roundId: 'round-1',
          playerId: 'player-1',
          totalGrossScore: 80,
        ),
        shotMetrics: const ShotMetrics(),
        incompleteDataWarning: IncompleteDataWarning.forTotalShots(
          requiredMinimum: 20,
          actualCount: 5,
          generatedAt: DateTime.now(),
        ),
        generatedAt: DateTime.now(),
      );
      expect(metrics.hasInsufficientData, true);
    });

    test('hasInsufficientData returns false when warning is null', () {
      final metrics = RoundReviewMetrics(
        scoring: const RoundScoringSummary(
          roundId: 'round-1',
          playerId: 'player-1',
          totalGrossScore: 80,
        ),
        shotMetrics: const ShotMetrics(),
        incompleteDataWarning: null,
        generatedAt: DateTime.now(),
      );
      expect(metrics.hasInsufficientData, false);
    });

    test('toJson and fromJson round-trip correctly', () {
      final original = RoundReviewMetrics(
        scoring: const RoundScoringSummary(
          roundId: 'round-1',
          playerId: 'player-1',
          totalGrossScore: 80,
        ),
        shotMetrics: const ShotMetrics(totalShots: 42),
        incompleteDataWarning: IncompleteDataWarning.forTotalShots(
          requiredMinimum: 20,
          actualCount: 5,
          generatedAt: DateTime.now(),
        ),
        generatedAt: DateTime(2025, 8, 1),
        courseName: 'Pine Valley',
        roundDate: DateTime(2025, 7, 30),
      );
      final json = original.toJson();
      final restored = RoundReviewMetrics.fromJson(json);
      expect(restored.scoring.roundId, original.scoring.roundId);
      expect(restored.shotMetrics.totalShots, original.shotMetrics.totalShots);
      expect(restored.courseName, original.courseName);
      expect(restored.incompleteDataWarning, isNotNull);
    });
  });
}
