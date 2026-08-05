// MeasureOverlayBuilder Unit Tests — VSP Mobile App
//
// Tests cover:
// - The geodesic accuracy circle (radius accuracy, closed ring)
// - Feature kinds and ordering in the overlay collection
// - GPS accuracy only drawn when we actually have an accuracy figure

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/measure_calculator.dart';
import 'package:vsp_mobile/features/measure/domain/measure_overlay_builder.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';

void main() {
  const golfer = LatLng(latitude: 10.8, longitude: 106.7);

  List<String> kindsOf(Map<String, dynamic> collection) {
    return (collection['features'] as List)
        .map((f) => ((f as Map)['properties'] as Map)['kind'] as String)
        .toList();
  }

  group('geodesicCircle', () {
    test('every vertex sits at the requested radius', () {
      final ring = MeasureOverlayBuilder.geodesicCircle(
        center: golfer,
        radiusMeters: 30,
        segments: 16,
      );

      for (final vertex in ring) {
        expect(golfer.distanceTo(vertex), closeTo(30, 0.2));
      }
    });

    test('closes the ring as GeoJSON polygons require', () {
      final ring = MeasureOverlayBuilder.geodesicCircle(
        center: golfer,
        radiusMeters: 12,
        segments: 8,
      );

      expect(ring, hasLength(9));
      expect(ring.first.latitude, closeTo(ring.last.latitude, 1e-9));
      expect(ring.first.longitude, closeTo(ring.last.longitude, 1e-9));
    });

    test('scales with the radius', () {
      final small = MeasureOverlayBuilder.geodesicCircle(
        center: golfer,
        radiusMeters: 5,
        segments: 8,
      );
      final large = MeasureOverlayBuilder.geodesicCircle(
        center: golfer,
        radiusMeters: 50,
        segments: 8,
      );

      expect(golfer.distanceTo(small.first), closeTo(5, 0.1));
      expect(golfer.distanceTo(large.first), closeTo(50, 0.3));
    });
  });

  group('build', () {
    const calculator = MeasureCalculator();

    final points = [
      const MeasurePoint(
        id: 'a',
        position: LatLng(latitude: 10.801, longitude: 106.7),
      ),
      const MeasurePoint(
        id: 'b',
        position: LatLng(latitude: 10.802, longitude: 106.7),
      ),
    ];

    test('an empty measurement produces an empty collection', () {
      final overlay = MeasureOverlayBuilder.build(
        points: const [],
        result: MeasureResult.empty,
      );

      expect(overlay['type'], 'FeatureCollection');
      expect(overlay['features'], isEmpty);
    });

    test('emits accuracy, legs, golfer, green and every point', () {
      final green = const MeasureAnchor(
        position: LatLng(latitude: 10.803, longitude: 106.7),
        isSurveyed: false,
      );
      final result = calculator.compute(points: points, green: green);

      final overlay = MeasureOverlayBuilder.build(
        points: points,
        result: result,
        golfer: golfer,
        golferAccuracyMeters: 8,
        green: green,
      );
      final kinds = kindsOf(overlay);

      expect(kinds.first, MeasureFeatureKind.accuracy);
      expect(kinds, contains(MeasureFeatureKind.leg));
      expect(kinds, contains(MeasureFeatureKind.greenLeg));
      expect(kinds, contains(MeasureFeatureKind.golfer));
      expect(kinds, contains(MeasureFeatureKind.green));
      expect(
        kinds.where((k) => k == MeasureFeatureKind.point).length,
        points.length,
      );
    });

    test('skips the accuracy disc when accuracy is unknown', () {
      final overlay = MeasureOverlayBuilder.build(
        points: points,
        result: calculator.compute(points: points),
        golfer: golfer,
      );

      expect(kindsOf(overlay), isNot(contains(MeasureFeatureKind.accuracy)));
      expect(kindsOf(overlay), contains(MeasureFeatureKind.golfer));
    });

    test('numbers points from one so labels match the panel', () {
      final overlay = MeasureOverlayBuilder.build(
        points: points,
        result: calculator.compute(points: points),
      );
      final indexes = (overlay['features'] as List)
          .map((f) => ((f as Map)['properties'] as Map)['index'])
          .whereType<int>()
          .toList();

      expect(indexes, [1, 2]);
    });

    test('leg geometry runs from the leg start to the leg end', () {
      final result = calculator.compute(points: points);
      final overlay = MeasureOverlayBuilder.build(
        points: points,
        result: result,
      );
      final leg = (overlay['features'] as List).firstWhere(
        (f) => ((f as Map)['properties'] as Map)['kind'] ==
            MeasureFeatureKind.leg,
      ) as Map;
      final coordinates = (leg['geometry'] as Map)['coordinates'] as List;

      expect(coordinates.first, [106.7, 10.801]);
      expect(coordinates.last, [106.7, 10.802]);
    });

    test('flags whether the green position was surveyed', () {
      const green = MeasureAnchor(
        position: LatLng(latitude: 10.803, longitude: 106.7),
        isSurveyed: true,
      );
      final overlay = MeasureOverlayBuilder.build(
        points: points,
        result: calculator.compute(points: points, green: green),
        green: green,
      );
      final feature = (overlay['features'] as List).firstWhere(
        (f) => ((f as Map)['properties'] as Map)['kind'] ==
            MeasureFeatureKind.green,
      ) as Map;

      expect((feature['properties'] as Map)['surveyed'], isTrue);
    });
  });
}
