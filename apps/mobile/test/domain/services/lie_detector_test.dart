// Lie Detector Unit Tests — VSP Mobile App
//
// Tests:
//  - Lie detection from GPS coordinates
//  - OB detection
//  - Water hazard detection
//  - Bunker detection
//  - Green detection (putting vs on green)
//  - Fairway detection
//  - Rough detection (default)
//  - GPS accuracy confidence adjustment
//
// Story 10.3 — Slice 5: Validation + Testing

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/hazard_geometry.dart';
import 'package:vsp_mobile/domain/models/hole_geometry.dart';
import 'package:vsp_mobile/domain/models/shot.dart';
import 'package:vsp_mobile/domain/services/lie_detector.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

void main() {
  group('LieDetector', () {
    late LieDetector lieDetector;

    setUp(() {
      lieDetector = LieDetector();
    });

    group('detectLie', () {
      test('detects OB when ball is in OB area', () {
        final hole = _createHoleWithObArea([
          // OB area rectangle
          LatLng(latitude: 37.7750, longitude: -122.4200),
          LatLng(latitude: 37.7760, longitude: -122.4200),
          LatLng(latitude: 37.7760, longitude: -122.4190),
          LatLng(latitude: 37.7750, longitude: -122.4190),
        ]);

        // Ball in center of OB area
        final ballLocation = LatLng(latitude: 37.7755, longitude: -122.4195);

        final result = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.outOfBounds);
        expect(result.confidence, greaterThan(0.8));
        expect(result.reason, contains('OB'));
      });

      test('detects water hazard', () {
        final hole = _createHoleWithWaterHazard([
          LatLng(latitude: 37.7745, longitude: -122.4195),
          LatLng(latitude: 37.7755, longitude: -122.4195),
          LatLng(latitude: 37.7755, longitude: -122.4185),
          LatLng(latitude: 37.7745, longitude: -122.4185),
        ]);

        final ballLocation = LatLng(latitude: 37.7750, longitude: -122.4190);

        final result = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.water);
        expect(result.reason, contains('water'));
      });

      test('detects bunker', () {
        final hole = _createHoleWithBunker([
          LatLng(latitude: 37.7745, longitude: -122.4195),
          LatLng(latitude: 37.7750, longitude: -122.4195),
          LatLng(latitude: 37.7750, longitude: -122.4185),
          LatLng(latitude: 37.7745, longitude: -122.4185),
        ]);

        final ballLocation = LatLng(latitude: 37.7747, longitude: -122.4190);

        final result = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.bunker);
        expect(result.reason, contains('bunker'));
      });

      test('detects green when ball is on green polygon', () {
        final hole = _createHoleWithGreen([
          LatLng(latitude: 37.7740, longitude: -122.4200),
          LatLng(latitude: 37.7750, longitude: -122.4200),
          LatLng(latitude: 37.7750, longitude: -122.4190),
          LatLng(latitude: 37.7740, longitude: -122.4190),
        ], pinPosition: LatLng(latitude: 37.7745, longitude: -122.4195));

        // Ball on green (but not near pin)
        final ballLocation = LatLng(latitude: 37.7743, longitude: -122.4193);

        final result = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.green);
        expect(result.reason, contains('green'));
      });

      test('detects putt when ball is near pin', () {
        final hole = _createHoleWithGreen([
          LatLng(latitude: 37.7740, longitude: -122.4200),
          LatLng(latitude: 37.7750, longitude: -122.4200),
          LatLng(latitude: 37.7750, longitude: -122.4190),
          LatLng(latitude: 37.7740, longitude: -122.4190),
        ], pinPosition: LatLng(latitude: 37.7745, longitude: -122.4195));

        // Ball very near pin (within 5m)
        final ballLocation = LatLng(latitude: 37.7745, longitude: -122.4195);

        final result = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.putt);
        expect(result.reason, contains('putting'));
      });

      test('returns rough as default when not in any feature', () {
        final hole = _createBasicHole();

        // Ball location not in any feature
        final ballLocation = LatLng(latitude: 37.7800, longitude: -122.4100);

        final result = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.rough);
        expect(result.reason, contains('rough'));
      });
    });

    group('detectLieSimplified', () {
      test('detects putt for short distances', () {
        final start = LatLng(latitude: 37.7749, longitude: -122.4194);
        final end = LatLng(latitude: 37.7749, longitude: -122.4195);

        final result = lieDetector.detectLieSimplified(
          startLocation: start,
          endLocation: end,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.putt);
        expect(result.confidence, lessThan(0.6));
      });

      test('detects fairway for medium distances', () {
        final start = LatLng(latitude: 37.7749, longitude: -122.4194);
        final end = LatLng(latitude: 37.7760, longitude: -122.4200);

        final result = lieDetector.detectLieSimplified(
          startLocation: start,
          endLocation: end,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.fairway);
      });

      test('detects rough for long distances', () {
        final start = LatLng(latitude: 37.7749, longitude: -122.4194);
        final end = LatLng(latitude: 37.7800, longitude: -122.4300);

        final result = lieDetector.detectLieSimplified(
          startLocation: start,
          endLocation: end,
          gpsAccuracyMeters: 5.0,
        );

        expect(result.lie, ShotLie.rough);
      });
    });

    group('GPS accuracy confidence', () {
      test('high GPS accuracy yields higher confidence', () {
        final hole = _createBasicHole();
        final ballLocation = LatLng(latitude: 37.7800, longitude: -122.4100);

        final resultHighAccuracy = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 5.0,
        );

        final resultLowAccuracy = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 25.0,
        );

        expect(
          resultHighAccuracy.confidence,
          greaterThan(resultLowAccuracy.confidence),
        );
      });

      test('very low GPS accuracy yields minimum confidence', () {
        final hole = _createBasicHole();
        final ballLocation = LatLng(latitude: 37.7800, longitude: -122.4100);

        final result = lieDetector.detectLie(
          endLocation: ballLocation,
          hole: hole,
          gpsAccuracyMeters: 50.0,
        );

        expect(result.confidence, lessThan(0.5));
      });
    });
  });
}

// Helper functions to create test hole geometries

HoleGeometry _createBasicHole() {
  return HoleGeometry(
    holeNumber: 1,
    par: 4,
    greenPolygon: [
      LatLng(latitude: 37.7740, longitude: -122.4200),
      LatLng(latitude: 37.7750, longitude: -122.4200),
      LatLng(latitude: 37.7750, longitude: -122.4190),
      LatLng(latitude: 37.7740, longitude: -122.4190),
    ],
    pinPosition: LatLng(latitude: 37.7745, longitude: -122.4195),
    teeBox: LatLng(latitude: 37.7700, longitude: -122.4100),
    fairwayCenterline: [
      LatLng(latitude: 37.7700, longitude: -122.4100),
      LatLng(latitude: 37.7745, longitude: -122.4195),
    ],
    hazards: [],
    cartPaths: [],
    obAreas: [],
    landmarks: [],
  );
}

HoleGeometry _createHoleWithGreen(
  List<LatLng> greenPolygon, {
  required LatLng pinPosition,
}) {
  return HoleGeometry(
    holeNumber: 1,
    par: 4,
    greenPolygon: greenPolygon,
    pinPosition: pinPosition,
    teeBox: LatLng(latitude: 37.7700, longitude: -122.4100),
    fairwayCenterline: [
      LatLng(latitude: 37.7700, longitude: -122.4100),
      LatLng(latitude: 37.7745, longitude: -122.4195),
    ],
    hazards: [],
    cartPaths: [],
    obAreas: [],
    landmarks: [],
  );
}

HoleGeometry _createHoleWithBunker(List<LatLng> bunkerPolygon) {
  return HoleGeometry(
    holeNumber: 1,
    par: 4,
    greenPolygon: [
      LatLng(latitude: 37.7740, longitude: -122.4200),
      LatLng(latitude: 37.7750, longitude: -122.4200),
      LatLng(latitude: 37.7750, longitude: -122.4190),
      LatLng(latitude: 37.7740, longitude: -122.4190),
    ],
    pinPosition: LatLng(latitude: 37.7745, longitude: -122.4195),
    teeBox: LatLng(latitude: 37.7700, longitude: -122.4100),
    fairwayCenterline: [
      LatLng(latitude: 37.7700, longitude: -122.4100),
      LatLng(latitude: 37.7745, longitude: -122.4195),
    ],
    hazards: [
      HazardGeometry(
        id: 'bunker-1',
        type: HazardType.bunker,
        name: 'Bunker 1',
        polygon: bunkerPolygon,
        nearestPoint: bunkerPolygon.first,
        farthestPoint: bunkerPolygon.last,
      ),
    ],
    cartPaths: [],
    obAreas: [],
    landmarks: [],
  );
}

HoleGeometry _createHoleWithWaterHazard(List<LatLng> waterPolygon) {
  return HoleGeometry(
    holeNumber: 1,
    par: 4,
    greenPolygon: [
      LatLng(latitude: 37.7740, longitude: -122.4200),
      LatLng(latitude: 37.7750, longitude: -122.4200),
      LatLng(latitude: 37.7750, longitude: -122.4190),
      LatLng(latitude: 37.7740, longitude: -122.4190),
    ],
    pinPosition: LatLng(latitude: 37.7745, longitude: -122.4195),
    teeBox: LatLng(latitude: 37.7700, longitude: -122.4100),
    fairwayCenterline: [
      LatLng(latitude: 37.7700, longitude: -122.4100),
      LatLng(latitude: 37.7745, longitude: -122.4195),
    ],
    hazards: [
      HazardGeometry(
        id: 'water-1',
        type: HazardType.water,
        name: 'Water 1',
        polygon: waterPolygon,
        nearestPoint: waterPolygon.first,
        farthestPoint: waterPolygon.last,
      ),
    ],
    cartPaths: [],
    obAreas: [],
    landmarks: [],
  );
}

HoleGeometry _createHoleWithObArea(List<LatLng> obPolygon) {
  return HoleGeometry(
    holeNumber: 1,
    par: 4,
    greenPolygon: [
      LatLng(latitude: 37.7740, longitude: -122.4200),
      LatLng(latitude: 37.7750, longitude: -122.4200),
      LatLng(latitude: 37.7750, longitude: -122.4190),
      LatLng(latitude: 37.7740, longitude: -122.4190),
    ],
    pinPosition: LatLng(latitude: 37.7745, longitude: -122.4195),
    teeBox: LatLng(latitude: 37.7700, longitude: -122.4100),
    fairwayCenterline: [
      LatLng(latitude: 37.7700, longitude: -122.4100),
      LatLng(latitude: 37.7745, longitude: -122.4195),
    ],
    hazards: [],
    cartPaths: [],
    obAreas: [obPolygon],
    landmarks: [],
  );
}
