// Distance Cubit Tests — VSP Mobile App
//
// Story 6.4 — Wave 2: State Management
// Integration test: mock location + geometry → verify distance output

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/application/distance/distance_cubit.dart';
import 'package:vsp_mobile/application/distance/distance_state.dart';
import 'package:vsp_mobile/domain/models/hazard_geometry.dart';
import 'package:vsp_mobile/domain/models/hole_geometry.dart';
import 'package:vsp_mobile/domain/services/distance_calculator.dart';
import 'package:vsp_mobile/domain/value_objects/distance_measurement.dart';
import 'package:vsp_mobile/domain/value_objects/distance_type.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

void main() {
  group('DistanceCubit', () {
    late DistanceCalculator calculator;
    late StreamController<dynamic> locationController;
    late DistanceCubit cubit;

    // Sample hole geometry — par-4 hole with green, bunker, water
    late HoleGeometry sampleHole;

    setUp(() {
      calculator = DistanceCalculator();
      locationController = StreamController<dynamic>.broadcast();

      cubit = DistanceCubit(
        locationStream: locationController.stream,
        calculator: calculator,
        initialUnit: DistanceUnit.meters,
      );

      // Build a sample hole geometry
      sampleHole = _buildSampleHole();
    });

    tearDown(() {
      locationController.close();
      cubit.close();
    });

    test('initial state is idle', () {
      expect(cubit.state.status, DistanceStatus.idle);
      expect(cubit.state.greenDistances, isEmpty);
      expect(cubit.state.hazardDistances, isEmpty);
    });

    test('setHoleGeometry transitions to waitingForLocation', () {
      cubit.setHoleGeometry(sampleHole);
      expect(cubit.state.status, DistanceStatus.waitingForLocation);
      expect(cubit.state.holeGeometry, sampleHole);
    });

    test('setHoleGeometry with null transitions to noHoleGeometry', () {
      cubit.setHoleGeometry(null);
      expect(cubit.state.status, DistanceStatus.noHoleGeometry);
      expect(cubit.state.holeGeometry, isNull);
    });

    test('location update with position triggers calculation', () async {
      cubit.setHoleGeometry(sampleHole);

      // Send a location update
      final position = const LatLng(latitude: 10.0, longitude: 106.0);
      locationController.add({'position': position, 'accuracy': 5.0});

      // Wait for state update
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.status, DistanceStatus.ready);
      expect(cubit.state.golferPosition, position);
      expect(cubit.state.gpsAccuracyMeters, 5.0);
      expect(cubit.state.greenDistances.isNotEmpty, isTrue);
      expect(cubit.state.greenDistances[DistanceType.frontGreen], isNotNull);
      expect(cubit.state.greenDistances[DistanceType.centerGreen], isNotNull);
      expect(cubit.state.greenDistances[DistanceType.backGreen], isNotNull);
    });

    test(
      'location update with no position transitions to gpsUnavailable',
      () async {
        cubit.setHoleGeometry(sampleHole);

        // Send a null position
        locationController.add({'position': null, 'accuracy': null});

        await Future.delayed(const Duration(milliseconds: 50));

        expect(cubit.state.status, DistanceStatus.gpsUnavailable);
      },
    );

    test('green distances are calculated correctly', () async {
      cubit.setHoleGeometry(sampleHole);

      // Golfer is 100m from green center
      final position = _offsetMeters(
        _polygonCenter(sampleHole.greenPolygon),
        bearingDegrees: 180,
        distanceMeters: 100,
      );

      locationController.add({'position': position, 'accuracy': 3.0});
      await Future.delayed(const Duration(milliseconds: 50));

      final frontGreen = cubit.state.greenDistances[DistanceType.frontGreen];
      final centerGreen = cubit.state.greenDistances[DistanceType.centerGreen];
      final backGreen = cubit.state.greenDistances[DistanceType.backGreen];

      expect(frontGreen, isNotNull);
      expect(centerGreen, isNotNull);
      expect(backGreen, isNotNull);

      // Front green < center green < back green (golfer is 100m from center)
      expect(frontGreen!.valueMeters, lessThan(centerGreen!.valueMeters));
      expect(centerGreen.valueMeters, lessThan(backGreen!.valueMeters));

      // All should be reasonable (within 400m)
      expect(frontGreen.valueMeters, lessThan(400));
      expect(centerGreen.valueMeters, lessThan(400));
      expect(backGreen.valueMeters, lessThan(400));
    });

    test('hazard near/far distances are calculated', () async {
      cubit.setHoleGeometry(sampleHole);

      final position = const LatLng(latitude: 10.0, longitude: 106.0);
      locationController.add({'position': position, 'accuracy': 5.0});
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.hazardDistances.isNotEmpty, isTrue);
    });

    test('toggleUnit switches between meters and yards', () async {
      cubit.setHoleGeometry(sampleHole);

      expect(cubit.state.selectedUnit, DistanceUnit.meters);

      cubit.toggleUnit();
      expect(cubit.state.selectedUnit, DistanceUnit.yards);

      cubit.toggleUnit();
      expect(cubit.state.selectedUnit, DistanceUnit.meters);
    });

    test('setUnit sets unit explicitly', () {
      cubit.setUnit(DistanceUnit.yards);
      expect(cubit.state.selectedUnit, DistanceUnit.yards);

      cubit.setUnit(DistanceUnit.meters);
      expect(cubit.state.selectedUnit, DistanceUnit.meters);
    });

    test('setTarget adds target and target-to-pin distances', () async {
      cubit.setHoleGeometry(sampleHole);

      // Send location first
      final position = const LatLng(latitude: 10.0, longitude: 106.0);
      locationController.add({'position': position, 'accuracy': 5.0});
      await Future.delayed(const Duration(milliseconds: 50));

      // Place a target
      final targetPosition = const LatLng(latitude: 10.001, longitude: 106.001);
      cubit.setTarget(targetPosition);

      expect(cubit.state.targetDistance, isNotNull);
      expect(cubit.state.targetToPinDistance, isNotNull);
      expect(cubit.state.targetDistance!.type, DistanceType.target);
      expect(cubit.state.targetToPinDistance!.type, DistanceType.targetToPin);
    });

    test('clearTarget removes target distances', () async {
      cubit.setHoleGeometry(sampleHole);

      final position = const LatLng(latitude: 10.0, longitude: 106.0);
      locationController.add({'position': position, 'accuracy': 5.0});
      await Future.delayed(const Duration(milliseconds: 50));

      // Place and then clear target
      cubit.setTarget(const LatLng(latitude: 10.001, longitude: 106.001));
      expect(cubit.state.hasTarget, isTrue);

      cubit.clearTarget();
      expect(cubit.state.hasTarget, isFalse);
    });

    test(
      'aggregateConfidence returns minimum confidence across green distances',
      () async {
        cubit.setHoleGeometry(sampleHole);

        final position = const LatLng(latitude: 10.0, longitude: 106.0);
        locationController.add({'position': position, 'accuracy': 5.0});
        await Future.delayed(const Duration(milliseconds: 50));

        expect(cubit.state.aggregateConfidence, isNotNull);
        expect(cubit.state.aggregateConfidence, greaterThan(0));
        expect(cubit.state.aggregateConfidence, lessThanOrEqualTo(1.0));
      },
    );

    test('accuracyLevel is correct for different accuracy values', () async {
      cubit.setHoleGeometry(sampleHole);

      final position = const LatLng(latitude: 10.0, longitude: 106.0);

      // Test excellent accuracy (< 5m)
      locationController.add({'position': position, 'accuracy': 3.0});
      await Future.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.accuracyLevel, GpsAccuracyLevel.excellent);

      // Test good accuracy (5-10m)
      locationController.add({'position': position, 'accuracy': 7.0});
      await Future.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.accuracyLevel, GpsAccuracyLevel.good);

      // Test moderate accuracy (10-20m)
      locationController.add({'position': position, 'accuracy': 15.0});
      await Future.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.accuracyLevel, GpsAccuracyLevel.moderate);

      // Test poor accuracy (>= 20m)
      locationController.add({'position': position, 'accuracy': 25.0});
      await Future.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.accuracyLevel, GpsAccuracyLevel.poor);
    });

    test('OB distance is calculated when OB areas present', () async {
      // Hole with OB areas
      final holeWithOb = _buildHoleWithOb();
      cubit.setHoleGeometry(holeWithOb);

      final position = const LatLng(latitude: 10.0, longitude: 106.0);
      locationController.add({'position': position, 'accuracy': 5.0});
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.obDistance, isNotNull);
      expect(cubit.state.obDistance!.type, DistanceType.ob);
    });

    test('stop transitions to idle and cancels subscription', () async {
      cubit.setHoleGeometry(sampleHole);

      final position = const LatLng(latitude: 10.0, longitude: 106.0);
      locationController.add({'position': position, 'accuracy': 5.0});
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.status, DistanceStatus.ready);

      cubit.stop();
      expect(cubit.state.status, DistanceStatus.idle);
    });
  });

  group('DistanceState', () {
    test('initial factory creates idle state', () {
      final state = DistanceState.initial();
      expect(state.status, DistanceStatus.idle);
      expect(state.selectedUnit, DistanceUnit.meters);
    });

    test('copyWith preserves unchanged fields', () {
      final state = DistanceState.initial();
      final updated = state.copyWith(status: DistanceStatus.ready);
      expect(updated.status, DistanceStatus.ready);
      expect(updated.selectedUnit, DistanceUnit.meters);
    });

    test('hasGps returns true when position is present', () {
      final state = DistanceState(
        status: DistanceStatus.ready,
        golferPosition: const LatLng(latitude: 10.0, longitude: 106.0),
      );
      expect(state.hasGps, isTrue);
    });

    test('hasGps returns false when position is null', () {
      final state = DistanceState(status: DistanceStatus.gpsUnavailable);
      expect(state.hasGps, isFalse);
    });

    test('accuracyLevel returns correct level', () {
      final excellent = DistanceState(
        status: DistanceStatus.ready,
        gpsAccuracyMeters: 3.0,
      );
      expect(excellent.accuracyLevel, GpsAccuracyLevel.excellent);

      final good = DistanceState(
        status: DistanceStatus.ready,
        gpsAccuracyMeters: 7.0,
      );
      expect(good.accuracyLevel, GpsAccuracyLevel.good);

      final moderate = DistanceState(
        status: DistanceStatus.ready,
        gpsAccuracyMeters: 15.0,
      );
      expect(moderate.accuracyLevel, GpsAccuracyLevel.moderate);

      final poor = DistanceState(
        status: DistanceStatus.ready,
        gpsAccuracyMeters: 25.0,
      );
      expect(poor.accuracyLevel, GpsAccuracyLevel.poor);
    });

    test('aggregateConfidence returns min of green distances', () {
      final state = DistanceState(
        status: DistanceStatus.ready,
        greenDistances: {
          DistanceType.frontGreen: _dm(0.8),
          DistanceType.centerGreen: _dm(0.9),
          DistanceType.backGreen: _dm(0.7),
        },
      );
      expect(state.aggregateConfidence, 0.7);
    });
  });
}

// ─── Test helpers ───────────────────────────────────────────────────────────

HoleGeometry _buildSampleHole() {
  // Simple rectangular green — ~33m x 33m (realistic green size).
  const greenPolygon = [
    LatLng(latitude: 10.0, longitude: 106.0),
    LatLng(latitude: 10.0003, longitude: 106.0),
    LatLng(latitude: 10.0003, longitude: 106.0003),
    LatLng(latitude: 10.0, longitude: 106.0003),
  ];

  // Bunker near green
  final bunker = HazardGeometry(
    id: 'bunker-1',
    type: HazardType.bunker,
    name: 'Bunker Left',
    polygon: const [
      LatLng(latitude: 9.999, longitude: 105.999),
      LatLng(latitude: 9.9995, longitude: 105.9995),
      LatLng(latitude: 9.999, longitude: 105.9995),
      LatLng(latitude: 9.999, longitude: 105.999),
    ],
    nearestPoint: const LatLng(latitude: 9.999, longitude: 105.999),
    farthestPoint: const LatLng(latitude: 9.9995, longitude: 105.9995),
  );

  // Water hazard
  final water = HazardGeometry(
    id: 'water-1',
    type: HazardType.water,
    name: 'Water Right',
    polygon: const [
      LatLng(latitude: 10.0015, longitude: 106.0015),
      LatLng(latitude: 10.002, longitude: 106.0015),
      LatLng(latitude: 10.002, longitude: 106.002),
      LatLng(latitude: 10.0015, longitude: 106.002),
    ],
    nearestPoint: const LatLng(latitude: 10.0015, longitude: 106.0015),
    farthestPoint: const LatLng(latitude: 10.002, longitude: 106.002),
  );

  return HoleGeometry(
    holeNumber: 1,
    par: 4,
    greenPolygon: greenPolygon,
    pinPosition: const LatLng(latitude: 10.0005, longitude: 106.0005),
    teeBox: const LatLng(latitude: 9.998, longitude: 105.998),
    fairwayCenterline: const [
      LatLng(latitude: 9.998, longitude: 105.998),
      LatLng(latitude: 10.0, longitude: 106.0),
      LatLng(latitude: 10.0005, longitude: 106.0005),
    ],
    hazards: [bunker, water],
  );
}

HoleGeometry _buildHoleWithOb() {
  const greenPolygon = [
    LatLng(latitude: 10.0, longitude: 106.0),
    LatLng(latitude: 10.001, longitude: 106.0),
    LatLng(latitude: 10.001, longitude: 106.001),
    LatLng(latitude: 10.0, longitude: 106.001),
  ];

  return HoleGeometry(
    holeNumber: 2,
    par: 4,
    greenPolygon: greenPolygon,
    pinPosition: const LatLng(latitude: 10.0005, longitude: 106.0005),
    teeBox: const LatLng(latitude: 9.998, longitude: 105.998),
    fairwayCenterline: const [
      LatLng(latitude: 9.998, longitude: 105.998),
      LatLng(latitude: 10.0, longitude: 106.0),
      LatLng(latitude: 10.0005, longitude: 106.0005),
    ],
    obAreas: const [
      [
        LatLng(latitude: 10.002, longitude: 106.002),
        LatLng(latitude: 10.003, longitude: 106.002),
        LatLng(latitude: 10.003, longitude: 106.003),
        LatLng(latitude: 10.002, longitude: 106.003),
      ],
    ],
  );
}

/// Create a DistanceMeasurement with only confidence for testing.
DistanceMeasurement _dm(double confidence) {
  return DistanceMeasurement(
    valueMeters: 100,
    type: DistanceType.frontGreen,
    source: DistanceSource.official,
    timestamp: DateTime.now(),
    gpsAccuracyMeters: 5,
    confidence: confidence,
  );
}

/// Calculate the centroid of a polygon.
LatLng _polygonCenter(List<LatLng> polygon) {
  double sumLat = 0;
  double sumLon = 0;
  for (final p in polygon) {
    sumLat += p.latitude;
    sumLon += p.longitude;
  }
  return LatLng(
    latitude: sumLat / polygon.length,
    longitude: sumLon / polygon.length,
  );
}

/// Offset a LatLng by [distanceMeters] in direction [bearingDegrees].
LatLng _offsetMeters(
  LatLng origin, {
  required double bearingDegrees,
  required double distanceMeters,
}) {
  const earthRadiusM = 6371000.0;
  final bearingRad = bearingDegrees * math.pi / 180;
  final lat1 = origin.latitude * math.pi / 180;
  final lon1 = origin.longitude * math.pi / 180;
  final dR = distanceMeters / earthRadiusM;

  // Destination-point formula (great-circle).
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(dR) +
        math.cos(lat1) * math.sin(dR) * math.cos(bearingRad),
  );
  final lon2 =
      lon1 +
      math.atan2(
        math.sin(bearingRad) * math.sin(dR) * math.cos(lat1),
        math.cos(dR) - math.sin(lat1) * math.sin(lat2),
      );

  return LatLng(
    latitude: lat2 * 180 / math.pi,
    longitude: lon2 * 180 / math.pi,
  );
}
