// Hole Geometry Model — VSP Mobile App
//
// Full hole geometry including green, hazards, landmarks, and metadata.
// Aggregates all spatial data for a single golf hole.
//
// Story 6.4 — Wave 1: Domain models

import 'package:equatable/equatable.dart';

import '../value_objects/lat_lng.dart';
import 'data_quality.dart';
import 'hazard_geometry.dart';
import 'landmark_geometry.dart';

/// A complete golf hole geometry.
//
// Contains all spatial features for one hole:
// green polygon, pin position, hazards, tee box, fairway centerline,
// cart paths, OB areas, and landmarks.
class HoleGeometry extends Equatable {
  /// Hole number (1–18).
  final int holeNumber;

  /// Par for this hole.
  final int par;

  /// Green boundary polygon (ordered vertices, closed — first == last).
  final List<LatLng> greenPolygon;

  /// Current pin position for this hole.
  final LatLng pinPosition;

  /// Tee box position.
  final LatLng teeBox;

  /// Fairway centerline as a polyline (ordered points).
  final List<LatLng> fairwayCenterline;

  /// All hazards on this hole (bunkers, water, OB, penalty areas).
  final List<HazardGeometry> hazards;

  /// Cart path segments on this hole.
  final List<List<LatLng>> cartPaths;

  /// OB area polygons on this hole.
  final List<List<LatLng>> obAreas;

  /// Landmarks on this hole for orientation.
  final List<LandmarkGeometry> landmarks;

  /// Data quality metadata for this hole geometry.
  final DataQuality? dataQuality;

  const HoleGeometry({
    required this.holeNumber,
    required this.par,
    required this.greenPolygon,
    required this.pinPosition,
    required this.teeBox,
    required this.fairwayCenterline,
    this.hazards = const [],
    this.cartPaths = const [],
    this.obAreas = const [],
    this.landmarks = const [],
    this.dataQuality,
  });

  // ─── Factory constructors ───────────────────────────────────────────────────

  /// Parse from GeoJSON FeatureCollection.
  factory HoleGeometry.fromGeoJsonFeatureCollection(
    Map<String, dynamic> collection,
    int holeNumber,
  ) {
    final features = collection['features'] as List<dynamic>;
    final featureMap = <String, Map<String, dynamic>>{};

    for (final f in features) {
      final feature = f as Map<String, dynamic>;
      final props = feature['properties'] as Map<String, dynamic>;
      final layerType = props['layerType'] as String? ?? 'unknown';
      featureMap[layerType] = feature;
    }

    // Parse green polygon
    List<LatLng> greenPolygon = [];
    final greenFeature = featureMap['green'];
    if (greenFeature != null) {
      final geom = greenFeature['geometry'] as Map<String, dynamic>;
      final coords = geom['coordinates'] as List<dynamic>;
      if (coords.isNotEmpty) {
        final ring = coords[0] as List<dynamic>;
        greenPolygon = ring
            .map((c) => LatLng.fromGeoJson(c as List<num>))
            .toList();
      }
    }

    // Parse pin position
    LatLng pinPosition = greenPolygon.isNotEmpty
        ? greenPolygon.first
        : const LatLng(latitude: 0, longitude: 0);
    final pinFeature = featureMap['pin'];
    if (pinFeature != null) {
      final geom = pinFeature['geometry'] as Map<String, dynamic>;
      pinPosition = LatLng.fromGeoJson((geom['coordinates'] as List<num>));
    }

    // Parse tee box
    LatLng teeBox = const LatLng(latitude: 0, longitude: 0);
    final teeFeature = featureMap['tee'];
    if (teeFeature != null) {
      final geom = teeFeature['geometry'] as Map<String, dynamic>;
      teeBox = LatLng.fromGeoJson((geom['coordinates'] as List<num>));
    }

    // Parse fairway centerline
    List<LatLng> fairwayCenterline = [];
    final fairwayFeature = featureMap['fairway'];
    if (fairwayFeature != null) {
      final geom = fairwayFeature['geometry'] as Map<String, dynamic>;
      final coords = geom['coordinates'] as List<dynamic>;
      fairwayCenterline = coords
          .map((c) => LatLng.fromGeoJson(c as List<num>))
          .toList();
    }

    // Parse hazards
    final hazards = <HazardGeometry>[];
    final bunkerFeature = featureMap['bunker'];
    if (bunkerFeature != null) {
      hazards.add(HazardGeometry.fromGeoJsonFeature(bunkerFeature));
    }
    final waterFeature = featureMap['water'];
    if (waterFeature != null) {
      hazards.add(HazardGeometry.fromGeoJsonFeature(waterFeature));
    }
    final obFeature = featureMap['ob'];
    if (obFeature != null) {
      hazards.add(HazardGeometry.fromGeoJsonFeature(obFeature));
    }

    // Parse landmarks
    final landmarks = <LandmarkGeometry>[];
    final landmarkFeature = featureMap['landmark'];
    if (landmarkFeature != null) {
      landmarks.add(LandmarkGeometry.fromGeoJsonFeature(landmarkFeature));
    }

    // Parse cart paths
    final cartPaths = <List<LatLng>>[];
    final cartFeature = featureMap['cart_path'];
    if (cartFeature != null) {
      final geom = cartFeature['geometry'] as Map<String, dynamic>;
      final coords = geom['coordinates'] as List<dynamic>;
      for (final line in coords) {
        cartPaths.add(
          (line as List<dynamic>)
              .map((c) => LatLng.fromGeoJson(c as List<num>))
              .toList(),
        );
      }
    }

    // Parse OB areas
    final obAreas = <List<LatLng>>[];
    final obAreaFeature = featureMap['ob_area'];
    if (obAreaFeature != null) {
      final geom = obAreaFeature['geometry'] as Map<String, dynamic>;
      final coords = geom['coordinates'] as List<dynamic>;
      if (coords.isNotEmpty) {
        final ring = coords[0] as List<dynamic>;
        obAreas.add(
          ring.map((c) => LatLng.fromGeoJson(c as List<num>)).toList(),
        );
      }
    }

    return HoleGeometry(
      holeNumber: holeNumber,
      par: (featureMap['hole']?['properties']?['par'] as num?)?.toInt() ?? 4,
      greenPolygon: greenPolygon,
      pinPosition: pinPosition,
      teeBox: teeBox,
      fairwayCenterline: fairwayCenterline,
      hazards: hazards,
      cartPaths: cartPaths,
      obAreas: obAreas,
      landmarks: landmarks,
    );
  }

  // ─── Computed properties ────────────────────────────────────────────────────

  /// True if the green polygon is valid (at least 3 vertices).
  bool get hasValidGreen => greenPolygon.length >= 3;

  /// Number of hazards on this hole.
  int get hazardCount => hazards.length;

  /// All bunker hazards.
  List<HazardGeometry> get bunkers => hazards.where((h) => h.isBunker).toList();

  /// All water/penalty hazards.
  List<HazardGeometry> get waterHazards =>
      hazards.where((h) => h.isWater).toList();

  /// All OB areas.
  List<HazardGeometry> get obHazards => hazards.where((h) => h.isOb).toList();

  /// All landmark features.
  List<LandmarkGeometry> get distanceMarkers =>
      landmarks.where((l) => l.isDistanceMarker).toList();

  /// Total hazard count.
  int get totalHazardCount => hazards.length;

  /// True if this hole has any hazards.
  bool get hasHazards => hazards.isNotEmpty;

  /// Hole length in meters (approximate — straight-line from tee to green center).
  double get holeLengthMeters {
    if (greenPolygon.isEmpty || fairwayCenterline.isEmpty) {
      return teeBox.distanceTo(pinPosition);
    }
    // Sum of centerline segments
    double total = 0;
    for (int i = 0; i < fairwayCenterline.length - 1; i++) {
      total += fairwayCenterline[i].distanceTo(fairwayCenterline[i + 1]);
    }
    return total;
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  /// Convert to a summary map for debugging/display.
  Map<String, dynamic> toSummaryMap() => {
    'hole': holeNumber,
    'par': par,
    'pinPosition': {'lat': pinPosition.latitude, 'lon': pinPosition.longitude},
    'greenVertexCount': greenPolygon.length,
    'hazardCount': hazardCount,
    'landmarkCount': landmarks.length,
    'hasCartPaths': cartPaths.isNotEmpty,
    'hasObAreas': obAreas.isNotEmpty,
    'holeLengthMeters': holeLengthMeters.round(),
  };

  @override
  List<Object?> get props => [
    holeNumber,
    par,
    greenPolygon,
    pinPosition,
    teeBox,
    fairwayCenterline,
    hazards,
    cartPaths,
    obAreas,
    landmarks,
    dataQuality,
  ];
}
