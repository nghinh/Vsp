// Hole Map GeoJSON — VSP Mobile App
//
// Turns the hole's domain entities into the two GeoJSON sources the vector
// course map draws: the course geometry from the downloaded course package,
// and the live overlay (golfer, pin, target, distance rings).
//
// Pure data — no Flutter, no MapLibre — so the geometry can be unit-tested
// without a device, in the same spirit as MeasureOverlayBuilder.
//
// Everything that has a real-world radius (the GPS accuracy disc, the distance
// rings) is emitted as a geodesic polygon in metres rather than as a point with
// a pixel radius. A ring drawn in pixels is not a 150 m ring at any zoom other
// than the one it was tuned for, and a golfer choosing a club off it would be
// reading a lie.

import 'package:vsp_mobile/features/measure/domain/measure_overlay_builder.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

import 'distance_ring_entity.dart';
import 'golfer_position_entity.dart';
import 'hole_map_entity.dart';
import 'map_layer.dart';
import 'pin_entity.dart';
import 'target_entity.dart';

/// Feature `layerType` values the course-map style filters on.
abstract final class HoleMapFeatureKind {
  static const String golfer = 'golfer';
  static const String golferAccuracy = 'golferAccuracy';
  static const String pin = 'pin';
  static const String target = 'target';
  static const String distanceRing100 = 'distanceRing100';
  static const String distanceRing150 = 'distanceRing150';
  static const String distanceRing200 = 'distanceRing200';

  /// The line a golfer is playing along. The numbers that go with it are
  /// drawn as Flutter widgets, not map symbols: a symbol layer needs a glyph
  /// endpoint, and this map has to work on a course with no signal.
  static const String playLine = 'playLine';
}

/// One leg of the play line: where it runs and what the number on it says.
///
/// The label arrives ready-made because only the caller knows whether this
/// golfer reads metres or yards.
class PlayLeg {
  const PlayLeg({required this.from, required this.to, required this.label});

  final LatLng from;
  final LatLng to;
  final String label;
}

/// Builds the GeoJSON feature collections for the vector hole map.
abstract final class HoleMapGeoJson {
  /// An empty feature collection, used as a source's initial data.
  static Map<String, dynamic> get empty => {
    'type': 'FeatureCollection',
    'features': <Map<String, dynamic>>[],
  };

  /// Flattens every course-package layer of [holeMap] into one collection,
  /// tagging each feature with `layerType` so the style can filter on it.
  ///
  /// The package stores each layer as its own FeatureCollection, but tolerates
  /// a bare Feature or bare geometry — all three shapes are accepted here for
  /// the same reason [HoleGeometryCoverage] accepts them: the data is real and
  /// not perfectly uniform.
  static Map<String, dynamic> courseGeometry(HoleMapEntity holeMap) {
    final features = <Map<String, dynamic>>[];

    for (final entry in holeMap.layers.entries) {
      final layerType = entry.key.name;
      for (final feature in _featuresOf(entry.value)) {
        final properties = <String, dynamic>{
          ...?(feature['properties'] as Map<String, dynamic>?),
          'layerType': layerType,
        };
        features.add({
          'type': 'Feature',
          'geometry': feature['geometry'],
          'properties': properties,
        });
      }
    }

    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Builds the live overlay: golfer position and accuracy disc, pin, target
  /// and any visible distance rings.
  static Map<String, dynamic> overlay({
    GolferPositionEntity? golferPosition,
    PinEntity? pin,
    TargetEntity? target,
    List<DistanceRingEntity> distanceRings = const [],
    List<PlayLeg> playLine = const [],
  }) {
    final features = <Map<String, dynamic>>[];

    // The line first, so every marker draws on top of it.
    //
    // Most holes here have a tee point, a green point and nothing else. Drawn
    // as two dots that is a map of nothing; drawn as a line with the distance
    // on it, it is the one thing a golfer wants from a hole map.
    for (final leg in playLine) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [leg.from.longitude, leg.from.latitude],
            [leg.to.longitude, leg.to.latitude],
          ],
        },
        'properties': {'layerType': HoleMapFeatureKind.playLine},
      });
    }

    // Accuracy disc first so the golfer dot draws on top of it.
    if (golferPosition != null) {
      final accuracy = golferPosition.accuracy;
      if (accuracy != null && accuracy > 0) {
        features.add(
          _circlePolygon(
            centerLat: golferPosition.latitude,
            centerLng: golferPosition.longitude,
            radiusMeters: accuracy,
            layerType: HoleMapFeatureKind.golferAccuracy,
          ),
        );
      }
      features.add(
        _point(
          lat: golferPosition.latitude,
          lng: golferPosition.longitude,
          properties: {
            'layerType': HoleMapFeatureKind.golfer,
            'isStale': golferPosition.isStale,
            'confidence': golferPosition.confidence.name,
          },
        ),
      );
    }

    for (final ring in distanceRings) {
      if (!ring.visible) {
        continue;
      }
      final layerType = _ringLayerType(ring);
      if (layerType == null) {
        continue;
      }
      features.add(
        _circleOutline(
          centerLat: ring.centerLat,
          centerLng: ring.centerLng,
          radiusMeters: ring.radiusMeters.toDouble(),
          layerType: layerType,
          label: ring.label,
        ),
      );
    }

    if (pin != null) {
      features.add(
        _point(
          lat: pin.latitude,
          lng: pin.longitude,
          properties: {
            'layerType': HoleMapFeatureKind.pin,
            'source': pin.source.name,
            'confidence': pin.confidence,
          },
        ),
      );
    }

    if (target != null) {
      features.add(
        _point(
          lat: target.latitude,
          lng: target.longitude,
          properties: {
            'layerType': HoleMapFeatureKind.target,
            if (target.label != null) 'label': target.label,
          },
        ),
      );
    }

    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Maps a ring's radius onto the style layer that draws it. Rings the style
  /// has no layer for are skipped rather than drawn as something they are not.
  static String? _ringLayerType(DistanceRingEntity ring) {
    switch (ring.radiusMeters) {
      case 100:
        return HoleMapFeatureKind.distanceRing100;
      case 150:
        return HoleMapFeatureKind.distanceRing150;
      case 200:
        return HoleMapFeatureKind.distanceRing200;
      default:
        return null;
    }
  }

  static List<Map<String, dynamic>> _featuresOf(MapLayerEntity layer) {
    final geoJson = layer.geoJson;
    if (geoJson == null) {
      return const [];
    }

    switch (geoJson['type']) {
      case 'FeatureCollection':
        final features = geoJson['features'];
        if (features is! List) {
          return const [];
        }
        return [
          for (final feature in features)
            if (feature is Map<String, dynamic> && feature['geometry'] != null)
              feature,
        ];
      case 'Feature':
        return geoJson['geometry'] != null ? [geoJson] : const [];
      default:
        // A bare geometry object.
        return geoJson['coordinates'] != null
            ? [
                {'type': 'Feature', 'geometry': geoJson},
              ]
            : const [];
    }
  }

  static Map<String, dynamic> _point({
    required double lat,
    required double lng,
    required Map<String, dynamic> properties,
  }) => {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [lng, lat],
    },
    'properties': properties,
  };

  static List<List<double>> _ring({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
  }) => MeasureOverlayBuilder.geodesicCircle(
    center: LatLng(latitude: centerLat, longitude: centerLng),
    radiusMeters: radiusMeters,
  ).map((p) => [p.longitude, p.latitude]).toList();

  static Map<String, dynamic> _circlePolygon({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    required String layerType,
  }) => {
    'type': 'Feature',
    'geometry': {
      'type': 'Polygon',
      'coordinates': [
        _ring(
          centerLat: centerLat,
          centerLng: centerLng,
          radiusMeters: radiusMeters,
        ),
      ],
    },
    'properties': {'layerType': layerType},
  };

  static Map<String, dynamic> _circleOutline({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    required String layerType,
    String? label,
  }) => {
    'type': 'Feature',
    'geometry': {
      'type': 'LineString',
      'coordinates': _ring(
        centerLat: centerLat,
        centerLng: centerLng,
        radiusMeters: radiusMeters,
      ),
    },
    'properties': {'layerType': layerType, if (label != null) 'label': label},
  };
}
