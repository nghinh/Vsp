// MeasureCalculator Unit Tests — VSP Mobile App
//
// Tests cover:
// - Haversine leg distances against known ground truth
// - Multi-point leg chains and totals
// - The run-on leg to the green (surveyed vs estimated)
// - Uncertainty combination in quadrature, and the honesty rules that depend
//   on it (a poor fix must not produce a confident number)
// - Behaviour with no GPS fix at all
// - Tap hit-testing so tapping a marker removes it instead of stacking points

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/value_objects/distance_measurement.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/measure_calculator.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';

void main() {
  const calculator = MeasureCalculator();

  // A quiet corner of a Vietnamese golf course.
  const base = LatLng(latitude: 10.800000, longitude: 106.700000);

  MeasurePoint pointAt(double lat, double lng, {String id = 'p'}) =>
      MeasurePoint(id: id, position: LatLng(latitude: lat, longitude: lng));

  QualifiedLocation fix({
    double lat = 10.800000,
    double lng = 106.700000,
    double? accuracy = 4.0,
    bool stale = false,
    LocationSource source = LocationSource.gps,
  }) {
    return QualifiedLocation(
      latitude: lat,
      longitude: lng,
      accuracyMeters: accuracy,
      timestamp: DateTime(2026, 8, 5, 9),
      source: source,
      isStale: stale,
    );
  }

  group('distanceMeters', () {
    test('matches known north-south ground truth', () {
      // 0.001° of latitude is ~111.19 m anywhere on the globe.
      final north = LatLng(
        latitude: base.latitude + 0.001,
        longitude: base.longitude,
      );
      expect(
        MeasureCalculator.distanceMeters(base, north),
        closeTo(111.19, 0.5),
      );
    });

    test('shrinks east-west distances by the cosine of latitude', () {
      final east = LatLng(
        latitude: base.latitude,
        longitude: base.longitude + 0.001,
      );
      // cos(10.8°) ≈ 0.9823 → ~109.2 m
      expect(
        MeasureCalculator.distanceMeters(base, east),
        closeTo(109.2, 0.5),
      );
    });

    test('is zero for identical points and symmetric otherwise', () {
      expect(MeasureCalculator.distanceMeters(base, base), 0);
      final other = LatLng(latitude: 10.81, longitude: 106.71);
      expect(
        MeasureCalculator.distanceMeters(base, other),
        closeTo(MeasureCalculator.distanceMeters(other, base), 1e-9),
      );
    });
  });

  group('combineUncertainty', () {
    test('adds independent errors in quadrature', () {
      expect(MeasureCalculator.combineUncertainty(3, 4), closeTo(5, 1e-9));
    });

    test('returns the larger error when the other is zero', () {
      expect(MeasureCalculator.combineUncertainty(7, 0), closeTo(7, 1e-9));
    });
  });

  group('single point from a GPS fix', () {
    test('produces one leg with the haversine distance', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(),
      );

      expect(result.legs, hasLength(1));
      expect(result.legs.single.kind, MeasureLegKind.fromGolfer);
      expect(result.legs.single.meters, closeTo(111.19, 0.5));
      expect(result.hasGolferOrigin, isTrue);
    });

    test('combines the GPS accuracy with the imagery tap uncertainty', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(accuracy: 12),
      );

      // sqrt(12² + 5²) = 13
      expect(result.legs.single.uncertaintyMeters, closeTo(13, 0.01));
    });

    test('treats a fix that reports no accuracy as a bad fix', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(accuracy: null),
      );

      expect(
        result.legs.single.uncertaintyMeters,
        greaterThan(MeasureCalculator.unknownGpsUncertaintyMeters),
      );
      expect(result.legs.single.quality, MeasureQuality.unusable);
      expect(result.gpsAccuracyMeters, isNull);
    });

    test('carries the stale flag through to the result', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(stale: true),
      );

      expect(result.gpsStale, isTrue);
      expect(result.needsWarning, isTrue);
    });
  });

  group('multi-point chains', () {
    test('chains legs golfer → p1 → p2 → p3', () {
      final result = calculator.compute(
        points: [
          pointAt(base.latitude + 0.001, base.longitude, id: 'a'),
          pointAt(base.latitude + 0.002, base.longitude, id: 'b'),
          pointAt(base.latitude + 0.003, base.longitude, id: 'c'),
        ],
        origin: fix(),
      );

      expect(result.legs, hasLength(3));
      expect(result.legs[0].kind, MeasureLegKind.fromGolfer);
      expect(result.legs[1].kind, MeasureLegKind.betweenPoints);
      expect(result.legs[2].kind, MeasureLegKind.betweenPoints);
      for (final leg in result.legs) {
        expect(leg.meters, closeTo(111.19, 0.5));
      }
      expect(result.totalMeters, closeTo(333.6, 1.5));
    });

    test('legs between two tapped points carry only tap uncertainty', () {
      final points = [
        pointAt(base.latitude + 0.001, base.longitude, id: 'a'),
        pointAt(base.latitude + 0.002, base.longitude, id: 'b'),
      ];
      final goodFix = calculator.compute(points: points, origin: fix());
      final terribleFix =
          calculator.compute(points: points, origin: fix(accuracy: 45));

      // sqrt(5² + 5²) ≈ 7.07 — no GPS error enters a point-to-point leg, so a
      // dreadful fix must not degrade it.
      expect(goodFix.legs[1].uncertaintyMeters, closeTo(7.07, 0.01));
      expect(
        terribleFix.legs[1].uncertaintyMeters,
        closeTo(goodFix.legs[1].uncertaintyMeters, 1e-9),
      );
      // The leg anchored to the GPS fix, by contrast, does degrade.
      expect(
        terribleFix.legs[0].uncertaintyMeters,
        greaterThan(goodFix.legs[0].uncertaintyMeters),
      );
    });

    test('total uncertainty grows with the number of legs', () {
      final twoLegs = calculator.compute(
        points: [
          pointAt(base.latitude + 0.001, base.longitude, id: 'a'),
          pointAt(base.latitude + 0.002, base.longitude, id: 'b'),
        ],
        origin: fix(),
      );
      final threeLegs = calculator.compute(
        points: [
          pointAt(base.latitude + 0.001, base.longitude, id: 'a'),
          pointAt(base.latitude + 0.002, base.longitude, id: 'b'),
          pointAt(base.latitude + 0.003, base.longitude, id: 'c'),
        ],
        origin: fix(),
      );

      expect(
        threeLegs.totalUncertaintyMeters,
        greaterThan(twoLegs.totalUncertaintyMeters),
      );
      // Root-sum-square of 6.40 and 7.07 ≈ 9.54.
      expect(twoLegs.totalUncertaintyMeters, closeTo(9.54, 0.05));
    });

    test('firstLeg exposes the distance from the golfer', () {
      final result = calculator.compute(
        points: [
          pointAt(base.latitude + 0.001, base.longitude, id: 'a'),
          pointAt(base.latitude + 0.002, base.longitude, id: 'b'),
        ],
        origin: fix(),
      );
      expect(result.firstLeg, same(result.legs.first));
    });
  });

  group('no usable GPS fix', () {
    test('drops the golfer leg but still measures between points', () {
      final result = calculator.compute(
        points: [
          pointAt(base.latitude + 0.001, base.longitude, id: 'a'),
          pointAt(base.latitude + 0.002, base.longitude, id: 'b'),
        ],
      );

      expect(result.hasGolferOrigin, isFalse);
      expect(result.legs, hasLength(1));
      expect(result.legs.single.kind, MeasureLegKind.betweenPoints);
    });

    test('an unavailable fix is treated as no fix at all', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(source: LocationSource.unavailable, accuracy: 2),
      );

      expect(result.hasGolferOrigin, isFalse);
      expect(result.legs, isEmpty);
    });

    test('no points at all is an empty result', () {
      final result = calculator.compute(points: const [], origin: fix());
      expect(result.isEmpty, isTrue);
      expect(result.totalMeters, 0);
      expect(result.totalUncertaintyMeters, 0);
    });
  });

  group('run-on to the green', () {
    final green = MeasureAnchor(
      position: LatLng(latitude: base.latitude + 0.003, longitude: 106.700000),
      isSurveyed: true,
    );

    test('measures from the last dropped point, not the golfer', () {
      final result = calculator.compute(
        points: [
          pointAt(base.latitude + 0.001, base.longitude, id: 'a'),
          pointAt(base.latitude + 0.002, base.longitude, id: 'b'),
        ],
        origin: fix(),
        green: green,
      );

      expect(result.greenLeg, isNotNull);
      expect(result.greenLeg!.kind, MeasureLegKind.toGreen);
      expect(result.greenLeg!.meters, closeTo(111.19, 0.5));
      expect(result.greenIsEstimated, isFalse);
    });

    test('totalWithGreenMeters adds the run-on, totalMeters does not', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(),
        green: green,
      );

      expect(result.totalMeters, closeTo(111.19, 0.5));
      expect(result.totalWithGreenMeters, closeTo(333.6, 1.5));
    });

    test('an estimated green is far less certain than a surveyed one', () {
      final surveyed = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(),
        green: green,
      );
      final estimated = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(),
        green: MeasureAnchor(position: green.position, isSurveyed: false),
      );

      expect(surveyed.greenLeg!.uncertaintyMeters,
          lessThan(estimated.greenLeg!.uncertaintyMeters));
      expect(estimated.greenIsEstimated, isTrue);
      // 830 of 900 holes land here — the number must not look authoritative.
      expect(estimated.greenLeg!.quality, MeasureQuality.unusable);
    });

    test('no green means no run-on leg', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(),
      );
      expect(result.greenLeg, isNull);
      expect(result.greenIsEstimated, isFalse);
    });

    test('a green with no dropped points produces nothing to run on from', () {
      final result = calculator.compute(
        points: const [],
        origin: fix(),
        green: green,
      );
      expect(result.greenLeg, isNull);
    });
  });

  group('quality and confidence', () {
    test('buckets uncertainty honestly', () {
      expect(MeasureQuality.forUncertainty(1), MeasureQuality.good);
      expect(MeasureQuality.forUncertainty(5), MeasureQuality.fair);
      expect(MeasureQuality.forUncertainty(15), MeasureQuality.poor);
      expect(MeasureQuality.forUncertainty(40), MeasureQuality.unusable);
    });

    test('confidence never increases as uncertainty grows', () {
      var previous = 1.0;
      for (final metres in [0.5, 2.9, 3.0, 7.9, 8.0, 20.0, 20.1, 100.0]) {
        final confidence = MeasureQuality.confidenceFor(metres);
        expect(confidence, lessThanOrEqualTo(previous));
        previous = confidence;
      }
    });

    test('result quality takes the worst leg, including the green run-on', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(accuracy: 2),
        green: MeasureAnchor(
          position: LatLng(latitude: base.latitude + 0.003, longitude: 106.7),
          isSurveyed: false,
        ),
      );

      expect(result.legs.single.quality, MeasureQuality.fair);
      expect(result.quality, MeasureQuality.unusable);
      expect(result.needsWarning, isTrue);
    });

    test('a good fix on a short chain needs no warning', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(accuracy: 3),
      );
      expect(result.quality, MeasureQuality.fair);
      expect(result.needsWarning, isFalse);
    });
  });

  group('toMeasurement adapter', () {
    test('never claims a measured point is official data', () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(),
      );
      final measurement = result.legs.single.toMeasurement();

      expect(measurement.source, DistanceSource.estimated);
      expect(measurement.valueMeters, result.legs.single.meters);
      expect(
        measurement.gpsAccuracyMeters,
        result.legs.single.uncertaintyMeters,
      );
    });

    test('a poor fix surfaces as low confidence in the shared value object',
        () {
      final result = calculator.compute(
        points: [pointAt(base.latitude + 0.001, base.longitude)],
        origin: fix(accuracy: 40),
      );
      final measurement = result.legs.single.toMeasurement();

      expect(measurement.confidenceLevel, ConfidenceLevel.veryLow);
      expect(measurement.isAccuracyPoor, isTrue);
    });
  });

  group('MeasureHitTester', () {
    test('touch radius shrinks as the map zooms in', () {
      final atZoom16 = MeasureHitTester.touchRadiusMeters(
        zoom: 16,
        latitude: 10.8,
      );
      final atZoom19 = MeasureHitTester.touchRadiusMeters(
        zoom: 19,
        latitude: 10.8,
      );

      expect(atZoom19, lessThan(atZoom16));
      // Halving per zoom level: three levels is a factor of eight.
      expect(atZoom16 / atZoom19, closeTo(8, 0.001));
    });

    test('metersPerPixel matches the web-mercator ground resolution', () {
      // At the equator, zoom 0, a 256 px tile spans the whole globe.
      expect(
        MeasureHitTester.metersPerPixel(zoom: 0, latitude: 0),
        closeTo(156543.03, 1),
      );
    });

    test('finds a point inside the threshold', () {
      final points = [
        pointAt(base.latitude, base.longitude, id: 'near'),
        pointAt(base.latitude + 0.01, base.longitude, id: 'far'),
      ];
      final hit = MeasureHitTester.findNearest(
        points: points,
        tap: LatLng(latitude: base.latitude + 0.00001, longitude: 106.7),
        thresholdMeters: 10,
      );
      expect(hit?.id, 'near');
    });

    test('returns the closest point when several are in range', () {
      final points = [
        pointAt(base.latitude + 0.00005, base.longitude, id: 'further'),
        pointAt(base.latitude + 0.00001, base.longitude, id: 'closest'),
      ];
      final hit = MeasureHitTester.findNearest(
        points: points,
        tap: base,
        thresholdMeters: 20,
      );
      expect(hit?.id, 'closest');
    });

    test('returns null when nothing is close enough', () {
      final hit = MeasureHitTester.findNearest(
        points: [pointAt(base.latitude + 0.01, base.longitude, id: 'far')],
        tap: base,
        thresholdMeters: 10,
      );
      expect(hit, isNull);
    });

    test('an empty map has nothing to hit', () {
      expect(
        MeasureHitTester.findNearest(
          points: const [],
          tap: base,
          thresholdMeters: 100,
        ),
        isNull,
      );
    });
  });
}
