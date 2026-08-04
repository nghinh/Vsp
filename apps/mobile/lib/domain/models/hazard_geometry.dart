// Hazard Geometry Model — VSP Mobile App
//
// Geometry model for a golf hazard (bunker, water, penalty area, OB).
// Mirrors the PostGIS geometry schema from Story 3.1.
//
// Story 6.4 — Wave 1: Domain models

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../value_objects/lat_lng.dart';
import '../models/data_quality.dart';

/// Hazard type categories.
enum HazardType {
  bunker('Bunker', 'bunker'),
  water('Water', 'water'),
  penaltyArea('Penalty Area', 'penalty'),
  ob('Out of Bounds', 'ob');

  final String displayName;
  final String slug;
  const HazardType(this.displayName, this.slug);

  static HazardType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'bunker':
        return HazardType.bunker;
      case 'water':
        return HazardType.water;
      case 'penalty':
      case 'penalty_area':
        return HazardType.penaltyArea;
      case 'ob':
      case 'out_of_bounds':
        return HazardType.ob;
      default:
        return HazardType.bunker;
    }
  }
}

/// A golf hazard geometry — bunker, water, penalty area, or OB.
//
// A hazard is represented as a polygon with pre-computed
// nearest/farthest points from the tee for quick distance calculation.
class HazardGeometry extends Equatable {
  /// Unique identifier for this hazard within the hole.
  final String id;

  /// Type of hazard.
  final HazardType type;

  /// Display name, e.g. "Bunker 1", "Water Hole 3".
  final String name;

  /// Polygon boundary of the hazard (ordered vertices, closed — first == last).
  final List<LatLng> polygon;

  /// Nearest point on this hazard from the tee box (pre-computed).
  final LatLng nearestPoint;

  /// Farthest point on this hazard from the tee box (pre-computed).
  final LatLng farthestPoint;

  /// Data quality metadata.
  final DataQuality? dataQuality;

  const HazardGeometry({
    required this.id,
    required this.type,
    required this.name,
    required this.polygon,
    required this.nearestPoint,
    required this.farthestPoint,
    this.dataQuality,
  });

  // ─── Factory constructors ───────────────────────────────────────────────────

  /// Parse from GeoJSON Feature.
  factory HazardGeometry.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final geom = feature['geometry'] as Map<String, dynamic>;
    final coords = geom['coordinates'] as List<dynamic>;

    // GeoJSON polygon: outer ring only for MVP
    final ring = coords[0] as List<dynamic>;
    final polygon = ring
        .map((c) => LatLng.fromGeoJson(c as List<num>))
        .toList();

    final nearestRaw = props['nearestPoint'] as List<num>?;
    final farthestRaw = props['farthestPoint'] as List<num>?;

    return HazardGeometry(
      id: props['id'] as String? ?? 'unknown',
      type: HazardType.fromString(props['type'] as String? ?? 'bunker'),
      name: props['name'] as String? ?? 'Hazard',
      polygon: polygon,
      nearestPoint: nearestRaw != null
          ? LatLng.fromGeoJson(nearestRaw)
          : polygon.first,
      farthestPoint: farthestRaw != null
          ? LatLng.fromGeoJson(farthestRaw)
          : polygon.last,
      dataQuality: props['dataQuality'] != null
          ? DataQuality.fromJson(props['dataQuality'] as Map<String, dynamic>)
          : null,
    );
  }

  // ─── Computed properties ────────────────────────────────────────────────────

  /// True if the hazard polygon is valid (at least 3 unique vertices).
  bool get isValid => polygon.length >= 3;

  /// Number of vertices in the polygon.
  int get vertexCount => polygon.length;

  /// Hazard type display name.
  String get typeLabel => type.displayName;

  /// True if this is a bunker hazard.
  bool get isBunker => type == HazardType.bunker;

  /// True if this is a water/penalty hazard.
  bool get isWater =>
      type == HazardType.water || type == HazardType.penaltyArea;

  /// True if this is an OB hazard.
  bool get isOb => type == HazardType.ob;

  /// Approximate area of the hazard polygon in square meters.
  /// Uses Shoelace formula; suitable for small golf feature areas.
  double get areaSquareMeters {
    if (polygon.length < 3) return 0;
    double sum = 0;
    for (int i = 0; i < polygon.length - 1; i++) {
      sum += polygon[i].longitude * polygon[i + 1].latitude;
      sum -= polygon[i + 1].longitude * polygon[i].latitude;
    }
    // Convert to approximate sq meters (1 deg lat ≈ 111km, adjusted for longitude)
    final latDegToM = 111000.0;
    final avgLat =
        polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length;
    final lonDegToM = 111000.0 * math.cos(avgLat * math.pi / 180);
    return (sum.abs() / 2) * latDegToM * lonDegToM;
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  /// Convert to GeoJSON Feature.
  Map<String, dynamic> toGeoJsonFeature() => {
    'type': 'Feature',
    'properties': {
      'id': id,
      'type': type.slug,
      'name': name,
      if (dataQuality != null) 'dataQuality': dataQuality!.toJson(),
    },
    'geometry': {
      'type': 'Polygon',
      'coordinates': [polygon.map((p) => p.toGeoJson()).toList()],
    },
  };

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    polygon,
    nearestPoint,
    farthestPoint,
    dataQuality,
  ];
}
