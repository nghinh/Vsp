// StrategyOption Model — VSP Mobile App
//
// A single strategy option (safe / balanced / aggressive) for a Smart Target recommendation.
//
// Story 11.4 — Slice 0: Domain Models

import 'package:equatable/equatable.dart';

import '../../../value_objects/lat_lng.dart';
import 'hazard_at_landing.dart';
import 'strategy_type.dart';

/// A single strategy option for Smart Target recommendation.
class StrategyOption extends Equatable {
  /// The strategy tier.
  final StrategyType strategyType;

  /// Club ID recommended for this strategy.
  final String clubId;

  /// Club name for display (e.g. "7 Iron").
  final String clubName;

  /// Loft angle in degrees.
  final double? loftDegrees;

  /// Aim point coordinates.
  final LatLng aimPoint;

  /// Carry distance in meters from golfer position to aim point.
  final double carryMeters;

  /// Remaining distance from aim point to pin in meters.
  final double remainingMeters;

  /// Hazards at or near the landing zone.
  final List<HazardAtLanding> hazardsAtLanding;

  /// Aggregated risk score (0–100, higher = riskier).
  final int riskScore;

  /// Confidence in this recommendation (0.0–1.0, based on sample size and data quality).
  final double confidenceScore;

  /// Human-readable explanation of why this option was chosen.
  final String explanation;

  const StrategyOption({
    required this.strategyType,
    required this.clubId,
    required this.clubName,
    this.loftDegrees,
    required this.aimPoint,
    required this.carryMeters,
    required this.remainingMeters,
    required this.hazardsAtLanding,
    required this.riskScore,
    required this.confidenceScore,
    required this.explanation,
  });

  /// True if any hazard overlaps the landing zone.
  bool get hasDirectHazard => hazardsAtLanding.any((h) => h.isOverlapping);

  /// True if any hazard is in the near-miss zone.
  bool get hasNearMissHazard => hazardsAtLanding.any((h) => h.isNearMiss);

  // ─── JSON ─────────────────────────────────────────────────────────────────

  factory StrategyOption.fromJson(Map<String, dynamic> json) {
    return StrategyOption(
      strategyType: StrategyType.values.firstWhere(
        (e) => e.name == json['strategyType'],
        orElse: () => StrategyType.balanced,
      ),
      clubId: json['clubId'] as String,
      clubName: json['clubName'] as String,
      loftDegrees: (json['loftDegrees'] as num?)?.toDouble(),
      aimPoint: LatLng.fromGeoJson(
        (json['aimPoint'] as Map<String, dynamic>)['coordinates'] as List<num>,
      ),
      carryMeters: (json['carryMeters'] as num).toDouble(),
      remainingMeters: (json['remainingMeters'] as num).toDouble(),
      hazardsAtLanding: (json['hazardsAtLanding'] as List<dynamic>? ?? const [])
          .map((e) => HazardAtLanding.fromJson(e as Map<String, dynamic>))
          .toList(),
      riskScore: (json['riskScore'] as num).toInt(),
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      explanation: json['explanation'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'strategyType': strategyType.name,
    'clubId': clubId,
    'clubName': clubName,
    'loftDegrees': loftDegrees,
    'aimPoint': {'type': 'Point', 'coordinates': aimPoint.toGeoJson()},
    'carryMeters': carryMeters,
    'remainingMeters': remainingMeters,
    'hazardsAtLanding': hazardsAtLanding.map((e) => e.toJson()).toList(),
    'riskScore': riskScore,
    'confidenceScore': confidenceScore,
    'explanation': explanation,
  };

  @override
  List<Object?> get props => [
    strategyType,
    clubId,
    clubName,
    loftDegrees,
    aimPoint,
    carryMeters,
    remainingMeters,
    hazardsAtLanding,
    riskScore,
    confidenceScore,
    explanation,
  ];
}
