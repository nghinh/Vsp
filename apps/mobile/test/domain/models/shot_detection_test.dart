// ShotDetection unit tests — VSP Mobile App
//
// Tests:
// - ShotDetectionSignalType enum values and properties
// - ShotConfidenceLevel.fromScore thresholds
// - ShotConfidenceLevel display labels and score boundaries
// - ShotFilterType enum values and properties
// - ShotDetectionSuggestionStatus fromString
// - ShotDetectionSignal construction and serialization
// - ShotDetectionSignals bundle operations
// - ShotDetectionSuggestion construction, status transitions, computed properties
// - ShotDetectionResult sorted suggestions and filter tracking
// - ShotDetectionConfig presets and threshold mapping
//
// Story 10.4 — Slice 1: Domain Models

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/shot_detection.dart';

void main() {
  // ─── ShotDetectionSignalType ──────────────────────────────────────────────

  group('ShotDetectionSignalType', () {
    test('has exactly 5 values matching AC1', () {
      expect(ShotDetectionSignalType.values, hasLength(5));
    });

    test('contains gps', () {
      expect(
        ShotDetectionSignalType.values,
        contains(ShotDetectionSignalType.gps),
      );
    });

    test('contains accelerometer', () {
      expect(
        ShotDetectionSignalType.values,
        contains(ShotDetectionSignalType.accelerometer),
      );
    });

    test('contains gyroscope', () {
      expect(
        ShotDetectionSignalType.values,
        contains(ShotDetectionSignalType.gyroscope),
      );
    });

    test('contains time', () {
      expect(
        ShotDetectionSignalType.values,
        contains(ShotDetectionSignalType.time),
      );
    });

    test('contains holeContext', () {
      expect(
        ShotDetectionSignalType.values,
        contains(ShotDetectionSignalType.holeContext),
      );
    });

    test('displayLabel returns human-readable labels', () {
      expect(ShotDetectionSignalType.gps.displayLabel, 'GPS Movement');
      expect(
        ShotDetectionSignalType.accelerometer.displayLabel,
        'Accelerometer',
      );
      expect(ShotDetectionSignalType.gyroscope.displayLabel, 'Gyroscope');
      expect(ShotDetectionSignalType.time.displayLabel, 'Time Interval');
      expect(ShotDetectionSignalType.holeContext.displayLabel, 'Hole Context');
    });

    test('defaultWeight returns correct weights per slice plan', () {
      expect(ShotDetectionSignalType.gps.defaultWeight, 0.30);
      expect(ShotDetectionSignalType.accelerometer.defaultWeight, 0.125);
      expect(ShotDetectionSignalType.gyroscope.defaultWeight, 0.125);
      expect(ShotDetectionSignalType.time.defaultWeight, 0.15);
      expect(ShotDetectionSignalType.holeContext.defaultWeight, 0.20);
    });

    test('signal weights leave 0.10 for GPS accuracy', () {
      final total = ShotDetectionSignalType.values.fold<double>(
        0.0,
        (sum, type) => sum + type.defaultWeight,
      );
      expect(total, closeTo(0.90, 1e-12));
    });
  });

  // ─── ShotConfidenceLevel ──────────────────────────────────────────────────

  group('ShotConfidenceLevel', () {
    test('has exactly 4 values matching AC2', () {
      expect(ShotConfidenceLevel.values, hasLength(4));
    });

    test('contains automatic, confirm, reviewLater, discard', () {
      expect(
        ShotConfidenceLevel.values,
        contains(ShotConfidenceLevel.automatic),
      );
      expect(ShotConfidenceLevel.values, contains(ShotConfidenceLevel.confirm));
      expect(
        ShotConfidenceLevel.values,
        contains(ShotConfidenceLevel.reviewLater),
      );
      expect(ShotConfidenceLevel.values, contains(ShotConfidenceLevel.discard));
    });

    group('fromScore', () {
      test('returns automatic for score >= 0.75', () {
        expect(
          ShotConfidenceLevel.fromScore(0.75),
          ShotConfidenceLevel.automatic,
        );
        expect(
          ShotConfidenceLevel.fromScore(0.80),
          ShotConfidenceLevel.automatic,
        );
        expect(
          ShotConfidenceLevel.fromScore(0.90),
          ShotConfidenceLevel.automatic,
        );
        expect(
          ShotConfidenceLevel.fromScore(1.0),
          ShotConfidenceLevel.automatic,
        );
      });

      test('returns confirm for score 0.5-0.74', () {
        expect(
          ShotConfidenceLevel.fromScore(0.50),
          ShotConfidenceLevel.confirm,
        );
        expect(
          ShotConfidenceLevel.fromScore(0.60),
          ShotConfidenceLevel.confirm,
        );
        expect(
          ShotConfidenceLevel.fromScore(0.74),
          ShotConfidenceLevel.confirm,
        );
      });

      test('returns reviewLater for score 0.2-0.49', () {
        expect(
          ShotConfidenceLevel.fromScore(0.2),
          ShotConfidenceLevel.reviewLater,
        );
        expect(
          ShotConfidenceLevel.fromScore(0.30),
          ShotConfidenceLevel.reviewLater,
        );
        expect(
          ShotConfidenceLevel.fromScore(0.49),
          ShotConfidenceLevel.reviewLater,
        );
      });

      test('returns discard for score < 0.2', () {
        expect(ShotConfidenceLevel.fromScore(0.0), ShotConfidenceLevel.discard);
        expect(ShotConfidenceLevel.fromScore(0.1), ShotConfidenceLevel.discard);
        expect(
          ShotConfidenceLevel.fromScore(0.19),
          ShotConfidenceLevel.discard,
        );
      });

      test('boundary at 0.75 goes to automatic not confirm', () {
        // 0.75 is the exact boundary
        expect(
          ShotConfidenceLevel.fromScore(0.7499),
          ShotConfidenceLevel.confirm,
        );
        expect(
          ShotConfidenceLevel.fromScore(0.75),
          ShotConfidenceLevel.automatic,
        );
      });

      test('boundary at 0.5 goes to confirm not reviewLater', () {
        expect(
          ShotConfidenceLevel.fromScore(0.4999),
          ShotConfidenceLevel.reviewLater,
        );
        expect(ShotConfidenceLevel.fromScore(0.5), ShotConfidenceLevel.confirm);
      });

      test('boundary at 0.2 goes to reviewLater not discard', () {
        expect(
          ShotConfidenceLevel.fromScore(0.1999),
          ShotConfidenceLevel.discard,
        );
        expect(
          ShotConfidenceLevel.fromScore(0.2),
          ShotConfidenceLevel.reviewLater,
        );
      });
    });

    group('displayLabel', () {
      test('returns correct labels', () {
        expect(ShotConfidenceLevel.automatic.displayLabel, 'Auto-Accept');
        expect(ShotConfidenceLevel.confirm.displayLabel, 'Confirm');
        expect(ShotConfidenceLevel.reviewLater.displayLabel, 'Review Later');
        expect(ShotConfidenceLevel.discard.displayLabel, 'Discard');
      });
    });

    group('score boundaries', () {
      test('minScore returns correct minimums', () {
        expect(ShotConfidenceLevel.automatic.minScore, 0.75);
        expect(ShotConfidenceLevel.confirm.minScore, 0.50);
        expect(ShotConfidenceLevel.reviewLater.minScore, 0.20);
        expect(ShotConfidenceLevel.discard.minScore, 0.0);
      });

      test('maxScore returns correct maximums', () {
        expect(ShotConfidenceLevel.automatic.maxScore, 1.0);
        expect(ShotConfidenceLevel.confirm.maxScore, 0.75);
        expect(ShotConfidenceLevel.reviewLater.maxScore, 0.5);
        expect(ShotConfidenceLevel.discard.maxScore, 0.2);
      });
    });
  });

  // ─── ShotFilterType ───────────────────────────────────────────────────────

  group('ShotFilterType', () {
    test('has exactly 6 values matching AC3', () {
      expect(ShotFilterType.values, hasLength(6));
    });

    test('contains all required filter types', () {
      expect(ShotFilterType.values, contains(ShotFilterType.practiceSwing));
      expect(ShotFilterType.values, contains(ShotFilterType.cartMovement));
      expect(ShotFilterType.values, contains(ShotFilterType.nearbyGolfer));
      expect(ShotFilterType.values, contains(ShotFilterType.shortShot));
      expect(ShotFilterType.values, contains(ShotFilterType.penalty));
      expect(ShotFilterType.values, contains(ShotFilterType.mulligan));
    });

    test('displayLabel returns human-readable labels', () {
      expect(ShotFilterType.practiceSwing.displayLabel, 'Practice Swing');
      expect(ShotFilterType.cartMovement.displayLabel, 'Cart Movement');
      expect(ShotFilterType.nearbyGolfer.displayLabel, 'Nearby Golfer');
      expect(ShotFilterType.shortShot.displayLabel, 'Short Shot');
      expect(ShotFilterType.penalty.displayLabel, 'Penalty');
      expect(ShotFilterType.mulligan.displayLabel, 'Mulligan');
    });

    test('exclusionReason returns human-readable reasons', () {
      expect(
        ShotFilterType.practiceSwing.exclusionReason,
        contains('practice swing'),
      );
      expect(
        ShotFilterType.cartMovement.exclusionReason,
        contains('cart movement'),
      );
      expect(
        ShotFilterType.nearbyGolfer.exclusionReason,
        contains('nearby golfer'),
      );
      expect(ShotFilterType.shortShot.exclusionReason, contains('short putt'));
      expect(ShotFilterType.penalty.exclusionReason, contains('penalty'));
      expect(ShotFilterType.mulligan.exclusionReason, contains('mulligan'));
    });
  });

  // ─── ShotDetectionSuggestionStatus ───────────────────────────────────────

  group('ShotDetectionSuggestionStatus', () {
    test('has expected values', () {
      expect(
        ShotDetectionSuggestionStatus.values,
        contains(ShotDetectionSuggestionStatus.pending),
      );
      expect(
        ShotDetectionSuggestionStatus.values,
        contains(ShotDetectionSuggestionStatus.confirmed),
      );
      expect(
        ShotDetectionSuggestionStatus.values,
        contains(ShotDetectionSuggestionStatus.rejected),
      );
      expect(
        ShotDetectionSuggestionStatus.values,
        contains(ShotDetectionSuggestionStatus.discarded),
      );
    });

    test('fromString defaults to pending for null', () {
      expect(
        ShotDetectionSuggestionStatus.fromString(null),
        ShotDetectionSuggestionStatus.pending,
      );
    });

    test('fromString handles lowercase', () {
      expect(
        ShotDetectionSuggestionStatus.fromString('pending'),
        ShotDetectionSuggestionStatus.pending,
      );
      expect(
        ShotDetectionSuggestionStatus.fromString('confirmed'),
        ShotDetectionSuggestionStatus.confirmed,
      );
    });
  });

  // ─── ShotDetectionSignal ──────────────────────────────────────────────────

  group('ShotDetectionSignal', () {
    test('creates with all fields', () {
      final capturedAt = DateTime.parse('2026-08-02T10:00:00Z');
      final signal = ShotDetectionSignal(
        type: ShotDetectionSignalType.gps,
        rawValue: 150.0,
        weight: 0.30,
        normalizedScore: 0.85,
        capturedAt: capturedAt,
      );

      expect(signal.type, ShotDetectionSignalType.gps);
      expect(signal.rawValue, 150.0);
      expect(signal.weight, 0.30);
      expect(signal.normalizedScore, 0.85);
      expect(signal.capturedAt, capturedAt);
    });

    test('withDefaultWeight uses type default weight', () {
      final capturedAt = DateTime.now();
      final signal = ShotDetectionSignal.withDefaultWeight(
        type: ShotDetectionSignalType.gps,
        rawValue: 150.0,
        normalizedScore: 0.85,
        capturedAt: capturedAt,
      );

      expect(signal.type, ShotDetectionSignalType.gps);
      expect(signal.weight, 0.30);
    });

    test('toJson / fromJson round-trip', () {
      final original = ShotDetectionSignal(
        type: ShotDetectionSignalType.holeContext,
        rawValue: 0.75,
        weight: 0.20,
        normalizedScore: 0.90,
        capturedAt: DateTime.parse('2026-08-02T10:00:00Z'),
      );

      final json = original.toJson();
      final restored = ShotDetectionSignal.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.rawValue, original.rawValue);
      expect(restored.weight, original.weight);
      expect(restored.normalizedScore, original.normalizedScore);
    });
  });

  // ─── ShotDetectionSignals ─────────────────────────────────────────────────

  group('ShotDetectionSignals', () {
    final now = DateTime.parse('2026-08-02T10:00:00Z');

    test('creates with all signals', () {
      final gps = ShotDetectionSignal(
        type: ShotDetectionSignalType.gps,
        rawValue: 100.0,
        weight: 0.30,
        normalizedScore: 0.8,
        capturedAt: now,
      );
      final accelerometer = ShotDetectionSignal(
        type: ShotDetectionSignalType.accelerometer,
        rawValue: 3.5,
        weight: 0.25,
        normalizedScore: 0.7,
        capturedAt: now,
      );
      final gyroscope = ShotDetectionSignal(
        type: ShotDetectionSignalType.gyroscope,
        rawValue: 2.1,
        weight: 0.25,
        normalizedScore: 0.75,
        capturedAt: now,
      );
      final time = ShotDetectionSignal(
        type: ShotDetectionSignalType.time,
        rawValue: 30.0,
        weight: 0.15,
        normalizedScore: 0.9,
        capturedAt: now,
      );
      final holeContext = ShotDetectionSignal(
        type: ShotDetectionSignalType.holeContext,
        rawValue: 0.85,
        weight: 0.20,
        normalizedScore: 0.85,
        capturedAt: now,
      );

      final signals = ShotDetectionSignals(
        gps: gps,
        accelerometer: accelerometer,
        gyroscope: gyroscope,
        time: time,
        holeContext: holeContext,
        capturedAt: now,
      );

      expect(signals.gps, gps);
      expect(signals.accelerometer, accelerometer);
      expect(signals.gyroscope, gyroscope);
      expect(signals.time, time);
      expect(signals.holeContext, holeContext);
      expect(signals.isComplete, true);
    });

    test('signalFor returns correct signal by type', () {
      final signals = ShotDetectionSignals(
        gps: ShotDetectionSignal(
          type: ShotDetectionSignalType.gps,
          rawValue: 100.0,
          weight: 0.30,
          normalizedScore: 0.8,
          capturedAt: now,
        ),
        capturedAt: now,
      );

      expect(signals.signalFor(ShotDetectionSignalType.gps), signals.gps);
      expect(signals.signalFor(ShotDetectionSignalType.accelerometer), isNull);
    });

    test('allSignals returns only non-null signals', () {
      final signals = ShotDetectionSignals(
        gps: ShotDetectionSignal(
          type: ShotDetectionSignalType.gps,
          rawValue: 100.0,
          weight: 0.30,
          normalizedScore: 0.8,
          capturedAt: now,
        ),
        capturedAt: now,
      );

      expect(signals.allSignals, hasLength(1));
      expect(signals.allSignals.first.type, ShotDetectionSignalType.gps);
    });

    test('toJson / fromJson round-trip', () {
      final original = ShotDetectionSignals(
        gps: ShotDetectionSignal(
          type: ShotDetectionSignalType.gps,
          rawValue: 100.0,
          weight: 0.30,
          normalizedScore: 0.8,
          capturedAt: now,
        ),
        capturedAt: now,
        windowSeconds: 30,
      );

      final json = original.toJson();
      final restored = ShotDetectionSignals.fromJson(json);

      expect(restored.gps?.type, original.gps?.type);
      expect(restored.gps?.rawValue, original.gps?.rawValue);
      expect(restored.windowSeconds, original.windowSeconds);
    });
  });

  // ─── ShotDetectionSuggestion ──────────────────────────────────────────────

  group('ShotDetectionSuggestion', () {
    final now = DateTime.parse('2026-08-02T10:00:00Z');
    final signals = ShotDetectionSignals(
      gps: ShotDetectionSignal(
        type: ShotDetectionSignalType.gps,
        rawValue: 100.0,
        weight: 0.30,
        normalizedScore: 0.8,
        capturedAt: now,
      ),
      capturedAt: now,
    );

    test('creates with required fields', () {
      final suggestion = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'Strong GPS and movement signals',
        detectedAt: now,
      );

      expect(suggestion.id, 'sug-1');
      expect(suggestion.roundId, 'round-1');
      expect(suggestion.playerId, 'player-1');
      expect(suggestion.confidence, 0.85);
      expect(suggestion.level, ShotConfidenceLevel.automatic);
      expect(suggestion.status, ShotDetectionSuggestionStatus.pending);
    });

    test('isPending returns true for pending status', () {
      final suggestion = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'Test',
        detectedAt: now,
      );

      expect(suggestion.isPending, true);
      expect(suggestion.isResolved, false);
    });

    test('isResolved returns true for non-pending status', () {
      final suggestion = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'Test',
        detectedAt: now,
        status: ShotDetectionSuggestionStatus.confirmed,
        confirmedAt: now,
      );

      expect(suggestion.isPending, false);
      expect(suggestion.isResolved, true);
    });

    test('shouldAutoAccept returns true for automatic level', () {
      final suggestion = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'Test',
        detectedAt: now,
      );

      expect(suggestion.shouldAutoAccept, true);
    });

    test('copyWith preserves unchanged fields', () {
      final original = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'Test',
        detectedAt: now,
      );

      final copied = original.copyWith(confidence: 0.90);

      expect(copied.id, original.id);
      expect(copied.confidence, 0.90);
      expect(copied.level, original.level);
    });

    test('toJson / fromJson round-trip', () {
      final original = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'Strong GPS and movement signals',
        detectedAt: now,
        status: ShotDetectionSuggestionStatus.confirmed,
        confirmedAt: now,
      );

      final json = original.toJson();
      final restored = ShotDetectionSuggestion.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.roundId, original.roundId);
      expect(restored.confidence, original.confidence);
      expect(restored.level, original.level);
      expect(restored.status, original.status);
      expect(restored.confirmedAt, isNotNull);
    });
  });

  // ─── ShotDetectionResult ──────────────────────────────────────────────────

  group('ShotDetectionResult', () {
    final now = DateTime.parse('2026-08-02T10:00:00Z');
    final signals = ShotDetectionSignals(
      gps: ShotDetectionSignal(
        type: ShotDetectionSignalType.gps,
        rawValue: 100.0,
        weight: 0.30,
        normalizedScore: 0.8,
        capturedAt: now,
      ),
      capturedAt: now,
    );

    test('suggestions are sorted by confidence', () {
      final suggestion1 = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.60,
        level: ShotConfidenceLevel.confirm,
        signals: signals,
        reason: 'Medium confidence',
        detectedAt: now,
      );
      final suggestion2 = ShotDetectionSuggestion(
        id: 'sug-2',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'High confidence',
        detectedAt: now,
      );
      final suggestion3 = ShotDetectionSuggestion(
        id: 'sug-3',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.30,
        level: ShotConfidenceLevel.reviewLater,
        signals: signals,
        reason: 'Low confidence',
        detectedAt: now,
      );

      final result = ShotDetectionResult(
        suggestions: [suggestion1, suggestion2, suggestion3],
        detectedAt: now,
      );

      expect(result.suggestions.first.confidence, 0.85);
      expect(result.suggestions[1].confidence, 0.60);
      expect(result.suggestions.last.confidence, 0.30);
    });

    test('hasAutomaticSuggestion returns true when present', () {
      final suggestion = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'Test',
        detectedAt: now,
      );

      final result = ShotDetectionResult(
        suggestions: [suggestion],
        detectedAt: now,
      );

      expect(result.hasAutomaticSuggestion, true);
      expect(result.hasConfirmSuggestion, false);
    });

    test('needsReview returns true when all suggestions low confidence', () {
      final suggestion = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.15,
        level: ShotConfidenceLevel.discard,
        signals: signals,
        reason: 'Low',
        detectedAt: now,
      );

      final result = ShotDetectionResult(
        suggestions: [suggestion],
        detectedAt: now,
      );

      expect(result.needsReview, true);
    });

    test('topSuggestion returns highest confidence', () {
      final suggestion1 = ShotDetectionSuggestion(
        id: 'sug-1',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.60,
        level: ShotConfidenceLevel.confirm,
        signals: signals,
        reason: 'Test',
        detectedAt: now,
      );
      final suggestion2 = ShotDetectionSuggestion(
        id: 'sug-2',
        roundId: 'round-1',
        playerId: 'player-1',
        confidence: 0.85,
        level: ShotConfidenceLevel.automatic,
        signals: signals,
        reason: 'Test',
        detectedAt: now,
      );

      final result = ShotDetectionResult(
        suggestions: [suggestion1, suggestion2],
        detectedAt: now,
      );

      expect(result.topSuggestion?.id, 'sug-2');
    });

    test('filtersApplied tracks applied filters', () {
      final result = ShotDetectionResult(
        suggestions: [],
        detectedAt: now,
        filtersApplied: [
          ShotFilterType.cartMovement,
          ShotFilterType.practiceSwing,
        ],
      );

      expect(result.filtersApplied, hasLength(2));
      expect(result.filtersApplied, contains(ShotFilterType.cartMovement));
    });
  });

  // ─── ShotDetectionConfig ──────────────────────────────────────────────────

  group('ShotDetectionConfig', () {
    test('defaultCasual has standard thresholds', () {
      final config = ShotDetectionConfig.defaultCasual;

      expect(config.thresholds.automaticMin, 0.75);
      expect(config.thresholds.confirmMin, 0.50);
      expect(config.thresholds.reviewLaterMin, 0.20);
      expect(config.thresholds.discardMax, 0.20);
    });

    test('defaultPractice is more lenient', () {
      final config = ShotDetectionConfig.defaultPractice;

      expect(config.thresholds.automaticMin, lessThan(0.75));
      expect(config.windows.detectionWindowSeconds, greaterThan(30));
    });

    test('defaultTournament is stricter', () {
      final config = ShotDetectionConfig.defaultTournament;

      expect(config.thresholds.automaticMin, greaterThan(0.75));
      expect(config.windows.detectionWindowSeconds, lessThan(30));
    });

    test('levelForScore uses configured thresholds', () {
      final config = ShotDetectionConfig(
        thresholds: const ShotDetectionThresholds(
          automaticMin: 0.80,
          confirmMin: 0.60,
          reviewLaterMin: 0.30,
          discardMax: 0.30,
        ),
      );

      expect(config.levelForScore(0.85), ShotConfidenceLevel.automatic);
      expect(config.levelForScore(0.70), ShotConfidenceLevel.confirm);
      expect(config.levelForScore(0.50), ShotConfidenceLevel.reviewLater);
      expect(config.levelForScore(0.20), ShotConfidenceLevel.discard);
    });

    test('toJson / fromJson round-trip', () {
      final original = ShotDetectionConfig.defaultTournament;

      final json = original.toJson();
      final restored = ShotDetectionConfig.fromJson(json);

      expect(
        restored.thresholds.automaticMin,
        original.thresholds.automaticMin,
      );
      expect(
        restored.windows.detectionWindowSeconds,
        original.windows.detectionWindowSeconds,
      );
      expect(
        restored.filters.maxCartPathSpeedMs,
        original.filters.maxCartPathSpeedMs,
      );
    });
  });

  // ─── ShotDetectionThresholds ───────────────────────────────────────────────

  group('ShotDetectionThresholds', () {
    test('default values match AC2 boundaries', () {
      const thresholds = ShotDetectionThresholds();

      expect(thresholds.automaticMin, 0.75);
      expect(thresholds.confirmMin, 0.50);
      expect(thresholds.reviewLaterMin, 0.20);
      expect(thresholds.discardMax, 0.20);
    });

    test('levelForScore returns correct levels', () {
      const thresholds = ShotDetectionThresholds();

      expect(thresholds.levelForScore(0.80), ShotConfidenceLevel.automatic);
      expect(thresholds.levelForScore(0.60), ShotConfidenceLevel.confirm);
      expect(thresholds.levelForScore(0.30), ShotConfidenceLevel.reviewLater);
      expect(thresholds.levelForScore(0.10), ShotConfidenceLevel.discard);
    });
  });

  // ─── ShotDetectionWindows ─────────────────────────────────────────────────

  group('ShotDetectionWindows', () {
    test('default values per slice plan', () {
      const windows = ShotDetectionWindows();

      expect(windows.detectionWindowSeconds, 30);
      expect(windows.minTimeBetweenShots, 15);
      expect(windows.maxShortShotDistanceMeters, 10.0);
    });

    test('toJson / fromJson round-trip', () {
      const original = ShotDetectionWindows(
        detectionWindowSeconds: 45,
        minTimeBetweenShots: 20,
        maxShortShotDistanceMeters: 15.0,
      );

      final json = original.toJson();
      final restored = ShotDetectionWindows.fromJson(json);

      expect(restored.detectionWindowSeconds, original.detectionWindowSeconds);
      expect(restored.minTimeBetweenShots, original.minTimeBetweenShots);
      expect(
        restored.maxShortShotDistanceMeters,
        original.maxShortShotDistanceMeters,
      );
    });
  });

  // ─── ShotDetectionFilters ─────────────────────────────────────────────────

  group('ShotDetectionFilters', () {
    test('default values per slice plan', () {
      const filters = ShotDetectionFilters();

      expect(filters.maxCartPathSpeedMs, 4.5);
      expect(filters.minPracticeSwingAccelerationDelta, 2.5);
      expect(filters.maxNearbyGolferDistanceMeters, 5.0);
      expect(filters.minPenaltyJumpMeters, 50.0);
    });

    test('toJson / fromJson round-trip', () {
      const original = ShotDetectionFilters(
        maxCartPathSpeedMs: 5.0,
        minPracticeSwingAccelerationDelta: 3.0,
        maxNearbyGolferDistanceMeters: 6.0,
        minPenaltyJumpMeters: 60.0,
      );

      final json = original.toJson();
      final restored = ShotDetectionFilters.fromJson(json);

      expect(restored.maxCartPathSpeedMs, original.maxCartPathSpeedMs);
      expect(
        restored.minPracticeSwingAccelerationDelta,
        original.minPracticeSwingAccelerationDelta,
      );
      expect(
        restored.maxNearbyGolferDistanceMeters,
        original.maxNearbyGolferDistanceMeters,
      );
      expect(restored.minPenaltyJumpMeters, original.minPenaltyJumpMeters);
    });
  });
}
