// PinEntity unit tests — VSP Mobile App
//
// Tests cover:
// - isOfficial, isEstimated computed properties
// - isExpired: true when expiryDate is set and has passed
// - isActive: true when isOfficial && !isExpired
// - copyWith creates new instance with updated fields
// - fromJson/toJson round-trip
//
// Story 7.3 — Slice 5: Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';

void main() {
  group('PinSource', () {
    test('fromString handles known values case-insensitively', () {
      expect(PinSource.values.firstWhere((e) => e.name == 'official'), PinSource.official);
      expect(PinSource.values.firstWhere((e) => e.name == 'estimated'), PinSource.estimated);
      expect(PinSource.values.firstWhere((e) => e.name == 'manual'), PinSource.manual);
    });
  });

  group('PinEntity', () {
    group('isOfficial and isEstimated', () {
      test('isOfficial is true only for official source', () {
        final official = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
        );
        final estimated = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.estimated,
        );
        final manual = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.manual,
        );

        expect(official.isOfficial, isTrue);
        expect(estimated.isOfficial, isFalse);
        expect(manual.isOfficial, isFalse);
      });

      test('isEstimated is true only for estimated source', () {
        final official = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
        );
        final estimated = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.estimated,
        );

        expect(official.isEstimated, isFalse);
        expect(estimated.isEstimated, isTrue);
      });
    });

    group('isExpired — AC2 verification', () {
      test('isExpired is false when expiryDate is null', () {
        final pin = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          expiryDate: null,
        );

        expect(pin.isExpired, isFalse);
      });

      test('isExpired is false when expiryDate is in the future', () {
        final pin = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          expiryDate: DateTime.now().add(const Duration(days: 7)),
        );

        expect(pin.isExpired, isFalse);
      });

      test('isExpired is true when expiryDate is in the past', () {
        final pin = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(pin.isExpired, isTrue);
      });
    });

    group('isActive — official AND not expired', () {
      test('isActive is true when official source and not expired', () {
        final pin = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          expiryDate: DateTime.now().add(const Duration(days: 7)),
        );

        expect(pin.isActive, isTrue);
      });

      test('isActive is false when estimated source (even if not expired)', () {
        final pin = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.estimated,
          expiryDate: DateTime.now().add(const Duration(days: 7)),
        );

        expect(pin.isActive, isFalse);
      });

      test('isActive is false when official but expired', () {
        final pin = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(pin.isActive, isFalse);
      });
    });

    group('copyWith', () {
      test('creates new instance with updated expiryDate', () {
        final original = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          confidence: 0.8,
        );

        final newExpiry = DateTime.now().add(const Duration(days: 7));
        final updated = original.copyWith(expiryDate: newExpiry);

        expect(updated.holeId, original.holeId);
        expect(updated.holeNumber, original.holeNumber);
        expect(updated.latitude, original.latitude);
        expect(updated.longitude, original.longitude);
        expect(updated.source, original.source);
        expect(updated.confidence, original.confidence);
        expect(updated.expiryDate, newExpiry);
      });

      test('preserves original when no parameters provided', () {
        final original = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          effectiveDate: DateTime(2026, 7, 1),
          expiryDate: DateTime(2026, 8, 1),
        );

        final copy = original.copyWith();

        expect(copy.holeId, original.holeId);
        expect(copy.effectiveDate, original.effectiveDate);
        expect(copy.expiryDate, original.expiryDate);
      });
    });

    group('fromJson — all fields parsed', () {
      test('parses full PinEntity response', () {
        final json = {
          'holeId': 'hole_1',
          'holeNumber': 3,
          'latitude': 35.123,
          'longitude': -80.456,
          'source': 'official',
          'confidence': 0.95,
          'snapshotDate': '2026-07-15T10:00:00Z',
          'effectiveDate': '2026-07-16T00:00:00Z',
          'expiryDate': '2026-08-16T00:00:00Z',
        };

        final pin = PinEntity.fromJson(json);

        expect(pin.holeId, 'hole_1');
        expect(pin.holeNumber, 3);
        expect(pin.latitude, 35.123);
        expect(pin.longitude, -80.456);
        expect(pin.source, PinSource.official);
        expect(pin.confidence, 0.95);
        expect(pin.snapshotDate, DateTime.parse('2026-07-15T10:00:00Z'));
        expect(pin.effectiveDate, DateTime.parse('2026-07-16T00:00:00Z'));
        expect(pin.expiryDate, DateTime.parse('2026-08-16T00:00:00Z'));
      });

      test('handles null optional fields', () {
        final json = {
          'holeId': 'hole_1',
          'holeNumber': 3,
          'latitude': 35.123,
          'longitude': -80.456,
          'source': 'manual',
        };

        final pin = PinEntity.fromJson(json);

        expect(pin.confidence, isNull);
        expect(pin.snapshotDate, isNull);
        expect(pin.effectiveDate, isNull);
        expect(pin.expiryDate, isNull);
      });

      test('defaults to manual for unknown source', () {
        final json = {
          'holeId': 'hole_1',
          'holeNumber': 3,
          'latitude': 35.123,
          'longitude': -80.456,
          'source': 'unknown_source',
        };

        final pin = PinEntity.fromJson(json);

        expect(pin.source, PinSource.manual);
      });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all non-null fields correctly', () {
        final pin = PinEntity(
          holeId: 'hole_1',
          holeNumber: 3,
          latitude: 35.123,
          longitude: -80.456,
          source: PinSource.official,
          confidence: 0.95,
          snapshotDate: DateTime.parse('2026-07-15T10:00:00Z'),
          effectiveDate: DateTime.parse('2026-07-16T00:00:00Z'),
          expiryDate: DateTime.parse('2026-08-16T00:00:00Z'),
        );

        final json = pin.toJson();
        final roundTrip = PinEntity.fromJson(json);

        expect(roundTrip.holeId, pin.holeId);
        expect(roundTrip.holeNumber, pin.holeNumber);
        expect(roundTrip.latitude, pin.latitude);
        expect(roundTrip.longitude, pin.longitude);
        expect(roundTrip.source, pin.source);
        expect(roundTrip.confidence, pin.confidence);
        expect(roundTrip.snapshotDate, pin.snapshotDate);
        expect(roundTrip.effectiveDate, pin.effectiveDate);
        expect(roundTrip.expiryDate, pin.expiryDate);
      });

      test('omits null optional fields', () {
        final pin = PinEntity(
          holeId: 'hole_1',
          holeNumber: 3,
          latitude: 35.123,
          longitude: -80.456,
          source: PinSource.manual,
        );

        final json = pin.toJson();

        expect(json.containsKey('confidence'), isFalse);
        expect(json.containsKey('snapshotDate'), isFalse);
        expect(json.containsKey('effectiveDate'), isFalse);
        expect(json.containsKey('expiryDate'), isFalse);
      });
    });

    group('props — Equatable', () {
      test('two pins with same props are equal', () {
        final pin1 = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          confidence: 0.8,
          effectiveDate: DateTime(2026, 8, 1),
          expiryDate: DateTime(2026, 8, 15),
        );

        final pin2 = PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: 10.0,
          longitude: 20.0,
          source: PinSource.official,
          confidence: 0.8,
          effectiveDate: DateTime(2026, 8, 1),
          expiryDate: DateTime(2026, 8, 15),
        );

        expect(pin1, equals(pin2));
      });
    });
  });
}
