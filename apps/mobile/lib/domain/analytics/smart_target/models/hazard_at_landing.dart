// HazardAtLanding Model — VSP Mobile App
//
// A hazard that intersects or is near the landing zone of a shot.
//
// Story 11.4 — Slice 0: Domain Models

import 'package:equatable/equatable.dart';

/// A hazard intersecting or near the landing zone of a shot.
class HazardAtLanding extends Equatable {
  /// Unique identifier for this hazard within the hole.
  final String hazardId;

  /// Display name, e.g. "Bunker 1", "Water Hole 3 Left".
  final String hazardName;

  /// Hazard type slug: bunker, water, penalty, ob.
  final String hazardType;

  /// Proximity factor: 1.0 = overlapping, 0.5 = within 1 dispersion unit, 0.0 = clear.
  final double proximityFactor;

  /// Penalty weight for this hazard type (0–100, higher = more dangerous).
  final int penaltyWeight;

  const HazardAtLanding({
    required this.hazardId,
    required this.hazardName,
    required this.hazardType,
    required this.proximityFactor,
    required this.penaltyWeight,
  });

  /// True if landing zone overlaps the hazard.
  bool get isOverlapping => proximityFactor >= 1.0;

  /// True if hazard is within one dispersion unit (near miss zone).
  bool get isNearMiss => proximityFactor > 0.0 && proximityFactor < 1.0;

  /// True if hazard is clear of the landing zone.
  bool get isClear => proximityFactor <= 0.0;

  // ─── JSON ─────────────────────────────────────────────────────────────────

  factory HazardAtLanding.fromJson(Map<String, dynamic> json) {
    return HazardAtLanding(
      hazardId: json['hazardId'] as String,
      hazardName: json['hazardName'] as String,
      hazardType: json['hazardType'] as String,
      proximityFactor: (json['proximityFactor'] as num).toDouble(),
      penaltyWeight: json['penaltyWeight'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'hazardId': hazardId,
    'hazardName': hazardName,
    'hazardType': hazardType,
    'proximityFactor': proximityFactor,
    'penaltyWeight': penaltyWeight,
  };

  @override
  List<Object?> get props => [
    hazardId,
    hazardName,
    hazardType,
    proximityFactor,
    penaltyWeight,
  ];
}
