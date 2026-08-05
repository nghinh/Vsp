// MeasureCubit Unit Tests — VSP Mobile App
//
// Tests cover:
// - Tap to add a point, tap the same marker to remove it
// - Undo / clear
// - Unit toggling without touching canonical metres
// - GPS fixes arriving from a LocationService and recomputing the result

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Minimal LocationService stub driven by the test.
class _FakeLocationService implements LocationService {
  final _controller = StreamController<QualifiedLocation>.broadcast();
  QualifiedLocation? _last;
  bool started = false;
  bool stopped = false;

  @override
  Stream<QualifiedLocation> get locationStream => _controller.stream;

  @override
  QualifiedLocation? get lastLocation => _last;

  void emit(QualifiedLocation location) {
    _last = location;
    _controller.add(location);
  }

  @override
  Future<QualifiedLocation> getCurrentLocation() async =>
      _last ?? QualifiedLocation.unavailable();

  @override
  void start() => started = true;

  @override
  void stop() => stopped = true;

  @override
  Future<bool> isLocationAvailable() async => true;

  @override
  Duration get stationaryInterval => const Duration(seconds: 30);

  @override
  Duration get activeInterval => const Duration(seconds: 5);

  @override
  void dispose() => _controller.close();
}

void main() {
  const base = LatLng(latitude: 10.8, longitude: 106.7);

  QualifiedLocation fix({double accuracy = 4}) => QualifiedLocation(
    latitude: base.latitude,
    longitude: base.longitude,
    accuracyMeters: accuracy,
    timestamp: DateTime(2026, 8, 5, 9),
    source: LocationSource.gps,
    isStale: false,
  );

  group('dropping and removing points', () {
    test('a tap on empty map drops a point', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 10,
      );

      expect(cubit.state.points, hasLength(1));
      expect(cubit.state.result.legs, hasLength(1));
    });

    test('a tap on an existing marker removes it', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      const target = LatLng(latitude: 10.801, longitude: 106.7);
      cubit.handleTap(target, hitThresholdMeters: 10);
      expect(cubit.state.points, hasLength(1));

      // A finger lands a metre or two off the marker it meant to hit.
      cubit.handleTap(
        const LatLng(latitude: 10.801005, longitude: 106.7),
        hitThresholdMeters: 10,
      );

      expect(cubit.state.points, isEmpty);
      expect(cubit.state.result.isEmpty, isTrue);
    });

    test('a tap outside the threshold drops another point instead', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 5,
      );
      cubit.handleTap(
        const LatLng(latitude: 10.802, longitude: 106.7),
        hitThresholdMeters: 5,
      );

      expect(cubit.state.points, hasLength(2));
      expect(cubit.state.result.legs, hasLength(2));
    });

    test('points keep the order they were tapped in', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      for (final lat in [10.801, 10.802, 10.803]) {
        cubit.handleTap(
          LatLng(latitude: lat, longitude: 106.7),
          hitThresholdMeters: 1,
        );
      }

      expect(
        cubit.state.points.map((p) => p.position.latitude),
        [10.801, 10.802, 10.803],
      );
    });

    test('removing a middle point re-chains the remaining legs', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      for (final lat in [10.801, 10.802, 10.803]) {
        cubit.handleTap(
          LatLng(latitude: lat, longitude: 106.7),
          hitThresholdMeters: 1,
        );
      }
      final middle = cubit.state.points[1];
      cubit.removePoint(middle.id);

      expect(cubit.state.points, hasLength(2));
      expect(cubit.state.result.legs, hasLength(2));
      // The gap closed: golfer → 10.801 → 10.803.
      expect(cubit.state.result.legs.last.to.latitude, 10.803);
    });

    test('removing an unknown id changes nothing', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 1,
      );
      final before = cubit.state;
      cubit.removePoint('not-a-real-id');

      expect(cubit.state, same(before));
    });
  });

  group('undo and clear', () {
    test('undo drops the most recent point only', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      for (final lat in [10.801, 10.802]) {
        cubit.handleTap(
          LatLng(latitude: lat, longitude: 106.7),
          hitThresholdMeters: 1,
        );
      }
      cubit.undo();

      expect(cubit.state.points, hasLength(1));
      expect(cubit.state.points.single.position.latitude, 10.801);
    });

    test('undo on an empty tool is a no-op', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      final before = cubit.state;
      cubit.undo();

      expect(cubit.state, same(before));
    });

    test('clear removes everything', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      for (final lat in [10.801, 10.802]) {
        cubit.handleTap(
          LatLng(latitude: lat, longitude: 106.7),
          hitThresholdMeters: 1,
        );
      }
      cubit.clear();

      expect(cubit.state.points, isEmpty);
      expect(cubit.state.result.isEmpty, isTrue);
    });
  });

  group('units', () {
    test('toggling flips between metres and yards', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      expect(cubit.state.unit, DistanceUnit.meters);
      cubit.toggleUnit();
      expect(cubit.state.unit, DistanceUnit.yards);
      cubit.toggleUnit();
      expect(cubit.state.unit, DistanceUnit.meters);
    });

    test('changing the unit never changes canonical metres', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 1,
      );
      final metres = cubit.state.result.totalMeters;
      cubit.setUnit(DistanceUnit.yards);

      expect(cubit.state.result.totalMeters, metres);
    });

    test('honours the golfer preference it was constructed with', () {
      final cubit = MeasureCubit(unit: DistanceUnit.yards);
      addTearDown(cubit.close);

      expect(cubit.state.unit, DistanceUnit.yards);
    });
  });

  group('GPS origin', () {
    test('starts the location service and takes its last known fix', () {
      final service = _FakeLocationService();
      addTearDown(service.dispose);
      service.emit(fix());

      final cubit = MeasureCubit(locationService: service);
      addTearDown(cubit.close);

      expect(service.started, isTrue);
      expect(cubit.state.hasNoFix, isFalse);
    });

    test('recomputes when a fresh fix arrives', () async {
      final service = _FakeLocationService();
      addTearDown(service.dispose);

      final cubit = MeasureCubit(locationService: service);
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 1,
      );
      expect(cubit.state.result.hasGolferOrigin, isFalse);

      service.emit(fix());
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.result.hasGolferOrigin, isTrue);
      expect(cubit.state.result.legs.first.meters, closeTo(111.19, 0.5));
    });

    test('a weak fix is flagged rather than quietly used', () {
      final cubit = MeasureCubit(initialOrigin: fix(accuracy: 30));
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 1,
      );

      expect(cubit.state.fixIsWeak, isTrue);
      expect(cubit.state.result.needsWarning, isTrue);
    });

    test('with no location service at all, the tool still measures', () {
      final cubit = MeasureCubit();
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 1,
      );
      cubit.handleTap(
        const LatLng(latitude: 10.802, longitude: 106.7),
        hitThresholdMeters: 1,
      );

      expect(cubit.state.hasNoFix, isTrue);
      expect(cubit.state.result.legs, hasLength(1));
      expect(cubit.state.result.legs.single.meters, closeTo(111.19, 0.5));
    });

    test('closing unsubscribes from the location stream', () async {
      final service = _FakeLocationService();
      addTearDown(service.dispose);

      final cubit = MeasureCubit(locationService: service);
      await cubit.close();

      // Emitting after close must not throw on a closed cubit.
      service.emit(fix());
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('green anchor', () {
    test('setGreen adds the run-on leg to an existing measurement', () {
      final cubit = MeasureCubit(initialOrigin: fix());
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 1,
      );
      expect(cubit.state.result.greenLeg, isNull);

      cubit.setGreen(
        const MeasureAnchor(
          position: LatLng(latitude: 10.803, longitude: 106.7),
          isSurveyed: true,
        ),
      );

      expect(cubit.state.result.greenLeg, isNotNull);
      expect(cubit.state.result.greenLeg!.meters, closeTo(222.4, 1.0));
    });

    test('setGreen(null) removes the run-on leg', () {
      final cubit = MeasureCubit(
        initialOrigin: fix(),
        green: const MeasureAnchor(
          position: LatLng(latitude: 10.803, longitude: 106.7),
          isSurveyed: true,
        ),
      );
      addTearDown(cubit.close);

      cubit.handleTap(
        const LatLng(latitude: 10.801, longitude: 106.7),
        hitThresholdMeters: 1,
      );
      expect(cubit.state.result.greenLeg, isNotNull);

      cubit.setGreen(null);

      expect(cubit.state.green, isNull);
      expect(cubit.state.result.greenLeg, isNull);
    });
  });
}
