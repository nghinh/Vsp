// Distance Calculator Unit Tests — VSP Mobile App
//
// Tests for Haversine, polygon distance, and carry calculations.
//
// Story 6.4 — Wave 1: Domain & Calculation Engine

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/hazard_geometry.dart';
import 'package:vsp_mobile/domain/models/hole_geometry.dart';
import 'package:vsp_mobile/domain/services/distance_calculator.dart';
import 'package:vsp_mobile/domain/value_objects/distance_measurement.dart';
import 'package:vsp_mobile/domain/value_objects/distance_type.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

void main() {
  group('LatLng — Haversine distance', () {
    test('distance between same point is zero', () {
      const p = LatLng(latitude: 10.0, longitude: 106.0);
      expect(p.distanceTo(p), 0);
    });

    test('known distance: ~111km per degree of latitude', () {
      const north = LatLng(latitude: 0.0, longitude: 0.0);
      const south = LatLng(latitude: -1.0, longitude: 0.0);
      final distKm = north.distanceTo(south) / 1000;
      // 1 degree latitude ≈ 111km
      expect(distKm, closeTo(111.0, 1.0));
    });

    test('known distance: ~111km per degree of latitude (north)', () {
      const north = LatLng(latitude: 0.0, longitude: 0.0);
      const south = LatLng(latitude: 1.0, longitude: 0.0);
      final distKm = north.distanceTo(south) / 1000;
      expect(distKm, closeTo(111.0, 1.0));
    });

    test('known distance: Ho Chi Minh City to Hanoi (~1145km great-circle)', () {
      // Ho Chi Minh City: ~10.76°N, 106.70°E
      // Hanoi: ~21.03°N, 105.85°E
      const hcmc = LatLng(latitude: 10.7624, longitude: 106.6845);
      const hanoi = LatLng(latitude: 21.0285, longitude: 105.8542);
      final distKm = hcmc.distanceTo(hanoi) / 1000;
      expect(distKm, closeTo(1145.0, 30.0));
    });

    test('distance is symmetric', () {
      const a = LatLng(latitude: 10.0, longitude: 106.0);
      const b = LatLng(latitude: 21.0, longitude: 105.0);
      expect(a.distanceTo(b), closeTo(b.distanceTo(a), 0.001));
    });

    test('isValid returns true for valid coordinates', () {
      const valid = LatLng(latitude: 45.0, longitude: 90.0);
      expect(valid.isValid, isTrue);
    });

    test('isValid returns false for out-of-range coordinates', () {
      const invalidLat = LatLng(latitude: 91.0, longitude: 0.0);
      expect(invalidLat.isValid, isFalse);

      const invalidLon = LatLng(latitude: 0.0, longitude: 181.0);
      expect(invalidLon.isValid, isFalse);
    });

    test('fromGeoJson parses [lon, lat] array', () {
      final p = LatLng.fromGeoJson([106.5, 10.25]);
      expect(p.longitude, 106.5);
      expect(p.latitude, 10.25);
    });

    test('toGeoJson produces [lon, lat] array', () {
      const p = LatLng(latitude: 10.25, longitude: 106.5);
      expect(p.toGeoJson(), [106.5, 10.25]);
    });
  });

  group('DistanceCalculator — green distances', () {
    late DistanceCalculator calculator;
    late HoleGeometry hole;
    late LatLng golferPosition;
    late DateTime timestamp;

    setUp(() {
      calculator = DistanceCalculator();
      timestamp = DateTime.now();

      // Create a simple rectangular green:
      // 20m wide x 30m long, centered near origin
      // Green vertices (closed polygon):
      // (0,0) -> (20,0) -> (20,30) -> (0,30) -> (0,0)
      hole = HoleGeometry(
        holeNumber: 1,
        par: 4,
        greenPolygon: const [
          LatLng(latitude: 0.0, longitude: 0.0),
          LatLng(latitude: 0.0, longitude: 0.00018), // ~20m east
          LatLng(latitude: 0.00027, longitude: 0.00018), // ~30m north
          LatLng(latitude: 0.00027, longitude: 0.0),
          LatLng(latitude: 0.0, longitude: 0.0), // closed
        ],
        pinPosition: const LatLng(latitude: 0.000135, longitude: 0.00009), // center
        teeBox: const LatLng(latitude: 0.0, longitude: 0.0),
        fairwayCenterline: const [
          LatLng(latitude: 0.0, longitude: 0.0),
          LatLng(latitude: 0.000135, longitude: 0.00009),
        ],
      );

      // Golfer is 100m short of the green
      // 100m ≈ 0.0009 degrees latitude
      golferPosition = const LatLng(latitude: -0.0009, longitude: 0.00009);
    });

    test('calculates front green distance', () {
      final distances = calculator.calculateGreenDistances(
        golferPosition: golferPosition,
        hole: hole,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(distances[DistanceType.frontGreen], isNotNull);
      final frontGreen = distances[DistanceType.frontGreen]!;

      // 100m to green front edge
      expect(frontGreen.valueMeters, closeTo(100.0, 15.0));
      expect(frontGreen.type, DistanceType.frontGreen);
      expect(frontGreen.source, DistanceSource.official);
      expect(frontGreen.gpsAccuracyMeters, 3.0);
      expect(frontGreen.confidence, greaterThan(0.5));
    });

    test('calculates center green distance', () {
      final distances = calculator.calculateGreenDistances(
        golferPosition: golferPosition,
        hole: hole,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(distances[DistanceType.centerGreen], isNotNull);
      final centerGreen = distances[DistanceType.centerGreen]!;

      // ~115m (100m + ~15m to center from front)
      expect(centerGreen.valueMeters, greaterThan(90.0));
      expect(centerGreen.valueMeters, lessThan(140.0));
      expect(centerGreen.type, DistanceType.centerGreen);
    });

    test('calculates back green distance', () {
      final distances = calculator.calculateGreenDistances(
        golferPosition: golferPosition,
        hole: hole,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(distances[DistanceType.backGreen], isNotNull);
      final backGreen = distances[DistanceType.backGreen]!;

      // ~130m (100m + ~30m green depth)
      expect(backGreen.valueMeters, greaterThan(120.0));
      expect(backGreen.type, DistanceType.backGreen);
    });

    test('calculates pin distance', () {
      final distances = calculator.calculateGreenDistances(
        golferPosition: golferPosition,
        hole: hole,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(distances[DistanceType.pin], isNotNull);
      final pin = distances[DistanceType.pin]!;

      // ~115m to pin at center
      expect(pin.valueMeters, greaterThan(100.0));
      expect(pin.valueMeters, lessThan(140.0));
      expect(pin.type, DistanceType.pin);
    });

    test('back green >= center green >= front green', () {
      final distances = calculator.calculateGreenDistances(
        golferPosition: golferPosition,
        hole: hole,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      final front = distances[DistanceType.frontGreen]!.valueMeters;
      final center = distances[DistanceType.centerGreen]!.valueMeters;
      final back = distances[DistanceType.backGreen]!.valueMeters;

      expect(back, greaterThanOrEqualTo(center));
      expect(center, greaterThanOrEqualTo(front));
    });

    test('returns empty map for invalid green', () {
      final invalidHole = HoleGeometry(
        holeNumber: 1,
        par: 4,
        greenPolygon: const [LatLng(latitude: 0, longitude: 0)], // too few
        pinPosition: const LatLng(latitude: 0, longitude: 0),
        teeBox: const LatLng(latitude: 0, longitude: 0),
        fairwayCenterline: const [],
      );

      final distances = calculator.calculateGreenDistances(
        golferPosition: golferPosition,
        hole: invalidHole,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(distances, isEmpty);
    });

    test('lower GPS accuracy reduces confidence', () {
      final goodGps = calculator.calculateGreenDistances(
        golferPosition: golferPosition,
        hole: hole,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      final poorGps = calculator.calculateGreenDistances(
        golferPosition: golferPosition,
        hole: hole,
        gpsAccuracyMeters: 15.0,
        timestamp: timestamp,
      );

      final goodConf = goodGps[DistanceType.frontGreen]!.confidence;
      final poorConf = poorGps[DistanceType.frontGreen]!.confidence;

      expect(goodConf, greaterThan(poorConf));
    });
  });

  group('DistanceCalculator — hazard distances', () {
    late DistanceCalculator calculator;
    late DateTime timestamp;
    late List<HazardGeometry> hazards;

    setUp(() {
      calculator = DistanceCalculator();
      timestamp = DateTime.now();

      // Bunker: small rectangle ~15m x 10m
      // 0,0 -> 0.000135,0 -> 0.000135,0.00009 -> 0,0.00009 -> 0,0
      const bunkerPolygon = [
        LatLng(latitude: 0.0, longitude: 0.0),
        LatLng(latitude: 0.0, longitude: 0.000135),
        LatLng(latitude: 0.00009, longitude: 0.000135),
        LatLng(latitude: 0.00009, longitude: 0.0),
        LatLng(latitude: 0.0, longitude: 0.0),
      ];

      hazards = [
        HazardGeometry(
          id: 'bunker-1',
          type: HazardType.bunker,
          name: 'Bunker 1',
          polygon: bunkerPolygon,
          nearestPoint: const LatLng(latitude: 0.0, longitude: 0.0),
          farthestPoint: const LatLng(latitude: 0.00009, longitude: 0.000135),
        ),
      ];
    });

    test('calculates bunker near distance', () {
      // Golfer 50m north of bunker
      const golfer = LatLng(latitude: -0.00045, longitude: 0.000067);
      final hole = _makeHoleWithHazards(hazards);

      final result = calculator.calculateHazardDistances(
        golferPosition: golfer,
        hazards: hazards,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
        hole: hole,
      );

      final near = result['bunker-1']![DistanceType.bunkerNear]!;
      expect(near.valueMeters, closeTo(50.0, 10.0));
      expect(near.type, DistanceType.bunkerNear);
    });

    test('calculates bunker far distance', () {
      const golfer = LatLng(latitude: -0.00045, longitude: 0.000067);
      final hole = _makeHoleWithHazards(hazards);

      final result = calculator.calculateHazardDistances(
        golferPosition: golfer,
        hazards: hazards,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
        hole: hole,
      );

      final far = result['bunker-1']![DistanceType.bunkerFar]!;
      expect(far.valueMeters, greaterThanOrEqualTo(0));
      expect(far.type, DistanceType.bunkerFar);
    });

    test('far distance >= near distance', () {
      const golfer = LatLng(latitude: -0.00045, longitude: 0.000067);
      final hole = _makeHoleWithHazards(hazards);

      final result = calculator.calculateHazardDistances(
        golferPosition: golfer,
        hazards: hazards,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
        hole: hole,
      );

      final near = result['bunker-1']![DistanceType.bunkerNear]!.valueMeters;
      final far = result['bunker-1']![DistanceType.bunkerFar]!.valueMeters;

      expect(far, greaterThanOrEqualTo(near));
    });

    test('returns empty map for empty hazards', () {
      const golfer = LatLng(latitude: 0, longitude: 0);
      final hole = _makeHoleWithHazards([]);

      final result = calculator.calculateHazardDistances(
        golferPosition: golfer,
        hazards: [],
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
        hole: hole,
      );

      expect(result, isEmpty);
    });

    test('water hazard uses waterNear/waterFar types', () {
      const waterPolygon = [
        LatLng(latitude: 0.0, longitude: 0.0),
        LatLng(latitude: 0.0, longitude: 0.0002),
        LatLng(latitude: 0.00015, longitude: 0.0002),
        LatLng(latitude: 0.00015, longitude: 0.0),
        LatLng(latitude: 0.0, longitude: 0.0),
      ];

      final waterHazard = HazardGeometry(
        id: 'water-1',
        type: HazardType.water,
        name: 'Water Hole 3',
        polygon: waterPolygon,
        nearestPoint: const LatLng(latitude: 0.0, longitude: 0.0),
        farthestPoint: const LatLng(latitude: 0.00015, longitude: 0.0002),
      );

      const golfer = LatLng(latitude: -0.00045, longitude: 0.0001);
      final hole = _makeHoleWithHazards([waterHazard]);

      final result = calculator.calculateHazardDistances(
        golferPosition: golfer,
        hazards: [waterHazard],
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
        hole: hole,
      );

      expect(result['water-1']!.containsKey(DistanceType.waterNear), isTrue);
      expect(result['water-1']!.containsKey(DistanceType.waterFar), isTrue);
    });
  });

  group('DistanceCalculator — target distances', () {
    late DistanceCalculator calculator;
    late DateTime timestamp;

    setUp(() {
      calculator = DistanceCalculator();
      timestamp = DateTime.now();
    });

    test('calculates target distance', () {
      const golfer = LatLng(latitude: 0.0, longitude: 0.0);
      const target = LatLng(latitude: 0.0009, longitude: 0.0); // ~100m north

      final result = calculator.calculateTargetDistance(
        golferPosition: golfer,
        targetPosition: target,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(result.valueMeters, closeTo(100.0, 10.0));
      expect(result.type, DistanceType.target);
      expect(result.source, DistanceSource.official);
    });

    test('calculates target-to-pin distance', () {
      const target = LatLng(latitude: 0.0009, longitude: 0.0);
      const pin = LatLng(latitude: 0.0018, longitude: 0.0); // ~100m beyond target

      final result = calculator.calculateTargetToPinDistance(
        targetPosition: target,
        pinPosition: pin,
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(result.valueMeters, closeTo(100.0, 10.0));
      expect(result.type, DistanceType.targetToPin);
    });
  });

  group('DistanceCalculator — OB distances', () {
    late DistanceCalculator calculator;
    late DateTime timestamp;

    setUp(() {
      calculator = DistanceCalculator();
      timestamp = DateTime.now();
    });

    test('calculates OB distance', () {
      const obArea = [
        LatLng(latitude: 0.0, longitude: 0.0),
        LatLng(latitude: 0.0, longitude: 0.001),
        LatLng(latitude: 0.001, longitude: 0.001),
        LatLng(latitude: 0.001, longitude: 0.0),
        LatLng(latitude: 0.0, longitude: 0.0),
      ];

      const golfer = LatLng(latitude: -0.0005, longitude: 0.0005);

      final result = calculator.calculateObDistance(
        golferPosition: golfer,
        obAreas: [obArea],
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(result, isNotNull);
      expect(result!.type, DistanceType.ob);
      // ~55m south of the OB boundary
      expect(result.valueMeters, closeTo(55.0, 15.0));
    });

    test('returns null for empty OB areas', () {
      const golfer = LatLng(latitude: 0, longitude: 0);

      final result = calculator.calculateObDistance(
        golferPosition: golfer,
        obAreas: [],
        gpsAccuracyMeters: 3.0,
        timestamp: timestamp,
      );

      expect(result, isNull);
    });
  });

  group('DistanceMeasurement — unit conversion', () {
    test('meters to yards conversion', () {
      // 100m ≈ 109.361 yards
      const measurement = DistanceMeasurement(
        valueMeters: 100.0,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 3.0,
        confidence: 0.95,
      );

      expect(measurement.valueYards, closeTo(109.36, 0.1));
    });

    test('formatMeters returns integer string', () {
      const m = DistanceMeasurement(
        valueMeters: 152.6,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 3.0,
        confidence: 0.95,
      );

      expect(m.formatMeters(), '153 m');
    });

    test('formatYards returns integer string', () {
      const m = DistanceMeasurement(
        valueMeters: 100.0,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 3.0,
        confidence: 0.95,
      );

      expect(m.formatYards(), '109 yd');
    });

    test('displayValue uses correct unit', () {
      const m = DistanceMeasurement(
        valueMeters: 100.0,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 3.0,
        confidence: 0.95,
      );

      expect(m.displayValue(useYards: false), 100.0);
      expect(m.displayValue(useYards: true), closeTo(109.36, 0.1));
    });
  });

  group('DistanceMeasurement — GPS accuracy levels', () {
    test('excellent accuracy < 5m', () {
      const m = DistanceMeasurement(
        valueMeters: 100,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 3.0,
        confidence: 0.95,
      );

      expect(m.accuracyLevel, GpsAccuracyLevel.excellent);
      expect(m.isAccurate, isTrue);
      expect(m.hasAccuracyWarning, isFalse);
    });

    test('good accuracy 5-10m', () {
      const m = DistanceMeasurement(
        valueMeters: 100,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 7.0,
        confidence: 0.8,
      );

      expect(m.accuracyLevel, GpsAccuracyLevel.good);
      expect(m.isAccurate, isTrue);
      expect(m.hasAccuracyWarning, isFalse);
    });

    test('moderate accuracy 10-20m', () {
      const m = DistanceMeasurement(
        valueMeters: 100,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 15.0,
        confidence: 0.6,
      );

      expect(m.accuracyLevel, GpsAccuracyLevel.moderate);
      expect(m.isAccurate, isFalse);
      expect(m.hasAccuracyWarning, isTrue);
      expect(m.isAccuracyPoor, isFalse);
    });

    test('poor accuracy >= 20m', () {
      const m = DistanceMeasurement(
        valueMeters: 100,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 25.0,
        confidence: 0.3,
      );

      expect(m.accuracyLevel, GpsAccuracyLevel.poor);
      expect(m.hasAccuracyWarning, isTrue);
      expect(m.isAccuracyPoor, isTrue);
    });
  });

  group('DistanceMeasurement — confidence levels', () {
    test('high confidence >= 0.9', () {
      const m = DistanceMeasurement(
        valueMeters: 100,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 3.0,
        confidence: 0.95,
      );

      expect(m.confidenceLevel, ConfidenceLevel.high);
    });

    test('medium confidence 0.7-0.89', () {
      const m = DistanceMeasurement(
        valueMeters: 100,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 5.0,
        confidence: 0.8,
      );

      expect(m.confidenceLevel, ConfidenceLevel.medium);
    });

    test('low confidence 0.5-0.69', () {
      const m = DistanceMeasurement(
        valueMeters: 100,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 10.0,
        confidence: 0.6,
      );

      expect(m.confidenceLevel, ConfidenceLevel.low);
    });

    test('very low confidence < 0.5', () {
      const m = DistanceMeasurement(
        valueMeters: 100,
        type: DistanceType.pin,
        source: DistanceSource.official,
        timestamp: null,
        gpsAccuracyMeters: 20.0,
        confidence: 0.3,
      );

      expect(m.confidenceLevel, ConfidenceLevel.veryLow);
    });
  });

  group('DistanceType — category helpers', () {
    test('isGreen returns true for green types', () {
      expect(DistanceType.frontGreen.isGreen, isTrue);
      expect(DistanceType.centerGreen.isGreen, isTrue);
      expect(DistanceType.backGreen.isGreen, isTrue);
      expect(DistanceType.pin.isGreen, isTrue);
    });

    test('isBunker returns true for bunker types', () {
      expect(DistanceType.bunkerNear.isBunker, isTrue);
      expect(DistanceType.bunkerFar.isBunker, isTrue);
      expect(DistanceType.bunkerCarry.isBunker, isTrue);
      expect(DistanceType.waterNear.isBunker, isFalse);
    });

    test('isWater returns true for water types', () {
      expect(DistanceType.waterNear.isWater, isTrue);
      expect(DistanceType.waterFar.isWater, isTrue);
      expect(DistanceType.waterCarry.isWater, isTrue);
      expect(DistanceType.bunkerNear.isWater, isFalse);
    });

    test('isCarry returns true for carry types', () {
      expect(DistanceType.bunkerCarry.isCarry, isTrue);
      expect(DistanceType.waterCarry.isCarry, isTrue);
      expect(DistanceType.bunkerNear.isCarry, isFalse);
    });

    test('isTarget returns true for target types', () {
      expect(DistanceType.target.isTarget, isTrue);
      expect(DistanceType.targetToPin.isTarget, isTrue);
      expect(DistanceType.pin.isTarget, isFalse);
    });
  });

  group('HazardGeometry — computed properties', () {
    test('isValid true for polygon with 3+ vertices', () {
      const hazard = HazardGeometry(
        id: 'test',
        type: HazardType.bunker,
        name: 'Test',
        polygon: [
          LatLng(latitude: 0, longitude: 0),
          LatLng(latitude: 1, longitude: 0),
          LatLng(latitude: 1, longitude: 1),
          LatLng(latitude: 0, longitude: 1),
        ],
        nearestPoint: LatLng(latitude: 0, longitude: 0),
        farthestPoint: LatLng(latitude: 1, longitude: 1),
      );

      expect(hazard.isValid, isTrue);
      expect(hazard.vertexCount, 4);
    });

    test('isValid false for polygon with < 3 vertices', () {
      const hazard = HazardGeometry(
        id: 'test',
        type: HazardType.bunker,
        name: 'Test',
        polygon: [
          LatLng(latitude: 0, longitude: 0),
          LatLng(latitude: 1, longitude: 0),
        ],
        nearestPoint: LatLng(latitude: 0, longitude: 0),
        farthestPoint: LatLng(latitude: 1, longitude: 0),
      );

      expect(hazard.isValid, isFalse);
    });

    test('hazard type helpers work', () {
      const bunker = HazardGeometry(
        id: 'b1',
        type: HazardType.bunker,
        name: 'Bunker',
        polygon: [],
        nearestPoint: LatLng(latitude: 0, longitude: 0),
        farthestPoint: LatLng(latitude: 0, longitude: 0),
      );

      const water = HazardGeometry(
        id: 'w1',
        type: HazardType.water,
        name: 'Water',
        polygon: [],
        nearestPoint: LatLng(latitude: 0, longitude: 0),
        farthestPoint: LatLng(latitude: 0, longitude: 0),
      );

      const ob = HazardGeometry(
        id: 'o1',
        type: HazardType.ob,
        name: 'OB',
        polygon: [],
        nearestPoint: LatLng(latitude: 0, longitude: 0),
        farthestPoint: LatLng(latitude: 0, longitude: 0),
      );

      expect(bunker.isBunker, isTrue);
      expect(bunker.isWater, isFalse);
      expect(bunker.isOb, isFalse);

      expect(water.isBunker, isFalse);
      expect(water.isWater, isTrue);
      expect(water.isOb, isFalse);

      expect(ob.isBunker, isFalse);
      expect(ob.isWater, isFalse);
      expect(ob.isOb, isTrue);
    });
  });

  group('HoleGeometry — computed properties', () {
    test('hasValidGreen true for polygon with 3+ vertices', () {
      final hole = HoleGeometry(
        holeNumber: 1,
        par: 4,
        greenPolygon: const [
          LatLng(latitude: 0, longitude: 0),
          LatLng(latitude: 0, longitude: 1),
          LatLng(latitude: 1, longitude: 1),
        ],
        pinPosition: const LatLng(latitude: 0.5, longitude: 0.5),
        teeBox: const LatLng(latitude: 0, longitude: 0),
        fairwayCenterline: const [],
      );

      expect(hole.hasValidGreen, isTrue);
    });

    test('hasValidGreen false for polygon with < 3 vertices', () {
      final hole = HoleGeometry(
        holeNumber: 1,
        par: 4,
        greenPolygon: const [
          LatLng(latitude: 0, longitude: 0),
          LatLng(latitude: 0, longitude: 1),
        ],
        pinPosition: const LatLng(latitude: 0, longitude: 1),
        teeBox: const LatLng(latitude: 0, longitude: 0),
        fairwayCenterline: const [],
      );

      expect(hole.hasValidGreen, isFalse);
    });

    test('bunkers returns only bunker hazards', () {
      final hole = HoleGeometry(
        holeNumber: 1,
        par: 4,
        greenPolygon: const [
          LatLng(latitude: 0, longitude: 0),
          LatLng(latitude: 0, longitude: 1),
          LatLng(latitude: 1, longitude: 1),
        ],
        pinPosition: const LatLng(latitude: 0.5, longitude: 0.5),
        teeBox: const LatLng(latitude: 0, longitude: 0),
        fairwayCenterline: const [],
        hazards: [
          HazardGeometry(
            id: 'b1',
            type: HazardType.bunker,
            name: 'Bunker',
            polygon: const [],
            nearestPoint: LatLng(latitude: 0, longitude: 0),
            farthestPoint: LatLng(latitude: 0, longitude: 0),
          ),
          HazardGeometry(
            id: 'w1',
            type: HazardType.water,
            name: 'Water',
            polygon: const [],
            nearestPoint: LatLng(latitude: 0, longitude: 0),
            farthestPoint: LatLng(latitude: 0, longitude: 0),
          ),
        ],
      );

      expect(hole.bunkers.length, 1);
      expect(hole.bunkers.first.id, 'b1');
      expect(hole.waterHazards.length, 1);
      expect(hole.waterHazards.first.id, 'w1');
    });
  });
}

// ─── Test helpers ─────────────────────────────────────────────────────────────

/// Create a test hole with hazards.
HoleGeometry _makeHoleWithHazards(List<HazardGeometry> hazards) {
  return HoleGeometry(
    holeNumber: 1,
    par: 4,
    greenPolygon: const [
      LatLng(latitude: 0.001, longitude: 0.0),
      LatLng(latitude: 0.001, longitude: 0.0018),
      LatLng(latitude: 0.0013, longitude: 0.0018),
      LatLng(latitude: 0.0013, longitude: 0.0),
      LatLng(latitude: 0.001, longitude: 0.0),
    ],
    pinPosition: const LatLng(latitude: 0.00115, longitude: 0.0009),
    teeBox: const LatLng(latitude: 0.0, longitude: 0.0009),
    fairwayCenterline: const [
      LatLng(latitude: 0.0, longitude: 0.0009),
      LatLng(latitude: 0.00115, longitude: 0.0009),
    ],
    hazards: hazards,
  );
}
