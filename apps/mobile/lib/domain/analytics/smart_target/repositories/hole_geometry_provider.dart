// HoleGeometryProvider Interface — VSP Mobile App
//
// Repository interface for hole geometry data (Epic 6).
//
// Story 11.4 — Slice 1: Data Access Interfaces

import '../../../value_objects/lat_lng.dart';

/// A simplified hazard reference for Smart Target calculations.
class HoleHazardSummary {
  final String id;
  final String name;
  final String type;
  final List<LatLng> polygon;

  const HoleHazardSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.polygon,
  });

  bool get isBunker => type == 'bunker';
  bool get isWater => type == 'water' || type == 'penalty';
  bool get isOb => type == 'ob';
}

/// Hole geometry context for Smart Target generation.
class HoleContext {
  final String holeId;
  final int holeNumber;
  final int par;
  final LatLng pinPosition;
  final LatLng teeBox;
  final List<LatLng> fairwayCenterline;
  final List<LatLng> greenPolygon;
  final List<HoleHazardSummary> hazards;

  const HoleContext({
    required this.holeId,
    required this.holeNumber,
    required this.par,
    required this.pinPosition,
    required this.teeBox,
    required this.fairwayCenterline,
    required this.greenPolygon,
    required this.hazards,
  });

  int get totalHazardCount => hazards.length;

  List<HoleHazardSummary> get bunkers =>
      hazards.where((h) => h.isBunker).toList();

  List<HoleHazardSummary> get waterHazards =>
      hazards.where((h) => h.isWater).toList();

  List<HoleHazardSummary> get obHazards =>
      hazards.where((h) => h.isOb).toList();

  double get holeLengthMeters {
    if (fairwayCenterline.isEmpty) {
      return teeBox.distanceTo(pinPosition);
    }
    double total = 0;
    for (int i = 0; i < fairwayCenterline.length - 1; i++) {
      total += fairwayCenterline[i].distanceTo(fairwayCenterline[i + 1]);
    }
    return total;
  }
}

/// Provider interface for hole geometry data.
///
/// Consumed by Smart Target generator to:
///
/// - Identify candidate aim points along the shot line
/// - Compute landing zone ellipses
/// - Intersect landing zones with hazard polygons
abstract class HoleGeometryProvider {
  /// Get hole context for a specific hole.
  Future<HoleContext?> getHoleContext(String holeId);

  /// Get hole context by course ID and hole number.
  Future<HoleContext?> getHoleContextByNumber(String courseId, int holeNumber);

  /// Check if hole geometry is available for a hole.
  Future<bool> hasGeometry(String holeId);
}
