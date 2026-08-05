// Strokes Gained Domain Models — VSP Mobile App
//
// Strokes Gained analytics for golf performance measurement.
// Per Story 11.3 Slice 1: Domain + Calculation Engine
//
// Calculates shot-level performance vs. benchmark baselines across 4 categories:
// Off-the-Tee, Approach, Around-the-Green, Putting.

import 'package:equatable/equatable.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

/// Supported Strokes Gained categories.
enum SGCategory {
  /// Par-4/Par-5 tee shots (excluding putters).
  offTheTee,

  /// Shots from 100+ yards to green.
  approach,

  /// Shots inside 100 yards, not on green.
  aroundTheGreen,

  /// All putts.
  putting;

  static SGCategory? fromString(String? value) {
    if (value == null) return null;
    return SGCategory.values.firstWhere(
      (e) => e.name == value || _normalize(value) == e.name,
      orElse: () => SGCategory.offTheTee,
    );
  }

  static String _normalize(String value) {
    return value.replaceAll('-', '').replaceAll('_', '').toLowerCase();
  }

  String toApiValue() {
    switch (this) {
      case SGCategory.offTheTee:
        return 'off_the_tee';
      case SGCategory.approach:
        return 'approach';
      case SGCategory.aroundTheGreen:
        return 'around_the_green';
      case SGCategory.putting:
        return 'putting';
    }
  }

  /// Human-readable display label.
  String get displayName {
    switch (this) {
      case SGCategory.offTheTee:
        return 'Off the Tee';
      case SGCategory.approach:
        return 'Approach';
      case SGCategory.aroundTheGreen:
        return 'Around the Green';
      case SGCategory.putting:
        return 'Putting';
    }
  }
}

/// Benchmark reference type for Strokes Gained comparison.
enum SGBenchmarkType {
  /// Peer group benchmark (e.g., 10–15 handicap).
  similarHandicap,

  /// User's target/goal handicap.
  targetHandicap,

  /// Player's own historical average.
  selfHistory,

  /// Valid professional reference (PGA Tour baselines).
  professional;

  static SGBenchmarkType? fromString(String? value) {
    if (value == null) return null;
    return SGBenchmarkType.values.firstWhere(
      (e) => e.name == value || _normalize(value) == e.name,
      orElse: () => SGBenchmarkType.similarHandicap,
    );
  }

  static String _normalize(String value) {
    return value.replaceAll('-', '').replaceAll('_', '').toLowerCase();
  }

  String toApiValue() {
    switch (this) {
      case SGBenchmarkType.similarHandicap:
        return 'similar_handicap';
      case SGBenchmarkType.targetHandicap:
        return 'target_handicap';
      case SGBenchmarkType.selfHistory:
        return 'self_history';
      case SGBenchmarkType.professional:
        return 'professional';
    }
  }

  String get displayName {
    switch (this) {
      case SGBenchmarkType.similarHandicap:
        return 'Similar Handicap';
      case SGBenchmarkType.targetHandicap:
        return 'Target Handicap';
      case SGBenchmarkType.selfHistory:
        return 'Self History';
      case SGBenchmarkType.professional:
        return 'Professional';
    }
  }
}

/// Limitation flags when Strokes Gained cannot be reliably computed.
enum SGLimitation {
  /// Fewer than 20 shots in category — insufficient sample.
  insufficientSample,

  /// No club distance data for this shot type.
  noClubData,

  /// Benchmark reference unavailable.
  noBenchmarkData,

  /// Wind/condition variance too high.
  mixedConditions,

  /// Filter applied but too few tournament rounds.
  tournamentRoundsOnly;

  static SGLimitation? fromString(String? value) {
    if (value == null) return null;
    return SGLimitation.values.firstWhere(
      (e) => e.name == value || _normalize(value) == e.name,
      orElse: () => SGLimitation.insufficientSample,
    );
  }

  static String _normalize(String value) {
    return value.replaceAll('-', '').replaceAll('_', '').toLowerCase();
  }

  String toApiValue() {
    switch (this) {
      case SGLimitation.insufficientSample:
        return 'insufficient_sample';
      case SGLimitation.noClubData:
        return 'no_club_data';
      case SGLimitation.noBenchmarkData:
        return 'no_benchmark_data';
      case SGLimitation.mixedConditions:
        return 'mixed_conditions';
      case SGLimitation.tournamentRoundsOnly:
        return 'tournament_rounds_only';
    }
  }

  String get displayName {
    switch (this) {
      case SGLimitation.insufficientSample:
        return 'Insufficient Sample';
      case SGLimitation.noClubData:
        return 'No Club Data';
      case SGLimitation.noBenchmarkData:
        return 'No Benchmark Data';
      case SGLimitation.mixedConditions:
        return 'Mixed Conditions';
      case SGLimitation.tournamentRoundsOnly:
        return 'Tournament Rounds Only';
    }
  }
}

// ─── Value Objects ───────────────────────────────────────────────────────────

/// Date range for filtering Strokes Gained calculations.
class SGDateRange extends Equatable {
  final DateTime start;
  final DateTime end;

  const SGDateRange({required this.start, required this.end});

  bool contains(DateTime date) {
    return !date.isBefore(start) && !date.isAfter(end);
  }

  @override
  List<Object?> get props => [start, end];

  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };

  factory SGDateRange.fromJson(Map<String, dynamic> json) {
    return SGDateRange(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }
}

// ─── Domain Models ───────────────────────────────────────────────────────────

/// Strokes Gained result for a single category.
class StrokesGainedResult extends Equatable {
  final SGCategory category;
  final SGBenchmarkType benchmarkType;
  final double strokesGained; // negative = lost shots, positive = gained
  final double baselineStrokes; // expected strokes for benchmark
  final double actualStrokes; // actual strokes taken
  final int sampleCount; // shots in this category
  final SGLimitation? limitation; // null if robust, else reason
  final double confidence; // 0.0–1.0

  const StrokesGainedResult({
    required this.category,
    required this.benchmarkType,
    required this.strokesGained,
    required this.baselineStrokes,
    required this.actualStrokes,
    required this.sampleCount,
    this.limitation,
    required this.confidence,
  });

  /// True if this result has a limitation flag.
  bool get hasLimitation => limitation != null;

  /// True if sample size is too small for reliable SG calculation.
  bool get isSampleInsufficient => sampleCount < 20;

  StrokesGainedResult copyWith({
    SGCategory? category,
    SGBenchmarkType? benchmarkType,
    double? strokesGained,
    double? baselineStrokes,
    double? actualStrokes,
    int? sampleCount,
    SGLimitation? limitation,
    bool clearLimitation = false,
    double? confidence,
  }) {
    return StrokesGainedResult(
      category: category ?? this.category,
      benchmarkType: benchmarkType ?? this.benchmarkType,
      strokesGained: strokesGained ?? this.strokesGained,
      baselineStrokes: baselineStrokes ?? this.baselineStrokes,
      actualStrokes: actualStrokes ?? this.actualStrokes,
      sampleCount: sampleCount ?? this.sampleCount,
      limitation: clearLimitation ? null : (limitation ?? this.limitation),
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category.toApiValue(),
    'benchmarkType': benchmarkType.toApiValue(),
    'strokesGained': strokesGained,
    'baselineStrokes': baselineStrokes,
    'actualStrokes': actualStrokes,
    'sampleCount': sampleCount,
    'limitation': limitation?.toApiValue(),
    'confidence': confidence,
  };

  factory StrokesGainedResult.fromJson(Map<String, dynamic> json) {
    return StrokesGainedResult(
      category:
          SGCategory.fromString(json['category'] as String?) ??
          SGCategory.offTheTee,
      benchmarkType:
          SGBenchmarkType.fromString(json['benchmarkType'] as String?) ??
          SGBenchmarkType.similarHandicap,
      strokesGained: (json['strokesGained'] as num).toDouble(),
      baselineStrokes: (json['baselineStrokes'] as num).toDouble(),
      actualStrokes: (json['actualStrokes'] as num).toDouble(),
      sampleCount: (json['sampleCount'] as num).toInt(),
      limitation: SGLimitation.fromString(json['limitation'] as String?),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [
    category,
    benchmarkType,
    strokesGained,
    baselineStrokes,
    actualStrokes,
    sampleCount,
    limitation,
    confidence,
  ];
}

/// Strokes Gained summary for a player over a round or date range.
class StrokesGainedSummary extends Equatable {
  final String playerId;
  final String? roundId;
  final SGDateRange? dateRange;
  final double overallStrokesGained;
  final List<StrokesGainedResult> categoryBreakdown;
  final List<SGLimitation> limitations;
  final DateTime lastCalculatedAt;

  const StrokesGainedSummary({
    required this.playerId,
    this.roundId,
    this.dateRange,
    required this.overallStrokesGained,
    required this.categoryBreakdown,
    required this.limitations,
    required this.lastCalculatedAt,
  });

  StrokesGainedSummary copyWith({
    String? playerId,
    String? roundId,
    bool clearRoundId = false,
    SGDateRange? dateRange,
    bool clearDateRange = false,
    double? overallStrokesGained,
    List<StrokesGainedResult>? categoryBreakdown,
    List<SGLimitation>? limitations,
    DateTime? lastCalculatedAt,
  }) {
    return StrokesGainedSummary(
      playerId: playerId ?? this.playerId,
      roundId: clearRoundId ? null : (roundId ?? this.roundId),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      overallStrokesGained: overallStrokesGained ?? this.overallStrokesGained,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      limitations: limitations ?? this.limitations,
      lastCalculatedAt: lastCalculatedAt ?? this.lastCalculatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'roundId': roundId,
    'dateRange': dateRange?.toJson(),
    'overallStrokesGained': overallStrokesGained,
    'categoryBreakdown': categoryBreakdown.map((r) => r.toJson()).toList(),
    'limitations': limitations.map((l) => l.toApiValue()).toList(),
    'lastCalculatedAt': lastCalculatedAt.toIso8601String(),
  };

  factory StrokesGainedSummary.fromJson(Map<String, dynamic> json) {
    return StrokesGainedSummary(
      playerId: json['playerId'] as String,
      roundId: json['roundId'] as String?,
      dateRange: json['dateRange'] != null
          ? SGDateRange.fromJson(json['dateRange'] as Map<String, dynamic>)
          : null,
      overallStrokesGained: (json['overallStrokesGained'] as num).toDouble(),
      categoryBreakdown: (json['categoryBreakdown'] as List)
          .map((r) => StrokesGainedResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      limitations: (json['limitations'] as List)
          .map(
            (l) =>
                SGLimitation.fromString(l as String) ??
                SGLimitation.insufficientSample,
          )
          .toList(),
      lastCalculatedAt: DateTime.parse(json['lastCalculatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    playerId,
    roundId,
    dateRange,
    overallStrokesGained,
    categoryBreakdown,
    limitations,
    lastCalculatedAt,
  ];
}

// ─── Benchmark Data Models ────────────────────────────────────────────────────

/// Baseline strokes data for a specific SG category and benchmark type.
class SGBenchmarkData extends Equatable {
  final SGBenchmarkType type;
  final SGCategory category;
  final double
  baselineStrokesPerShot; // expected strokes per shot in this category
  final int? minSampleForCredibility; // minimum shots needed (default 20)

  const SGBenchmarkData({
    required this.type,
    required this.category,
    required this.baselineStrokesPerShot,
    this.minSampleForCredibility = 20,
  });

  @override
  List<Object?> get props => [
    type,
    category,
    baselineStrokesPerShot,
    minSampleForCredibility,
  ];
}

/// PGA Tour professional baseline strokes per shot by distance band.
class ProfessionalBenchmark extends Equatable {
  /// Distance band key (e.g., "100-150", "150-200", "200-250").
  final String distanceBand;

  /// SG Category this benchmark applies to.
  final SGCategory category;

  /// Tour baseline strokes per shot for this distance band.
  final double baselineStrokes;

  const ProfessionalBenchmark({
    required this.distanceBand,
    required this.category,
    required this.baselineStrokes,
  });

  @override
  List<Object?> get props => [distanceBand, category, baselineStrokes];
}

/// Player's own historical baseline for self-history benchmark.
class SelfHistoryBenchmark extends Equatable {
  final String playerId;
  final SGCategory category;
  final double historicalAverageStrokes;
  final int sampleCount;
  final DateTime computedAt;

  const SelfHistoryBenchmark({
    required this.playerId,
    required this.category,
    required this.historicalAverageStrokes,
    required this.sampleCount,
    required this.computedAt,
  });

  @override
  List<Object?> get props => [
    playerId,
    category,
    historicalAverageStrokes,
    sampleCount,
    computedAt,
  ];
}

/// Similar-handicap peer group benchmark data.
class SimilarHandicapBenchmark extends Equatable {
  /// Handicap range (e.g., "5-10", "10-15", "15-20").
  final String handicapRange;

  final SGCategory category;
  final double baselineStrokesPerShot;

  const SimilarHandicapBenchmark({
    required this.handicapRange,
    required this.category,
    required this.baselineStrokesPerShot,
  });

  @override
  List<Object?> get props => [handicapRange, category, baselineStrokesPerShot];
}

/// Target handicap benchmark.
class TargetHandicapBenchmark extends Equatable {
  final String playerId;
  final SGCategory category;
  final double targetHandicap;
  final double baselineStrokesPerShot;

  const TargetHandicapBenchmark({
    required this.playerId,
    required this.category,
    required this.targetHandicap,
    required this.baselineStrokesPerShot,
  });

  @override
  List<Object?> get props => [
    playerId,
    category,
    targetHandicap,
    baselineStrokesPerShot,
  ];
}
