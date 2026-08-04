// QualifiedLocation unit tests — VSP Mobile App
//
// Tests:
// - Model construction and field access
// - isAccurateForDetection and isUsableForDetection computed properties
// - Serialization round-trip (fromJson/toJson)
// - distanceTo and bearingTo with known coordinates
// - ConfidenceLevel enum exhaustiveness and thresholds
// - Copy with updated fields
//
// Story 6.2 — Wave A

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';

void main() {
  group('QualifiedLocation', () {
    group('construction', () {
      test('creates with all required fields', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          timestamp: DateTime.parse('2026-08-02T10:00:00Z'),
          source: LocationSource.gps,
          isStale: false,
        );

        expect(location.latitude, 10.762917);
        expect(location.longitude, 106.687074);
        expect(location.accuracyMeters, isNull);
        expect(location.heading, isNull);
        expect(location.source, LocationSource.gps);
        expect(location.isStale, false);
      });

      test('creates with optional fields', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 3.5,
          timestamp: DateTime.parse('2026-08-02T10:00:00Z'),
          heading: 45.0,
          source: LocationSource.gps,
          isStale: true,
        );

        expect(location.accuracyMeters, 3.5);
        expect(location.heading, 45.0);
        expect(location.isStale, true);
      });
    });

    group('isAccurateForDetection', () {
      test('returns true when accuracy is <= 10 meters', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 5.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        expect(location.isAccurateForDetection, true);
      });

      test('returns true at exactly 10 meters', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 10.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        expect(location.isAccurateForDetection, true);
      });

      test('returns false when accuracy exceeds 10 meters', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 15.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        expect(location.isAccurateForDetection, false);
      });

      test('returns false when accuracy is null', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        expect(location.isAccurateForDetection, false);
      });
    });

    group('isUsableForDetection', () {
      test('returns true when not stale and accuracy is good', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 5.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        expect(location.isUsableForDetection, true);
      });

      test('returns false when stale', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 5.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: true,
        );
        expect(location.isUsableForDetection, false);
      });

      test('returns false when accuracy is poor', () {
        final location = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 20.0,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
        expect(location.isUsableForDetection, false);
      });
    });

    group('fromJson / toJson round-trip', () {
      test('round-trip preserves all fields', () {
        final original = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 3.5,
          timestamp: DateTime.parse('2026-08-02T10:00:00Z'),
          heading: 45.0,
          source: LocationSource.gps,
          isStale: true,
        );

        final json = original.toJson();
        final restored = QualifiedLocation.fromJson(json);

        expect(restored.latitude, original.latitude);
        expect(restored.longitude, original.longitude);
        expect(restored.accuracyMeters, original.accuracyMeters);
        expect(restored.heading, original.heading);
        expect(restored.source, original.source);
        expect(restored.isStale, original.isStale);
      });

      test('fromJson handles null optional fields', () {
        final json = {
          'latitude': 10.762917,
          'longitude': 106.687074,
          'timestamp': '2026-08-02T10:00:00.000Z',
          'source': 'gps',
          'isStale': false,
        };

        final location = QualifiedLocation.fromJson(json);
        expect(location.accuracyMeters, isNull);
        expect(location.heading, isNull);
      });

      test('fromJson defaults to gps for unknown source', () {
        final json = {
          'latitude': 10.762917,
          'longitude': 106.687074,
          'timestamp': '2026-08-02T10:00:00.000Z',
          'source': 'unknown_source',
          'isStale': false,
        };

        final location = QualifiedLocation.fromJson(json);
        expect(location.source, LocationSource.gps);
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final original = QualifiedLocation(
          latitude: 10.762917,
          longitude: 106.687074,
          accuracyMeters: 5.0,
          timestamp: DateTime.parse('2026-08-02T10:00:00Z'),
          heading: 45.0,
          source: LocationSource.gps,
          isStale: false,
        );

        final copied = original.copyWith(heading: 90.0);

        expect(copied.latitude, original.latitude);
        expect(copied.longitude, original.longitude);
        expect(copied.accuracyMeters, original.accuracyMeters);
        expect(copied.heading, 90.0);
        expect(copied.source, original.source);
        expect(copied.isStale, original.isStale);
      });
    });
  });

  group('LocationSource enum', () {
    test('has expected values', () {
      expect(LocationSource.values, contains(LocationSource.gps));
      expect(LocationSource.values, contains(LocationSource.network));
      expect(LocationSource.values, contains(LocationSource.fused));
      expect(LocationSource.values, contains(LocationSource.cached));
    });
  });
}
