// Strokes Gained Calculator — VSP Mobile App
//
// Pure calculation engine for Strokes Gained analytics.
// Per Story 11.3 Slice 1: Domain + Calculation Engine
//
// Maps shots → SG categories, applies benchmark baselines,
// and computes strokes gained vs. benchmarks.
// Slice 1: No I/O — takes shots as input for testability.

import 'dart:math' as math;

import '../../domain/models/shot.dart';
import '../../domain/models/strokes_gained.dart';

/// Minimum sample count for credible SG calculation.
const int kMinSampleForCredibility = 20;

/// Service that computes Strokes Gained analytics from shot data.
///
/// Slice 1 (this file): Pure calculation — no I/O.
/// Shots are passed directly to allow unit testing.
/// Slice 2 will add repository-backed calculation methods.
class StrokesGainedCalculator {
  // ─── Benchmark Baselines ─────────────────────────────────────────────────

  /// PGA Tour professional baselines by category (strokes per shot).
  /// These are representative values based on PGA Tour statistics.
  static const Map<SGCategory, double> _professionalBaselines = {
    SGCategory.offTheTee: 3.00, // average strokes to hole from tee on par-4/5
    SGCategory.approach: 3.50, // average strokes from 100+ yards
    SGCategory.aroundTheGreen:
        3.20, // average strokes inside 100 yards not on green
    SGCategory.putting: 1.90, // average putts per hole
  };

  /// Similar-handicap peer baselines (10-15 handicap range).
  /// Representative amateur baselines for comparison.
  static const Map<SGCategory, double> _similarHandicapBaselines = {
    SGCategory.offTheTee: 3.10,
    SGCategory.approach: 3.70,
    SGCategory.aroundTheGreen: 3.40,
    SGCategory.putting: 2.00,
  };

  /// Default target handicap baseline (strokes per shot).
  static const Map<SGCategory, double> _targetHandicapBaselines = {
    SGCategory.offTheTee: 3.05,
    SGCategory.approach: 3.60,
    SGCategory.aroundTheGreen: 3.30,
    SGCategory.putting: 1.95,
  };

  // ─── Public API ─────────────────────────────────────────────────────────

  /// Calculate Strokes Gained for a single round.
  ///
  /// Takes shots directly ( Slice 1 pattern for testability).
  /// In Slice 2, repository-backed overloads will be added.
  StrokesGainedSummary calculateForRound({
    required String playerId,
    required String roundId,
    required List<Shot> shots,
    required Set<SGBenchmarkType> benchmarkTypes,
    int? holePar,
  }) {
    final playerShots = _filterShotsForPlayer(shots, playerId);

    final categoryBreakdown = <StrokesGainedResult>[];

    for (final benchmarkType in benchmarkTypes) {
      for (final category in SGCategory.values) {
        final result = _calculateForCategory(
          category: category,
          benchmarkType: benchmarkType,
          shots: playerShots,
          holePar: holePar,
        );
        categoryBreakdown.add(result);
      }
    }

    final limitations = categoryBreakdown
        .where((r) => r.limitation != null)
        .map((r) => r.limitation!)
        .toSet()
        .toList();

    categoryBreakdown.sort((a, b) {
      final sampleOrder = b.sampleCount.compareTo(a.sampleCount);
      return sampleOrder != 0
          ? sampleOrder
          : a.category.index.compareTo(b.category.index);
    });

    final overallSG = categoryBreakdown.fold<double>(
      0.0,
      (sum, r) => sum + r.strokesGained,
    );

    return StrokesGainedSummary(
      playerId: playerId,
      roundId: roundId,
      dateRange: null,
      overallStrokesGained: overallSG,
      categoryBreakdown: categoryBreakdown,
      limitations: limitations,
      lastCalculatedAt: DateTime.now(),
    );
  }

  /// Calculate Strokes Gained for a date range.
  StrokesGainedSummary calculateForDateRange({
    required String playerId,
    required SGDateRange dateRange,
    required List<Shot> shots,
    required Set<SGBenchmarkType> benchmarkTypes,
    int? holePar,
  }) {
    final playerShots = _filterShotsForPlayer(
      shots,
      playerId,
    ).where((s) => dateRange.contains(s.startedAt)).toList();

    final categoryBreakdown = <StrokesGainedResult>[];

    for (final benchmarkType in benchmarkTypes) {
      for (final category in SGCategory.values) {
        final result = _calculateForCategory(
          category: category,
          benchmarkType: benchmarkType,
          shots: playerShots,
          holePar: holePar,
        );
        categoryBreakdown.add(result);
      }
    }

    final limitations = categoryBreakdown
        .where((r) => r.limitation != null)
        .map((r) => r.limitation!)
        .toSet()
        .toList();

    categoryBreakdown.sort((a, b) {
      final sampleOrder = b.sampleCount.compareTo(a.sampleCount);
      return sampleOrder != 0
          ? sampleOrder
          : a.category.index.compareTo(b.category.index);
    });

    final overallSG = categoryBreakdown.fold<double>(
      0.0,
      (sum, r) => sum + r.strokesGained,
    );

    return StrokesGainedSummary(
      playerId: playerId,
      roundId: null,
      dateRange: dateRange,
      overallStrokesGained: overallSG,
      categoryBreakdown: categoryBreakdown,
      limitations: limitations,
      lastCalculatedAt: DateTime.now(),
    );
  }

  // ─── Category Mapping ───────────────────────────────────────────────────

  /// Maps a shot to its SG category using shot data and hole par.
  ///
  /// Logic (per Slice 4):
  /// - Off-the-Tee: shotNumber==1 AND lie==teebox AND hole is Par-4 or Par-5
  ///   (Par-3 holes have no off-the-tee category)
  /// - Approach: distance >= 100 yards, not on green
  /// - Around-the-Green: 0 < distance < 100 yards, not on green, not a putt
  /// - Putting: any putt or lie on green
  ///
  /// The holePar parameter determines if this is a par-4/5 hole:
  /// - par >= 4 → tee shots count as off-the-tee
  /// - par == 3 → no off-the-tee category (Par-3 hole)
  SGCategory? mapShotToCategory(Shot shot, {int? holePar}) {
    final lie = shot.lie;
    final distance = shot.distanceYards ?? 0;
    final shotNumber = shot.shotNumber;

    // Putting: any putt or lie on green
    if (lie == ShotLie.putt || lie == ShotLie.green) {
      return SGCategory.putting;
    }

    // Off-the-Tee: first shot on par-4/5 hole from teebox
    // Par-3 holes (par < 4) do NOT have off-the-tee shots
    if (shotNumber == 1 &&
        lie == ShotLie.teebox &&
        (holePar == null || holePar >= 4)) {
      return SGCategory.offTheTee;
    }

    // Approach: 100+ yards, not on green
    if (distance >= 100) {
      return SGCategory.approach;
    }

    // Around-the-Green: inside 100 yards, not on green, not a putt
    if (distance > 0 && distance < 100) {
      return SGCategory.aroundTheGreen;
    }

    // Fallback: if no distance but it's a non-putting lie, treat as around green
    if (distance == 0 &&
        lie != null &&
        lie != ShotLie.other &&
        lie != ShotLie.putt &&
        lie != ShotLie.green) {
      return SGCategory.aroundTheGreen;
    }

    return null;
  }

  /// Maps a shot to SG category using a map of hole IDs to pars.
  /// Convenience method for when hole pars are available per-hole.
  SGCategory? mapShotToCategoryForHole(Shot shot, Map<String, int> holePars) {
    final holePar = holePars[shot.holeNumber.toString()];
    return mapShotToCategory(shot, holePar: holePar);
  }

  // ─── Private Helpers ───────────────────────────────────────────────────

  List<Shot> _filterShotsForPlayer(List<Shot> shots, String playerId) {
    return shots.where((s) => s.playerId == playerId && s.isEnded).toList();
  }

  StrokesGainedResult _calculateForCategory({
    required SGCategory category,
    required SGBenchmarkType benchmarkType,
    required List<Shot> shots,
    int? holePar,
  }) {
    // Filter shots belonging to this category
    final categoryShots = shots
        .where((s) => mapShotToCategory(s, holePar: holePar) == category)
        .toList();
    final sampleCount = categoryShots.length;

    // Insufficient sample — flag limitation
    if (sampleCount < kMinSampleForCredibility) {
      return StrokesGainedResult(
        category: category,
        benchmarkType: benchmarkType,
        strokesGained: 0.0,
        baselineStrokes: 0.0,
        actualStrokes: 0.0,
        sampleCount: sampleCount,
        limitation: SGLimitation.insufficientSample,
        confidence: 0.0,
      );
    }

    // Get baseline for this category + benchmark type
    final baseline = _getBaseline(category, benchmarkType);
    if (baseline == null) {
      return StrokesGainedResult(
        category: category,
        benchmarkType: benchmarkType,
        strokesGained: 0.0,
        baselineStrokes: 0.0,
        actualStrokes: 0.0,
        sampleCount: sampleCount,
        limitation: SGLimitation.noBenchmarkData,
        confidence: 0.0,
      );
    }

    // Calculate actual average strokes for this player's shots in category
    // For SG calculation, we use strokes to hole completion
    // Actual strokes = number of shots in this category
    // Baseline strokes = expected number based on benchmark
    // SG = baseline - actual (positive = player is better than benchmark)

    final actualStrokes = category == SGCategory.putting
        ? categoryShots.fold<double>(
            0.0,
            (total, shot) => total + shot.shotNumber,
          )
        : sampleCount.toDouble();
    final baselineStrokes = baseline * sampleCount;
    final strokesGained = baselineStrokes - actualStrokes;

    // Confidence based on sample size
    final confidence = _computeConfidence(sampleCount);

    return StrokesGainedResult(
      category: category,
      benchmarkType: benchmarkType,
      strokesGained: strokesGained,
      baselineStrokes: baselineStrokes,
      actualStrokes: actualStrokes,
      sampleCount: sampleCount,
      limitation: null,
      confidence: confidence,
    );
  }

  double? _getBaseline(SGCategory category, SGBenchmarkType benchmarkType) {
    switch (benchmarkType) {
      case SGBenchmarkType.professional:
        return _professionalBaselines[category];
      case SGBenchmarkType.similarHandicap:
        return _similarHandicapBaselines[category];
      case SGBenchmarkType.targetHandicap:
        return _targetHandicapBaselines[category];
      case SGBenchmarkType.selfHistory:
        // Self-history requires historical data (computed in Slice 2)
        // Return similar-handicap as fallback for now
        return _similarHandicapBaselines[category];
    }
  }

  /// Compute confidence score based on sample size.
  /// 0.0 = no confidence, 1.0 = full confidence.
  /// Uses asymptotic curve: 1 - e^(-n/20) where n = sample count.
  double _computeConfidence(int sampleCount) {
    if (sampleCount <= 0) return 0.0;
    return 1.0 - math.exp(-sampleCount / kMinSampleForCredibility);
  }

  // ─── Benchmark Data Accessors (for Slice 2) ─────────────────────────────

  /// Get professional benchmark for a category.
  /// Returns in-memory data; will be backed by database in Slice 2.
  double? getProfessionalBaseline(SGCategory category) {
    return _professionalBaselines[category];
  }

  /// Get similar-handicap benchmark for a category.
  double? getSimilarHandicapBaseline(SGCategory category) {
    return _similarHandicapBaselines[category];
  }

  /// Get all available benchmark types for a category.
  List<SGBenchmarkType> getAvailableBenchmarks(SGCategory category) {
    return SGBenchmarkType.values;
  }

  // ─── Slice 4: Score + Round Analytics Integration ──────────────────────

  /// Calculate Strokes Gained using hole-specific pars.
  ///
  /// This is the E2E integration method that:
  /// - Uses per-hole par values from course data
  /// - Maps shots to SG categories with proper par-3 detection
  /// - Integrates with Score entity for baseline comparison
  StrokesGainedSummary calculateForRoundWithHolePars({
    required String playerId,
    required String roundId,
    required List<Shot> shots,
    required Set<SGBenchmarkType> benchmarkTypes,
    required Map<String, int> holePars,
  }) {
    final playerShots = _filterShotsForPlayer(shots, playerId);

    final categoryBreakdown = <StrokesGainedResult>[];

    for (final benchmarkType in benchmarkTypes) {
      for (final category in SGCategory.values) {
        // Count shots for this category using per-hole par mapping
        final categoryShots = playerShots.where((s) {
          final sgCategory = mapShotToCategoryForHole(s, holePars);
          return sgCategory == category;
        }).toList();

        final result = _calculateResultForShots(
          category: category,
          benchmarkType: benchmarkType,
          shots: categoryShots,
        );
        categoryBreakdown.add(result);
      }
    }

    final limitations = categoryBreakdown
        .where((r) => r.limitation != null)
        .map((r) => r.limitation!)
        .toSet()
        .toList();

    categoryBreakdown.sort((a, b) {
      final sampleOrder = b.sampleCount.compareTo(a.sampleCount);
      return sampleOrder != 0
          ? sampleOrder
          : a.category.index.compareTo(b.category.index);
    });

    final overallSG = categoryBreakdown.fold<double>(
      0.0,
      (sum, r) => sum + r.strokesGained,
    );

    return StrokesGainedSummary(
      playerId: playerId,
      roundId: roundId,
      dateRange: null,
      overallStrokesGained: overallSG,
      categoryBreakdown: categoryBreakdown,
      limitations: limitations,
      lastCalculatedAt: DateTime.now(),
    );
  }

  /// Calculate expected score vs actual for a round.
  ///
  /// Uses hole pars to compute expected strokes and compares to Score entity.
  /// Returns map of holeNumber → (expected, actual, difference).
  Map<int, ScoreVsPar> calculateScoreVsPar({
    required String playerId,
    required Map<String, int> holePars,
    required Map<int, int> holeScores, // holeNumber → gross score
  }) {
    final result = <int, ScoreVsPar>{};

    for (final entry in holeScores.entries) {
      final holeNumber = entry.key;
      final actualScore = entry.value;
      final holeId = holeNumber.toString();
      final par =
          holePars[holeId] ?? holePars[holeNumber] ?? 72; // default to 72

      result[holeNumber] = ScoreVsPar(
        holeNumber: holeNumber,
        par: par,
        actualScore: actualScore,
        expectedScore: par,
        difference: actualScore - par,
      );
    }

    return result;
  }

  StrokesGainedResult _calculateResultForShots({
    required SGCategory category,
    required SGBenchmarkType benchmarkType,
    required List<Shot> shots,
  }) {
    final sampleCount = shots.length;

    // Insufficient sample — flag limitation
    if (sampleCount < kMinSampleForCredibility) {
      return StrokesGainedResult(
        category: category,
        benchmarkType: benchmarkType,
        strokesGained: 0.0,
        baselineStrokes: 0.0,
        actualStrokes: 0.0,
        sampleCount: sampleCount,
        limitation: SGLimitation.insufficientSample,
        confidence: 0.0,
      );
    }

    // Get baseline for this category + benchmark type
    final baseline = _getBaseline(category, benchmarkType);
    if (baseline == null) {
      return StrokesGainedResult(
        category: category,
        benchmarkType: benchmarkType,
        strokesGained: 0.0,
        baselineStrokes: 0.0,
        actualStrokes: 0.0,
        sampleCount: sampleCount,
        limitation: SGLimitation.noBenchmarkData,
        confidence: 0.0,
      );
    }

    final actualStrokes = sampleCount.toDouble();
    final baselineStrokes = baseline * sampleCount;
    final strokesGained = baselineStrokes - actualStrokes;
    final confidence = _computeConfidence(sampleCount);

    return StrokesGainedResult(
      category: category,
      benchmarkType: benchmarkType,
      strokesGained: strokesGained,
      baselineStrokes: baselineStrokes,
      actualStrokes: actualStrokes,
      sampleCount: sampleCount,
      limitation: null,
      confidence: confidence,
    );
  }
}

/// Result of score vs par comparison for a single hole.
class ScoreVsPar {
  final int holeNumber;
  final int par;
  final int actualScore;
  final int expectedScore;
  final int difference; // positive = over par, negative = under par

  const ScoreVsPar({
    required this.holeNumber,
    required this.par,
    required this.actualScore,
    required this.expectedScore,
    required this.difference,
  });

  bool get isBirdieOrBetter => difference <= -1;
  bool get isPar => difference == 0;
  bool get isBogey => difference == 1;
  bool get isDoubleBogeyOrWorse => difference >= 2;

  String get scoreNotation {
    if (difference <= -3) return 'Albatross';
    if (difference == -2) return 'Eagle';
    if (difference == -1) return 'Birdie';
    if (difference == 0) return 'Par';
    if (difference == 1) return 'Bogey';
    if (difference == 2) return 'Double Bogey';
    return '+${difference - 1} Over';
  }
}
