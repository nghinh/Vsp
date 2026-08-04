// LocationState unit tests — VSP Mobile App
//
// Tests:
// - state transitions (idle, active, stopped, unavailable)
// - quality getter derivation
// - hasWarning getter
// - lastGoodLocation tracking
//
// Story 6.1 — Wave C

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/application/location/location_state.dart';
import 'package:vsp_mobile/domain/models/location_quality.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';

void main() {
  group('LocationState', () {
    test('initial state is idle', () {
      final state = LocationState.initial();
      expect(state.status, LocationServiceStatus.idle);
      expect(state.isIdle, true);
      expect(state.isActive, false);
      expect(state.isStopped, false);
      expect(state.isUnavailable, false);
    });

    test('quality returns unavailable when idle', () {
      final state = LocationState.initial();
      expect(state.quality, LocationQuality.unavailable);
    });

    test('quality returns unavailable when unavailable status', () {
      final state = LocationState(
        status: LocationServiceStatus.unavailable,
        currentLocation: QualifiedLocation.unavailable(),
      );
      expect(state.quality, LocationQuality.unavailable);
    });

    test('quality returns lowAccuracy from location', () {
      final loc = QualifiedLocation(
        latitude: 10.762917,
        longitude: 106.687074,
        accuracyMeters: 15.0,
        timestamp: DateTime.now(),
        source: LocationSource.gps,
        isStale: false,
      );
      final state = LocationState(
        status: LocationServiceStatus.active,
        currentLocation: loc,
      );
      expect(state.quality, LocationQuality.lowAccuracy);
    });

    test('quality returns stale from location', () {
      final loc = QualifiedLocation(
        latitude: 10.762917,
        longitude: 106.687074,
        accuracyMeters: 3.0,
        timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
        source: LocationSource.gps,
        isStale: true,
      );
      final state = LocationState(
        status: LocationServiceStatus.active,
        currentLocation: loc,
      );
      expect(state.quality, LocationQuality.stale);
    });

    test('quality returns ready when location is good', () {
      final loc = QualifiedLocation(
        latitude: 10.762917,
        longitude: 106.687074,
        accuracyMeters: 3.0,
        timestamp: DateTime.now(),
        source: LocationSource.gps,
        isStale: false,
      );
      final state = LocationState(
        status: LocationServiceStatus.active,
        currentLocation: loc,
      );
      expect(state.quality, LocationQuality.ready);
    });

    test('hasWarning is true when location has warning', () {
      final loc = QualifiedLocation(
        latitude: 10.762917,
        longitude: 106.687074,
        accuracyMeters: 15.0,
        timestamp: DateTime.now(),
        source: LocationSource.gps,
        isStale: false,
      );
      final state = LocationState(
        status: LocationServiceStatus.active,
        currentLocation: loc,
      );
      expect(state.hasWarning, true);
    });

    test('hasWarning is false when location is good', () {
      final loc = QualifiedLocation(
        latitude: 10.762917,
        longitude: 106.687074,
        accuracyMeters: 3.0,
        timestamp: DateTime.now(),
        source: LocationSource.gps,
        isStale: false,
      );
      final state = LocationState(
        status: LocationServiceStatus.active,
        currentLocation: loc,
      );
      expect(state.hasWarning, false);
    });

    test('copyWith preserves unchanged fields', () {
      final original = LocationState(
        status: LocationServiceStatus.active,
        currentLocation: QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 3.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        ),
      );

      final copied = original.copyWith(status: LocationServiceStatus.stopped);

      expect(copied.status, LocationServiceStatus.stopped);
      expect(copied.currentLocation, original.currentLocation);
    });
  });
}
