// Tests for GreenDistanceReading — front, centre and back of the green.
//
// These three numbers are what an orphaned screen
// (`active_round_distances_screen.dart`) promised and could never deliver: it
// read them from a `DistanceCubit` fed by a parallel `HoleGeometry` model that
// nothing in the app ever built from a downloaded course package, so it would
// have shown "No hole data" on every hole in production. The screen is gone;
// the capability is here, computed from the green polygon the hole map already
// loads and measured with the same calculator the measuring tool uses.
//
// One degree of latitude is 111 194.9 m on the sphere the app measures with,
// so the fixtures below are exact to the metre and asserted as literals.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/domain/green_distance_reading.dart';

const _golferLat = 10.7000;
const _lng = 106.7000;

/// The green runs from 0.0020° to 0.0030° north of the golfer: 222.39 m to the
/// near edge, 333.58 m to the far one, 277.99 m to the mean of the outline.
const _greenNearLat = 10.7020;
const _greenFarLat = 10.7030;

QualifiedLocation _fix({double? accuracyMeters = 4}) => QualifiedLocation(
  latitude: _golferLat,
  longitude: _lng,
  accuracyMeters: accuracyMeters,
  timestamp: DateTime(2026, 8, 5, 8),
  source: LocationSource.gps,
  isStale: false,
);

/// A hole whose green is drawn as a polygon, as a surveyed package draws it.
HoleMapEntity _hole({
  Map<String, dynamic>? greenGeoJson,
  bool withGreen = true,
}) => HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: 7,
  par: 4,
  layers: {
    if (withGreen)
      MapLayerType.green: MapLayerEntity(
        type: MapLayerType.green,
        format: LayerGeometryFormat.geoJson,
        style: const LayerStyle(),
        geoJson: greenGeoJson ?? _greenPolygon,
      ),
  },
);

/// A four-corner green: two vertices on the near edge, two on the far.
const Map<String, dynamic> _greenPolygon = {
  'type': 'Feature',
  'geometry': {
    'type': 'Polygon',
    'coordinates': [
      [
        [_lng, _greenNearLat],
        [_lng, _greenNearLat],
        [_lng, _greenFarLat],
        [_lng, _greenFarLat],
      ],
    ],
  },
};

void main() {
  group('front, centre and back', () {
    test('are the near edge, the mean and the far edge of the green', () {
      final reading = GreenDistanceReading.of(
        holeMap: _hole(),
        golfer: _fix(),
      );

      expect(reading.hasDistances, isTrue);
      expect(reading.front!.meters, closeTo(222.39, 0.5));
      expect(reading.centre!.meters, closeTo(277.99, 0.5));
      expect(reading.back!.meters, closeTo(333.58, 0.5));
      // Front is never longer than back — the whole point of three numbers.
      expect(reading.front!.meters, lessThan(reading.centre!.meters));
      expect(reading.centre!.meters, lessThan(reading.back!.meters));
    });

    test('carry the error bar the fix and the geometry earned', () {
      final reading = GreenDistanceReading.of(
        holeMap: _hole(),
        golfer: _fix(accuracyMeters: 12),
      );

      // √(12² + 5²) = 13.0 — the golfer's fix combined in quadrature with the
      // uncertainty of a point picked off aerial imagery, which is what a
      // digitised green outline is.
      expect(reading.front!.uncertaintyMeters, closeTo(13.0, 0.1));
      expect(reading.back!.uncertaintyMeters, closeTo(13.0, 0.1));
    });

    test('move with the golfer, because they are measured from the fix', () {
      final near = GreenDistanceReading.of(
        holeMap: _hole(),
        golfer: _fix(),
      );
      final closer = GreenDistanceReading.of(
        holeMap: _hole(),
        golfer: QualifiedLocation(
          latitude: 10.7010,
          longitude: _lng,
          accuracyMeters: 4,
          timestamp: DateTime(2026, 8, 5, 8),
          source: LocationSource.gps,
          isStale: false,
        ),
      );

      expect(closer.front!.meters, lessThan(near.front!.meters));
      expect(closer.front!.meters, closeTo(111.19, 0.5));
    });
  });

  group('and nothing at all when an input is missing', () {
    test('no fix means no distances — all three rest on the golfer', () {
      final reading = GreenDistanceReading.of(holeMap: _hole(), golfer: null);

      expect(reading.hasDistances, isFalse);
      expect(reading.front, isNull);
    });

    test('an unavailable fix is not treated as a position', () {
      // LocationService reports "unavailable" as 0,0 — the Gulf of Guinea.
      // Measuring from it would quote a confident 1 200 km to the green.
      final reading = GreenDistanceReading.of(
        holeMap: _hole(),
        golfer: QualifiedLocation.unavailable(),
      );

      expect(reading.hasDistances, isFalse);
    });

    test('a hole with no green layer has no green distances', () {
      final reading = GreenDistanceReading.of(
        holeMap: _hole(withGreen: false),
        golfer: _fix(),
      );

      expect(reading.hasDistances, isFalse);
    });

    test('a green drawn as a single point is not split into three', () {
      final reading = GreenDistanceReading.of(
        holeMap: _hole(
          greenGeoJson: const {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [_lng, _greenNearLat],
            },
          },
        ),
        golfer: _fix(),
      );

      // One coordinate is a marker, not an outline. Three identical figures
      // labelled front, centre and back would claim a precision the geometry
      // does not have.
      expect(reading.hasDistances, isFalse);
    });

    test('a green with no depth to it is not split into three', () {
      final reading = GreenDistanceReading.of(
        holeMap: _hole(
          greenGeoJson: const {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  // Three vertices spanning under a metre of depth.
                  [_lng, _greenNearLat],
                  [_lng + 0.000001, _greenNearLat],
                  [_lng, _greenNearLat + 0.000001],
                ],
              ],
            },
          },
        ),
        golfer: _fix(),
      );

      expect(reading.hasDistances, isFalse);
    });
  });
}
