// DispersionOverlay — VSP Mobile App
//
// Domain model for dispersion overlay with scatter points and hazard features.
// Per Story 11.1 AC-3: scatter overlay and hazard comparison.

import 'package:equatable/equatable.dart';

/// Shot outcome category for scatter points.
enum ShotResult { fairway, rough, bunker, water, ob, unknown }

/// A single scatter point representing a shot's landing position.
class DispersionPoint extends Equatable {
  /// Normalized X coordinate relative to target center.
  final double relativeX;

  /// Normalized Y coordinate relative to target center.
  final double relativeY;

  /// Shot outcome category.
  final ShotResult result;

  const DispersionPoint({
    required this.relativeX,
    required this.relativeY,
    required this.result,
  });

  @override
  List<Object?> get props => [relativeX, relativeY, result];
}

/// A hazard polygon projected to hole local coordinates.
class HazardFeature extends Equatable {
  final String hazardId;
  final HazardType type;
  final List<List<double>> coordinates; // [lng, lat] pairs

  const HazardFeature({
    required this.hazardId,
    required this.type,
    required this.coordinates,
  });

  @override
  List<Object?> get props => [hazardId, type, coordinates];
}

/// Hazard type categories.
enum HazardType { bunker, water, penaltyArea, ob, unknown }

/// Domain model for dispersion overlay data.
/// Contains scatter points, hazard features, and distance metrics.
class DispersionOverlay extends Equatable {
  final int clubId;
  final int bagId;
  final int holeId;
  final int layoutId;

  /// Number of shots used in this dispersion.
  final int shotCount;

  /// Scatter points as GeoJSON FeatureCollection.
  final Map<String, dynamic> scatterGeoJSON;

  /// Hazard polygons as GeoJSON FeatureCollection.
  final Map<String, dynamic> hazardGeoJSON;

  /// Average center of scatter points (hole local coords).
  final double? centerX;
  final double? centerY;

  /// Distance from scatter center to nearest hazard edge (meters).
  final double? centerToHazardMeters;

  /// Hazard type of the nearest hazard.
  final String? nearestHazardType;

  /// Count of shots by outcome category.
  final Map<String, int> outcomeCounts;

  /// Timestamp when this was computed.
  final DateTime? computedAt;

  const DispersionOverlay({
    required this.clubId,
    required this.bagId,
    required this.holeId,
    required this.layoutId,
    required this.shotCount,
    required this.scatterGeoJSON,
    required this.hazardGeoJSON,
    this.centerX,
    this.centerY,
    this.centerToHazardMeters,
    this.nearestHazardType,
    required this.outcomeCounts,
    this.computedAt,
  });

  /// Get outcome count for a specific result type.
  int getOutcomeCount(ShotResult result) {
    return outcomeCounts[result.name.toUpperCase()] ?? 0;
  }

  /// Get total fairway hits.
  int get fairwayCount => getOutcomeCount(ShotResult.fairway);

  /// Get total hazard hits (bunker + water + penalty).
  int get hazardCount =>
      getOutcomeCount(ShotResult.bunker) + getOutcomeCount(ShotResult.water);

  /// Get total OB count.
  int get obCount => getOutcomeCount(ShotResult.ob);

  @override
  List<Object?> get props => [
    clubId,
    bagId,
    holeId,
    layoutId,
    shotCount,
    scatterGeoJSON,
    hazardGeoJSON,
    centerX,
    centerY,
    centerToHazardMeters,
    nearestHazardType,
    outcomeCounts,
    computedAt,
  ];
}
