// Round Review Metrics Model — VSP Mobile App
//
// Scoring and shot metrics for a completed round review.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
//
// Combines score data (gross, putts, penalties, GIR, FIR) with
// shot-level aggregations (club usage, distances, lies).

import 'package:equatable/equatable.dart';

import 'incomplete_data_warning.dart';
import 'shot_metrics.dart';

/// Summary scoring metrics for a completed round.
class RoundScoringSummary extends Equatable {
  final String roundId;
  final String playerId;
  final int totalGrossScore;
  final int? totalPutts;
  final int? totalPenalties;
  final int? girCount; // Greens in regulation
  final int? girTotal; // Par-3s + par-4s + par-5s played
  final int? firCount; // Fairways in regulation
  final int? firTotal; // Par-4s + par-5s (holes where FIR applies)
  final int? upAndDownCount; // Scrambles: got up-and-down from around green
  final int? upAndDownTotal; // Opportunities for up-and-down
  final int? sandSaveCount;
  final int? sandSaveTotal;
  final int? birdieOrBetterCount;
  final int? parOrBetterCount;
  final int? bogeyOrWorseCount;
  final double? scoringAverage;
  final int? scoreToPar; // Total relative to par (negative = under)

  const RoundScoringSummary({
    required this.roundId,
    required this.playerId,
    required this.totalGrossScore,
    this.totalPutts,
    this.totalPenalties,
    this.girCount,
    this.girTotal,
    this.firCount,
    this.firTotal,
    this.upAndDownCount,
    this.upAndDownTotal,
    this.sandSaveCount,
    this.sandSaveTotal,
    this.birdieOrBetterCount,
    this.parOrBetterCount,
    this.bogeyOrWorseCount,
    this.scoringAverage,
    this.scoreToPar,
  });

  /// GIR percentage (0-100).
  double? get girPercentage {
    if (girCount == null || girTotal == null || girTotal == 0) return null;
    return (girCount! / girTotal!) * 100;
  }

  /// FIR percentage (0-100).
  double? get firPercentage {
    if (firCount == null || firTotal == null || firTotal == 0) return null;
    return (firCount! / firTotal!) * 100;
  }

  /// Up-and-down percentage (0-100).
  double? get upAndDownPercentage {
    if (upAndDownCount == null ||
        upAndDownTotal == null ||
        upAndDownTotal == 0) {
      return null;
    }
    return (upAndDownCount! / upAndDownTotal!) * 100;
  }

  /// Sand save percentage (0-100).
  double? get sandSavePercentage {
    if (sandSaveCount == null || sandSaveTotal == null || sandSaveTotal == 0) {
      return null;
    }
    return (sandSaveCount! / sandSaveTotal!) * 100;
  }

  @override
  List<Object?> get props => [
    roundId,
    playerId,
    totalGrossScore,
    totalPutts,
    totalPenalties,
    girCount,
    girTotal,
    firCount,
    firTotal,
    upAndDownCount,
    upAndDownTotal,
    sandSaveCount,
    sandSaveTotal,
    birdieOrBetterCount,
    parOrBetterCount,
    bogeyOrWorseCount,
    scoringAverage,
    scoreToPar,
  ];

  Map<String, dynamic> toJson() => {
    'roundId': roundId,
    'playerId': playerId,
    'totalGrossScore': totalGrossScore,
    'totalPutts': totalPutts,
    'totalPenalties': totalPenalties,
    'girCount': girCount,
    'girTotal': girTotal,
    'firCount': firCount,
    'firTotal': firTotal,
    'upAndDownCount': upAndDownCount,
    'upAndDownTotal': upAndDownTotal,
    'sandSaveCount': sandSaveCount,
    'sandSaveTotal': sandSaveTotal,
    'birdieOrBetterCount': birdieOrBetterCount,
    'parOrBetterCount': parOrBetterCount,
    'bogeyOrWorseCount': bogeyOrWorseCount,
    'scoringAverage': scoringAverage,
    'scoreToPar': scoreToPar,
  };

  factory RoundScoringSummary.fromJson(Map<String, dynamic> json) {
    return RoundScoringSummary(
      roundId: json['roundId'] as String,
      playerId: json['playerId'] as String,
      totalGrossScore: (json['totalGrossScore'] as num).toInt(),
      totalPutts: (json['totalPutts'] as num?)?.toInt(),
      totalPenalties: (json['totalPenalties'] as num?)?.toInt(),
      girCount: (json['girCount'] as num?)?.toInt(),
      girTotal: (json['girTotal'] as num?)?.toInt(),
      firCount: (json['firCount'] as num?)?.toInt(),
      firTotal: (json['firTotal'] as num?)?.toInt(),
      upAndDownCount: (json['upAndDownCount'] as num?)?.toInt(),
      upAndDownTotal: (json['upAndDownTotal'] as num?)?.toInt(),
      sandSaveCount: (json['sandSaveCount'] as num?)?.toInt(),
      sandSaveTotal: (json['sandSaveTotal'] as num?)?.toInt(),
      birdieOrBetterCount: (json['birdieOrBetterCount'] as num?)?.toInt(),
      parOrBetterCount: (json['parOrBetterCount'] as num?)?.toInt(),
      bogeyOrWorseCount: (json['bogeyOrWorseCount'] as num?)?.toInt(),
      scoringAverage: (json['scoringAverage'] as num?)?.toDouble(),
      scoreToPar: (json['scoreToPar'] as num?)?.toInt(),
    );
  }
}

/// Round review metrics combining scoring and shot data.
class RoundReviewMetrics extends Equatable {
  final RoundScoringSummary scoring;
  final ShotMetrics shotMetrics;
  final IncompleteDataWarning? incompleteDataWarning;
  final DateTime generatedAt;
  final String? courseName;
  final DateTime? roundDate;

  const RoundReviewMetrics({
    required this.scoring,
    required this.shotMetrics,
    this.incompleteDataWarning,
    required this.generatedAt,
    this.courseName,
    this.roundDate,
  });

  /// True if the underlying data is insufficient for reliable insights.
  bool get hasInsufficientData => incompleteDataWarning != null;

  @override
  List<Object?> get props => [
    scoring,
    shotMetrics,
    incompleteDataWarning,
    generatedAt,
    courseName,
    roundDate,
  ];

  Map<String, dynamic> toJson() => {
    'scoring': scoring.toJson(),
    'shotMetrics': shotMetrics.toJson(),
    'incompleteDataWarning': incompleteDataWarning?.toJson(),
    'generatedAt': generatedAt.toIso8601String(),
    'courseName': courseName,
    'roundDate': roundDate?.toIso8601String(),
  };

  factory RoundReviewMetrics.fromJson(Map<String, dynamic> json) {
    return RoundReviewMetrics(
      scoring: RoundScoringSummary.fromJson(
        json['scoring'] as Map<String, dynamic>,
      ),
      shotMetrics: ShotMetrics.fromJson(
        json['shotMetrics'] as Map<String, dynamic>,
      ),
      incompleteDataWarning: json['incompleteDataWarning'] != null
          ? IncompleteDataWarning.fromJson(
              json['incompleteDataWarning'] as Map<String, dynamic>,
            )
          : null,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      courseName: json['courseName'] as String?,
      roundDate: json['roundDate'] != null
          ? DateTime.parse(json['roundDate'] as String)
          : null,
    );
  }
}
