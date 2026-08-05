// Measure Overlay Builder — VSP Mobile App
//
// Builds the GeoJSON the map draws for the measuring tool: the accuracy disc
// around the golfer, the measured chain, and each dropped point.
//
// Pure data — no Flutter, no MapLibre — so the geometry can be unit-tested
// without a device.

import 'dart:math' as math;

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

import 'measure_leg.dart';
import 'measure_point.dart';

/// Feature `kind` values used by the satellite style's layer filters.
abstract final class MeasureFeatureKind {
  /// Filled disc showing the GPS accuracy radius.
  static const String accuracy = 'accuracy';

  /// Solid line for a measured leg.
  static const String leg = 'leg';

  /// Dashed line for the run-on from the last point to the green.
  static const String greenLeg = 'greenLeg';

  /// The golfer's GPS position.
  static const String golfer = 'golfer';

  /// The known green/pin position.
  static const String green = 'green';

  /// A point the golfer dropped.
  static const String point = 'point';
}

/// Builds the measuring-tool GeoJSON feature collection.
abstract final class MeasureOverlayBuilder {
  /// Number of segments used to approximate the accuracy disc.
  static const int accuracyCircleSegments = 48;

  /// Mean earth radius in metres — same value the app's haversine uses.
  static const double earthRadiusMeters = 6371000.0;

  /// Builds the full overlay for the current measurement.
  static Map<String, dynamic> build({
    required List<MeasurePoint> points,
    required MeasureResult result,
    LatLng? golfer,
    double? golferAccuracyMeters,
    MeasureAnchor? green,
  }) {
    final features = <Map<String, dynamic>>[];

    // Accuracy disc first so everything else draws on top of it.
    if (golfer != null &&
        golferAccuracyMeters != null &&
        golferAccuracyMeters > 0) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            geodesicCircle(
              center: golfer,
              radiusMeters: golferAccuracyMeters,
            ).map((p) => [p.longitude, p.latitude]).toList(),
          ],
        },
        'properties': {'kind': MeasureFeatureKind.accuracy},
      });
    }

    for (final leg in result.legs) {
      features.add(_lineFeature(leg, MeasureFeatureKind.leg));
    }
    final greenLeg = result.greenLeg;
    if (greenLeg != null) {
      features.add(_lineFeature(greenLeg, MeasureFeatureKind.greenLeg));
    }

    if (golfer != null) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [golfer.longitude, golfer.latitude],
        },
        'properties': {'kind': MeasureFeatureKind.golfer},
      });
    }

    if (green != null) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [green.position.longitude, green.position.latitude],
        },
        'properties': {
          'kind': MeasureFeatureKind.green,
          'surveyed': green.isSurveyed,
        },
      });
    }

    for (var i = 0; i < points.length; i++) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [points[i].longitude, points[i].latitude],
        },
        'properties': {
          'kind': MeasureFeatureKind.point,
          'index': i + 1,
          'id': points[i].id,
        },
      });
    }

    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Approximates a circle of [radiusMeters] around [center] as a closed ring.
  ///
  /// The first and last vertex are identical, as GeoJSON polygons require.
  static List<LatLng> geodesicCircle({
    required LatLng center,
    required double radiusMeters,
    int segments = accuracyCircleSegments,
  }) {
    final ring = <LatLng>[];
    final angularRadius = radiusMeters / earthRadiusMeters;
    final latRad = center.latitude * math.pi / 180.0;
    final lngRad = center.longitude * math.pi / 180.0;

    for (var i = 0; i <= segments; i++) {
      final bearing = 2 * math.pi * i / segments;
      final lat = math.asin(
        math.sin(latRad) * math.cos(angularRadius) +
            math.cos(latRad) * math.sin(angularRadius) * math.cos(bearing),
      );
      final lng =
          lngRad +
          math.atan2(
            math.sin(bearing) * math.sin(angularRadius) * math.cos(latRad),
            math.cos(angularRadius) - math.sin(latRad) * math.sin(lat),
          );
      ring.add(
        LatLng(
          latitude: lat * 180.0 / math.pi,
          longitude: lng * 180.0 / math.pi,
        ),
      );
    }
    return ring;
  }

  static Map<String, dynamic> _lineFeature(MeasureLeg leg, String kind) {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [leg.from.longitude, leg.from.latitude],
          [leg.to.longitude, leg.to.latitude],
        ],
      },
      'properties': {'kind': kind, 'meters': leg.meters},
    };
  }
}
