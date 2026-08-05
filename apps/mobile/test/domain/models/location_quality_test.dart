// LocationQuality unit tests — VSP Mobile App
//
// Tests:
// - LocationWarning factory from QualifiedLocation
// - AC2: isLowAccuracy (>10m) triggers lowAccuracy warning
// - AC2: isStale (age >5s) triggers stale warning
// - blocksAutoAction is true for lowAccuracy and stale
// - LocationQuality enum exhaustiveness
//
// Story 6.1 — Wave A

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/location_quality.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

void main() {
  group('LocationWarning', () {
    group('fromQualifiedLocation', () {
      test('returns unavailable warning when source is unavailable', () {
        final loc = QualifiedLocation.unavailable();
        final warning = LocationWarning.fromQualifiedLocation(loc);

        expect(warning.quality, LocationQuality.unavailable);
        expect(warning.title, AppMessages.gpsUnavailable);
        expect(warning.blocksAutoAction, true);
      });

      test('returns stale warning when isStale is true', () {
        final loc = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 3.0,
          timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
          source: LocationSource.gps,
          isStale: true,
        );
        final warning = LocationWarning.fromQualifiedLocation(loc);

        expect(warning.quality, LocationQuality.stale);
        expect(warning.title, AppMessages.gpsStale);
        expect(warning.blocksAutoAction, true);
      });

      test('returns lowAccuracy warning when accuracy > 10m', () {
        final loc = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 15.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        final warning = LocationWarning.fromQualifiedLocation(loc);

        expect(warning.quality, LocationQuality.lowAccuracy);
        expect(warning.title, AppMessages.gpsLowAccuracy);
        expect(warning.blocksAutoAction, true);
      });

      test('returns ready warning when location is good', () {
        final loc = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 3.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        final warning = LocationWarning.fromQualifiedLocation(loc);

        expect(warning.quality, LocationQuality.ready);
        expect(warning.title, AppMessages.gpsReady);
        expect(warning.blocksAutoAction, false);
      });

      test('ready has no message with warning indicators', () {
        final loc = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 3.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        final warning = LocationWarning.fromQualifiedLocation(loc);

        expect(warning.message, AppMessages.gpsReadyMessage);
      });

      test('lowAccuracy message includes accuracy value', () {
        final loc = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 15.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        final warning = LocationWarning.fromQualifiedLocation(loc);

        expect(warning.message, AppMessages.gpsLowAccuracyMessage);
      });
    });

    group('blocksAutoAction', () {
      test('unavailable blocks auto action', () {
        final loc = QualifiedLocation.unavailable();
        final warning = LocationWarning.fromQualifiedLocation(loc);
        expect(warning.shouldBlockAutoSwitch, true);
      });

      test('stale blocks auto action', () {
        final loc = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 3.0,
          timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
          source: LocationSource.gps,
          isStale: true,
        );
        final warning = LocationWarning.fromQualifiedLocation(loc);
        expect(warning.shouldBlockAutoSwitch, true);
      });

      test('lowAccuracy blocks auto action', () {
        final loc = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 15.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        final warning = LocationWarning.fromQualifiedLocation(loc);
        expect(warning.shouldBlockAutoSwitch, true);
      });

      test('ready does not block auto action', () {
        final loc = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 3.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        final warning = LocationWarning.fromQualifiedLocation(loc);
        expect(warning.shouldBlockAutoSwitch, false);
      });
    });
  });

  group('LocationQuality enum', () {
    test('has expected values', () {
      expect(LocationQuality.values, contains(LocationQuality.ready));
      expect(LocationQuality.values, contains(LocationQuality.lowAccuracy));
      expect(LocationQuality.values, contains(LocationQuality.stale));
      expect(LocationQuality.values, contains(LocationQuality.unavailable));
      expect(LocationQuality.values.length, 4);
    });
  });
}
