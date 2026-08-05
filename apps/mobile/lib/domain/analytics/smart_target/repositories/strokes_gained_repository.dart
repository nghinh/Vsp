// StrokesGainedRepository Interface — VSP Mobile App
//
// Repository interface for strokes gained analytics (Story 11.3).
//
// Story 11.4 — Slice 1: Data Access Interfaces

import 'package:equatable/equatable.dart';

/// Strokes gained result for a player relative to a benchmark.
class StrokesGainedResult extends Equatable {
  final String playerId;
  final String clubId;
  final double strokesGainedPerShot;
  final double strokesGainedTotal;
  final int shotCount;
  final double benchmarkAvgMeters;
  final double actualAvgMeters;
  final String benchmarkType;

  const StrokesGainedResult({
    required this.playerId,
    required this.clubId,
    required this.strokesGainedPerShot,
    required this.strokesGainedTotal,
    required this.shotCount,
    required this.benchmarkAvgMeters,
    required this.actualAvgMeters,
    required this.benchmarkType,
  });

  factory StrokesGainedResult.fromJson(Map<String, dynamic> json) {
    return StrokesGainedResult(
      playerId: json['playerId'] as String,
      clubId: json['clubId'] as String,
      strokesGainedPerShot: (json['strokesGainedPerShot'] as num).toDouble(),
      strokesGainedTotal: (json['strokesGainedTotal'] as num).toDouble(),
      shotCount: (json['shotCount'] as num).toInt(),
      benchmarkAvgMeters: (json['benchmarkAvgMeters'] as num).toDouble(),
      actualAvgMeters: (json['actualAvgMeters'] as num).toDouble(),
      benchmarkType: json['benchmarkType'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'clubId': clubId,
    'strokesGainedPerShot': strokesGainedPerShot,
    'strokesGainedTotal': strokesGainedTotal,
    'shotCount': shotCount,
    'benchmarkAvgMeters': benchmarkAvgMeters,
    'actualAvgMeters': actualAvgMeters,
    'benchmarkType': benchmarkType,
  };

  @override
  List<Object?> get props => [
    playerId,
    clubId,
    strokesGainedPerShot,
    strokesGainedTotal,
    shotCount,
    benchmarkAvgMeters,
    actualAvgMeters,
    benchmarkType,
  ];
}

/// Overall strokes gained summary for a player.
class StrokesGainedSummary {
  final String playerId;
  final double totalStrokesGained;
  final double avgStrokesGainedPerRound;
  final int totalShotCount;
  final Map<String, double> strokesGainedByClub;

  const StrokesGainedSummary({
    required this.playerId,
    required this.totalStrokesGained,
    required this.avgStrokesGainedPerRound,
    required this.totalShotCount,
    required this.strokesGainedByClub,
  });

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'totalStrokesGained': totalStrokesGained,
    'avgStrokesGainedPerRound': avgStrokesGainedPerRound,
    'totalShotCount': totalShotCount,
    'strokesGainedByClub': strokesGainedByClub,
  };

  factory StrokesGainedSummary.fromJson(Map<String, dynamic> json) {
    return StrokesGainedSummary(
      playerId: json['playerId'] as String,
      totalStrokesGained: (json['totalStrokesGained'] as num).toDouble(),
      avgStrokesGainedPerRound: (json['avgStrokesGainedPerRound'] as num)
          .toDouble(),
      totalShotCount: (json['totalShotCount'] as num).toInt(),
      strokesGainedByClub: (json['strokesGainedByClub'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }
}

/// Repository interface for strokes gained data.
///
/// Consumed by Smart Target generator to evaluate expected strokes gained
/// vs. risk tradeoff for the balanced strategy option.
abstract class StrokesGainedRepository {
  /// Get strokes gained for a specific club.
  Future<StrokesGainedResult?> getByClub(String playerId, String clubId);

  /// Get strokes gained for all clubs for a player.
  Future<List<StrokesGainedResult>> getAllForPlayer(String playerId);

  /// Get overall strokes gained summary for a player.
  Future<StrokesGainedSummary?> getSummaryForPlayer(String playerId);
}
