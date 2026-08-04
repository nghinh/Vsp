// Landmark Geometry Model — VSP Mobile App
//
// Geometry model for golf course landmarks (trees, fountains, restrooms, etc.).
// Landmarks are point features used for orientation on the course map.
//
// Story 6.4 — Wave 1: Domain models

import 'package:equatable/equatable.dart';

import '../value_objects/lat_lng.dart';
import '../models/data_quality.dart';

/// Types of landmarks on a golf course.
enum LandmarkType {
  tree('Tree', 'tree'),
  restroom('Restroom', 'restroom'),
  waterFountain('Water Fountain', 'water'),
  cartPath('Cart Path', 'cart_path'),
  bridge('Bridge', 'bridge'),
  teeMarker('Tee Marker', 'tee_marker'),
  distanceMarker('Distance Marker', 'distance_marker'),
  building('Building', 'building'),
  shelter('Shelter', 'shelter'),
  wildlifeArea('Wildlife Area', 'wildlife'),
  fairwayBunker('Fairway Bunker', 'fairway_bunker'),
  wasteArea('Waste Area', 'waste_area'),
  nativeArea('Native Area', 'native_area'),
  other('Other', 'other');

  final String displayName;
  final String slug;
  const LandmarkType(this.displayName, this.slug);

  static LandmarkType fromString(String value) {
    final normalized = value.toLowerCase().replaceAll(' ', '_');
    for (final lt in LandmarkType.values) {
      if (lt.slug == normalized) return lt;
    }
    return LandmarkType.other;
  }
}

/// A golf course landmark — point feature for orientation.
class LandmarkGeometry extends Equatable {
  /// Unique identifier for this landmark within the hole/facility.
  final String id;

  /// Display name, e.g. "Oak Tree", "Bathroom".
  final String name;

  /// Type of landmark.
  final LandmarkType type;

  /// Position of the landmark.
  final LatLng position;

  /// Optional heading/bearing from this landmark (degrees from north).
  final double? bearing;

  /// Data quality metadata.
  final DataQuality? dataQuality;

  const LandmarkGeometry({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    this.bearing,
    this.dataQuality,
  });

  // ─── Factory constructors ───────────────────────────────────────────────────

  /// Parse from GeoJSON Feature.
  factory LandmarkGeometry.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final geom = feature['geometry'] as Map<String, dynamic>;
    final coords = geom['coordinates'] as List<num>;

    return LandmarkGeometry(
      id: props['id'] as String? ?? 'unknown',
      name: props['name'] as String? ?? 'Landmark',
      type: LandmarkType.fromString(props['type'] as String? ?? 'other'),
      position: LatLng.fromGeoJson(coords),
      bearing: (props['bearing'] as num?)?.toDouble(),
      dataQuality: props['dataQuality'] != null
          ? DataQuality.fromJson(props['dataQuality'] as Map<String, dynamic>)
          : null,
    );
  }

  // ─── Computed properties ────────────────────────────────────────────────────

  /// Landmark type display name.
  String get typeLabel => type.displayName;

  /// True if this is a distance marker.
  bool get isDistanceMarker => type == LandmarkType.distanceMarker;

  /// True if this is a cart path landmark.
  bool get isCartPath => type == LandmarkType.cartPath;

  /// True if this landmark has bearing information.
  bool get hasBearing => bearing != null;

  // ─── Serialization ──────────────────────────────────────────────────────────

  /// Convert to GeoJSON Feature.
  Map<String, dynamic> toGeoJsonFeature() => {
    'type': 'Feature',
    'properties': {
      'id': id,
      'name': name,
      'type': type.slug,
      if (bearing != null) 'bearing': bearing,
      if (dataQuality != null) 'dataQuality': dataQuality!.toJson(),
    },
    'geometry': {'type': 'Point', 'coordinates': position.toGeoJson()},
  };

  @override
  List<Object?> get props => [id, name, type, position, bearing, dataQuality];
}
