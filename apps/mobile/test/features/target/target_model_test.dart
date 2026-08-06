// Target Model Unit Tests — VSP Mobile App
//
// Tests cover:
// - TargetModel.placed() factory creates target with correct fields
// - TargetModel.moveTo() creates moved copy with updated fields
// - TargetModel.fromRow() parses SQLite row correctly
// - TargetModel.toRow() produces correct SQLite row
// - TargetModel.fromJson() / toJson() round-trip correctly
// - GpsAccuracy and TargetSource enums parse correctly
// - position getter returns [lon, lat]
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/target/domain/target_model.dart';

void main() {
  group('TargetModel', () {
    group('TargetModel.placed factory', () {
      test('creates target with tap source and current timestamps', () {
        final target = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );

        expect(target.id, 'target_r1_h1_uuid1');
        expect(target.roundId, 'round-1');
        expect(target.holeNumber, 1);
        expect(target.position, [106.6294, 10.7629]);
        expect(target.accuracy, GpsAccuracy.high);
        expect(target.source, TargetSource.tap);
        expect(target.placedAt, isNotNull);
        expect(target.updatedAt, isNotNull);
        expect(target.placedAt, target.updatedAt);
      });

      test('position longitude and latitude accessors work', () {
        final target = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 5,
          position: [106.8000, 10.8500],
          accuracy: GpsAccuracy.medium,
        );

        expect(target.longitude, 106.8000);
        expect(target.latitude, 10.8500);
      });
    });

    group('TargetModel.moveTo', () {
      test('creates new instance with new position and drag source', () {
        final original = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 3,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );

        // Wait a tiny bit so updatedAt differs
        final moved = original.moveTo(
          newPosition: [106.6400, 10.7700],
          newAccuracy: GpsAccuracy.medium,
        );

        expect(moved.id, original.id);
        expect(moved.roundId, original.roundId);
        expect(moved.holeNumber, original.holeNumber);
        expect(moved.position, [106.6400, 10.7700]);
        expect(moved.accuracy, GpsAccuracy.medium);
        expect(moved.source, TargetSource.drag);
        expect(moved.placedAt, original.placedAt);
        expect(moved.updatedAt.isAfter(original.updatedAt) ||
               moved.updatedAt.isAtSameMomentAs(original.updatedAt), isTrue);
      });

      test('moveTo does not mutate original instance', () {
        final original = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 2,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );
        final originalPos = original.position;

        original.moveTo(
          newPosition: [106.6400, 10.7700],
          newAccuracy: GpsAccuracy.medium,
        );

        expect(original.position, originalPos);
        expect(original.source, TargetSource.tap);
      });
    });

    group('TargetModel.fromRow / toRow', () {
      test('fromRow parses SQLite row correctly', () {
        final row = {
          'id': 'target_r1_h1_uuid1',
          'round_id': 'round-1',
          'hole_number': 7,
          'longitude': 106.6294,
          'latitude': 10.7629,
          'accuracy': 'medium',
          'source': 'tap',
          'placed_at': '2026-08-02T10:00:00.000Z',
          'updated_at': '2026-08-02T10:01:00.000Z',
        };

        final target = TargetModel.fromRow(row);

        expect(target.id, 'target_r1_h1_uuid1');
        expect(target.roundId, 'round-1');
        expect(target.holeNumber, 7);
        expect(target.longitude, 106.6294);
        expect(target.latitude, 10.7629);
        expect(target.accuracy, GpsAccuracy.medium);
        expect(target.source, TargetSource.tap);
        expect(target.placedAt.year, 2026);
        expect(target.updatedAt.year, 2026);
      });

      test('toRow produces correct SQLite row', () {
        final target = TargetModel(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 9,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.low,
          source: TargetSource.drag,
          placedAt: DateTime.utc(2026, 8, 2, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 8, 2, 10, 1, 0),
        );

        final row = target.toRow();

        expect(row['id'], 'target_r1_h1_uuid1');
        expect(row['round_id'], 'round-1');
        expect(row['hole_number'], 9);
        expect(row['longitude'], 106.6294);
        expect(row['latitude'], 10.7629);
        expect(row['accuracy'], 'low');
        expect(row['source'], 'drag');
        expect(row['placed_at'], '2026-08-02T10:00:00.000Z');
        expect(row['updated_at'], '2026-08-02T10:01:00.000Z');
      });

      test('fromRow handles unknown accuracy gracefully', () {
        final row = {
          'id': 'target_r1_h1_uuid1',
          'round_id': 'round-1',
          'hole_number': 1,
          'longitude': 106.6294,
          'latitude': 10.7629,
          'accuracy': 'garbage',
          'source': 'tap',
          'placed_at': '2026-08-02T10:00:00.000Z',
          'updated_at': '2026-08-02T10:00:00.000Z',
        };

        final target = TargetModel.fromRow(row);
        expect(target.accuracy, GpsAccuracy.unknown);
      });

      test('fromRow handles unknown source gracefully', () {
        final row = {
          'id': 'target_r1_h1_uuid1',
          'round_id': 'round-1',
          'hole_number': 1,
          'longitude': 106.6294,
          'latitude': 10.7629,
          'accuracy': 'high',
          'source': 'unknown_source',
          'placed_at': '2026-08-02T10:00:00.000Z',
          'updated_at': '2026-08-02T10:00:00.000Z',
        };

        final target = TargetModel.fromRow(row);
        expect(target.source, TargetSource.tap);
      });

      test('fromRow / toRow round-trip is lossless', () {
        final original = TargetModel(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 18,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
          source: TargetSource.restored,
          placedAt: DateTime.utc(2026, 8, 2, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 8, 2, 10, 5, 0),
        );

        final restored = TargetModel.fromRow(original.toRow());

        expect(restored, original);
      });
    });

    group('TargetModel.fromJson / toJson', () {
      test('fromJson parses API-style JSON correctly', () {
        final json = {
          'id': 'target_r1_h1_uuid1',
          'roundId': 'round-1',
          'holeNumber': 10,
          'position': {'longitude': 106.6294, 'latitude': 10.7629},
          'accuracy': 'high',
          'source': 'tap',
          'placedAt': '2026-08-02T10:00:00.000Z',
          'updatedAt': '2026-08-02T10:01:00.000Z',
        };

        final target = TargetModel.fromJson(json);

        expect(target.id, 'target_r1_h1_uuid1');
        expect(target.roundId, 'round-1');
        expect(target.holeNumber, 10);
        expect(target.longitude, 106.6294);
        expect(target.latitude, 10.7629);
        expect(target.accuracy, GpsAccuracy.high);
        expect(target.source, TargetSource.tap);
      });

      test('toJson produces correct JSON', () {
        final target = TargetModel(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 12,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.medium,
          source: TargetSource.tap,
          placedAt: DateTime.utc(2026, 8, 2, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 8, 2, 10, 1, 0),
        );

        final json = target.toJson();

        expect(json['id'], 'target_r1_h1_uuid1');
        expect(json['roundId'], 'round-1');
        expect(json['holeNumber'], 12);
        expect(json['position']['longitude'], 106.6294);
        expect(json['position']['latitude'], 10.7629);
        expect(json['accuracy'], 'medium');
        expect(json['source'], 'tap');
      });

      test('fromJson / toJson round-trip is lossless', () {
        final original = TargetModel(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 15,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.low,
          source: TargetSource.drag,
          placedAt: DateTime.utc(2026, 8, 2, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 8, 2, 10, 5, 0),
        );

        final restored = TargetModel.fromJson(original.toJson());

        expect(restored, original);
      });
    });

    group('GpsAccuracy enum', () {
      test('all enum values are handled in fromRow', () {
        for (final accuracy in GpsAccuracy.values) {
          final row = {
            'id': 'test',
            'round_id': 'r',
            'hole_number': 1,
            'longitude': 0.0,
            'latitude': 0.0,
            'accuracy': accuracy.name,
            'source': 'tap',
            'placed_at': '2026-08-02T10:00:00.000Z',
            'updated_at': '2026-08-02T10:00:00.000Z',
          };
          final target = TargetModel.fromRow(row);
          expect(target.accuracy, accuracy, reason: '${accuracy.name} should parse');
        }
      });
    });

    group('TargetSource enum', () {
      test('all enum values are handled in fromRow', () {
        for (final source in TargetSource.values) {
          final row = {
            'id': 'test',
            'round_id': 'r',
            'hole_number': 1,
            'longitude': 0.0,
            'latitude': 0.0,
            'accuracy': 'high',
            'source': source.name,
            'placed_at': '2026-08-02T10:00:00.000Z',
            'updated_at': '2026-08-02T10:00:00.000Z',
          };
          final target = TargetModel.fromRow(row);
          expect(target.source, source, reason: '${source.name} should parse');
        }
      });
    });

    group('Equatable', () {
      test('identical targets are equal', () {
        final t1 = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );
        final t2 = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );

        // Note: placedAt will differ slightly; test with explicit instances
        final target1 = TargetModel(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
          source: TargetSource.tap,
          placedAt: DateTime.utc(2026, 8, 2),
          updatedAt: DateTime.utc(2026, 8, 2),
        );
        final target2 = TargetModel(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
          source: TargetSource.tap,
          placedAt: DateTime.utc(2026, 8, 2),
          updatedAt: DateTime.utc(2026, 8, 2),
        );

        expect(target1, target2);
      });

      test('different targets are not equal', () {
        final t1 = TargetModel(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
          source: TargetSource.tap,
          placedAt: DateTime.utc(2026, 8, 2),
          updatedAt: DateTime.utc(2026, 8, 2),
        );
        final t2 = TargetModel(
          id: 'target_r1_h2_uuid1',
          roundId: 'round-1',
          holeNumber: 2,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
          source: TargetSource.tap,
          placedAt: DateTime.utc(2026, 8, 2),
          updatedAt: DateTime.utc(2026, 8, 2),
        );

        expect(t1, isNot(t2));
      });
    });
  });
}
