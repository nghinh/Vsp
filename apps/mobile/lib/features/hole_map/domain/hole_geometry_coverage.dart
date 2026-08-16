// Hole Geometry Coverage — VSP Mobile App
//
// Answers one question: does this hole have enough real geometry to be worth
// drawing as a vector map?
//
// Only 69 of ~900 holes have coordinates from a real source, and none of those
// have been verified. On the rest the strategic hole map draws an empty green
// rectangle and calls it a course. This helper lets the map default to
// satellite + measuring on those holes instead.
//
// The question has two halves and the second one used to be missing. Asking
// only "is there geometry here" answered yes for every synthetic hole, because
// the import pipeline derives a fairway corridor and a green extent from the
// hole's tee and green points whatever those points are worth — so the gate
// fired on 69 holes out of 900 rather than the 831 it was written for, and the
// "not surveyed" banner never appeared on the holes that most needed it. A
// shape drawn around invented coordinates is still invented, so provenance is
// now part of the question.

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

  /// True when the hole's geometry is both present and verified — the only
  /// case in which drawing a vector hole map tells the golfer the truth.
  static bool hasTrustworthyGeometry(HoleMapEntity holeMap) =>
      hasStrategicGeometry(holeMap) && holeMap.isSurveyed;

  /// True when the hole should open in satellite + measuring mode.
  ///
  /// A pin on its own is not a map — it gives one dot and no shape — so a hole
  /// with a pin but no polygons still gets satellite. Nor is a polygon drawn
  /// around unverified points: the satellite imagery underneath is real even
  /// when our vector data is not, and the measuring tool states its own error
  /// bar, so this is the better answer for an unsurveyed hole as well as the
  /// honest one.
  static bool shouldDefaultToSatellite(HoleMapEntity holeMap) =>
      !hasTrustworthyGeometry(holeMap);

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

  /// True when a layer carries a shape, as opposed to a spot on the ground.
  ///
  /// The distinction the course package does not make. Every hole it ships has
  /// a `tee` layer and a `green` layer, because the assembler writes the hole's
  /// own `teeing_ground_location` and `green_location` into them as reference
  /// points before it adds any polygons — and on the 62 courses whose polygons
  /// live in the draft table rather than the published one, those single points
  /// are the entire layer.
  ///
  /// A layer like that is a coordinate wearing a layer's name, and treating it
  /// as geometry is what let a package with no green outline in it displace a
  /// traced green outline. Everything downstream then measured to the middle of
  /// a green it could no longer see the edges of: no front, no back, one number
  /// on the panel where there should have been two.
  static bool hasAreaGeometry(MapLayerEntity layer) {
    final geoJson = layer.geoJson;
    if (geoJson == null) return false;

    bool isArea(Object? geometry) =>
        geometry is Map &&
        (geometry['type'] == 'Polygon' || geometry['type'] == 'MultiPolygon') &&
        geometry['coordinates'] != null;

    switch (geoJson['type']) {
      case 'FeatureCollection':
        final features = geoJson['features'];
        if (features is! List) return false;
        return features.any(
          (feature) => feature is Map && isArea(feature['geometry']),
        );
      case 'Feature':
        return isArea(geoJson['geometry']);
      default:
        return isArea(geoJson);
    }
  }

  /// Every coordinate of the green as the course package draws it.
  ///
  /// The near edge, the far edge and the middle of a green are three different
  /// numbers to a golfer choosing a club, and this is the only place the app
  /// knows the green's shape rather than just a point on it. Empty when the
  /// hole carries no green layer.
  static List<LatLng> greenOutline(HoleMapEntity holeMap) {
    final greenLayer = holeMap.layers[MapLayerType.green];
    if (greenLayer == null) return const [];
    return _coordinates(greenLayer.geoJson);
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
        // An official pin placed against unverified hole coordinates is an
        // exact position on a hole we cannot locate. The measuring tool's 2 m
        // error bar would be a claim the data does not support, so the hole's
        // own provenance has a veto here.
        isSurveyed:
            pin.source == PinSource.official &&
            !pin.isExpired &&
            holeMap.isSurveyed,
      );
    }

    final greenLayer = holeMap.layers[MapLayerType.green];
    if (greenLayer == null) return null;
    final centroid = _centroid(greenLayer.geoJson);
    if (centroid == null) return null;
    return MeasureAnchor(position: centroid, isSurveyed: false);
  }

  /// The middle of one layer, or null where the hole has none of it.
  ///
  /// Enough for the two ends of a hole: a tee point and a green point are
  /// all most Vietnamese holes have, and they are all the play line needs.
  static LatLng? layerCenter(HoleMapEntity holeMap, MapLayerType type) {
    final layer = holeMap.layers[type];
    if (layer == null) return null;
    return _centroid(layer.geoJson);
  }

  /// Centre of everything this hole actually draws.
  ///
  /// The mean of every coordinate in the strategic layers — tee, fairway,
  /// green, bunkers, water — so the camera frames the hole rather than one end
  /// of it.
  ///
  /// Returns null only when the hole has no strategic geometry at all, which
  /// is the case the satellite path handles.
  static LatLng? holeCenter(HoleMapEntity holeMap) {
    final points = <LatLng>[];
    for (final type in strategicLayers) {
      final layer = holeMap.layers[type];
      if (layer == null) continue;
      points.addAll(_coordinates(layer.geoJson));
    }
    if (points.isEmpty) return null;

    var latSum = 0.0;
    var lngSum = 0.0;
    for (final point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    return LatLng(
      latitude: latSum / points.length,
      longitude: lngSum / points.length,
    );
  }

  static bool _hasCoordinates(Object? feature) {
    if (feature is! Map) return false;
    if (feature['coordinates'] != null) return true;
    final geometry = feature['geometry'];
    return geometry is Map && geometry['coordinates'] != null;
  }

  /// Mean of every coordinate in the geometry — accurate enough for a green.
  static LatLng? _centroid(Map<String, dynamic>? geoJson) {
    final points = _coordinates(geoJson);
    if (points.isEmpty) return null;
    var latSum = 0.0;
    var lngSum = 0.0;
    for (final point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    return LatLng(
      latitude: latSum / points.length,
      longitude: lngSum / points.length,
    );
  }

  /// Every [lng, lat] pair in the geometry, in document order.
  ///
  /// Tolerates the same three shapes [featureCount] does, and any nesting
  /// depth of rings and multi-geometries.
  static List<LatLng> _coordinates(Map<String, dynamic>? geoJson) {
    if (geoJson == null) return const [];
    final points = <LatLng>[];

    void walk(Object? node) {
      if (node is List) {
        if (node.length >= 2 && node[0] is num && node[1] is num) {
          points.add(
            LatLng(
              latitude: (node[1] as num).toDouble(),
              longitude: (node[0] as num).toDouble(),
            ),
          );
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
    return points;
  }
}
