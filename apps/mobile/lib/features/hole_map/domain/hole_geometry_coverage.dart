// Hole Geometry Coverage — VSP Mobile App
//
// Answers one question: does this hole have enough real geometry to be worth
// drawing as a vector map?
//
// Only 69 of ~900 holes have surveyed coordinates. On the rest the strategic
// hole map draws an empty green rectangle and calls it a course. This helper
// lets the map default to satellite + measuring on those holes instead.

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';

import 'hole_map_entity.dart';
import 'map_layer.dart';
import 'pin_entity.dart';

/// Inspects a [HoleMapEntity] for usable geometry.
abstract final class HoleGeometryCoverage {
  /// Layers that make a vector hole map worth looking at.
  ///
  /// Cart paths and landmarks alone do not: a golfer cannot plan a shot from
  /// a cart path.
  static const Set<MapLayerType> strategicLayers = {
    MapLayerType.green,
    MapLayerType.fairway,
    MapLayerType.bunker,
    MapLayerType.water,
    MapLayerType.penaltyArea,
    MapLayerType.tee,
  };

  /// True when at least one strategic layer actually contains geometry.
  static bool hasStrategicGeometry(HoleMapEntity holeMap) {
    for (final type in strategicLayers) {
      final layer = holeMap.layers[type];
      if (layer != null && featureCount(layer) > 0) return true;
    }
    return false;
  }

  /// True when the hole should open in satellite + measuring mode.
  ///
  /// A pin on its own is not a map — it gives one dot and no shape — so a hole
  /// with a pin but no polygons still gets satellite.
  static bool shouldDefaultToSatellite(HoleMapEntity holeMap) =>
      !hasStrategicGeometry(holeMap);

  /// Counts GeoJSON features in a layer, tolerating the three shapes the
  /// course package emits: FeatureCollection, bare Feature, bare geometry.
  static int featureCount(MapLayerEntity layer) {
    final geoJson = layer.geoJson;
    if (geoJson == null) return 0;

    final type = geoJson['type'];
    if (type == 'FeatureCollection') {
      final features = geoJson['features'];
      if (features is List) {
        return features.where(_hasCoordinates).length;
      }
      return 0;
    }
    if (type == 'Feature') {
      return _hasCoordinates(geoJson) ? 1 : 0;
    }
    return geoJson['coordinates'] != null ? 1 : 0;
  }

  /// Green (or pin) position for the measuring tool, when one is known.
  ///
  /// Prefers an active official pin. Falls back to the centroid of the green
  /// polygon, which is flagged as NOT surveyed: the course package carries no
  /// provenance for polygon geometry, and given how much of our data is
  /// derived, "estimated" is the safe thing to be wrong about.
  static MeasureAnchor? greenAnchor(HoleMapEntity holeMap) {
    final pin = holeMap.pin;
    if (pin != null) {
      return MeasureAnchor(
        position: LatLng(latitude: pin.latitude, longitude: pin.longitude),
        isSurveyed: pin.source == PinSource.official && !pin.isExpired,
      );
    }

    final greenLayer = holeMap.layers[MapLayerType.green];
    if (greenLayer == null) return null;
    final centroid = _centroid(greenLayer.geoJson);
    if (centroid == null) return null;
    return MeasureAnchor(position: centroid, isSurveyed: false);
  }

  static bool _hasCoordinates(Object? feature) {
    if (feature is! Map) return false;
    if (feature['coordinates'] != null) return true;
    final geometry = feature['geometry'];
    return geometry is Map && geometry['coordinates'] != null;
  }

  /// Mean of every coordinate in the geometry — accurate enough for a green.
  static LatLng? _centroid(Map<String, dynamic>? geoJson) {
    if (geoJson == null) return null;
    var latSum = 0.0;
    var lngSum = 0.0;
    var count = 0;

    void walk(Object? node) {
      if (node is List) {
        if (node.length >= 2 && node[0] is num && node[1] is num) {
          lngSum += (node[0] as num).toDouble();
          latSum += (node[1] as num).toDouble();
          count++;
          return;
        }
        for (final child in node) {
          walk(child);
        }
      } else if (node is Map) {
        walk(node['coordinates']);
        walk(node['geometry']);
        walk(node['features']);
      }
    }

    walk(geoJson);
    if (count == 0) return null;
    return LatLng(latitude: latSum / count, longitude: lngSum / count);
  }
}
