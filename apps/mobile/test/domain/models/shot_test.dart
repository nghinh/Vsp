// Shot Model Unit Tests — VSP Mobile App
//
// Tests:
//  - Shot serialization (toMap / fromMap)
//  - Shot JSON round-trip (toJson / fromJson)
//  - ShotLie enum parsing
//  - ShotResult enum parsing
//  - Copy with modifications
//  - Derived state (isActive, isEnded, isMerged)
//
// Story 10.3 — Slice 5: Validation + Testing

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/shot.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';

void main() {
  group('Shot', () {
    group('serialization', () {
      test('toMap creates correct map structure', () {
        final shot = _createTestShot();

        final map = shot.toMap();

        expect(map['id'], 'shot-1');
        expect(map['round_id'], 'round-1');
        expect(map['flight_id'], 'flight-1');
        expect(map['player_id'], 'player-1');
        expect(map['hole_number'], 1);
        expect(map['shot_number'], 1);
        expect(map['club_id'], 'club-1');
        expect(map['lie'], 'fairway');
        expect(map['distance_yards'], 250.0);
        expect(map['distance_meters'], 228.6);
        expect(map['is_penalty'], 1);
        expect(map['is_provisional'], 0);
        expect(map['is_mulligan'], 0);
        expect(map['source'], 'manual');
        expect(map['sync_status'], 'pending');
      });

      test('fromMap reconstructs shot correctly', () {
        final map = {
          'id': 'shot-1',
          'round_id': 'round-1',
          'flight_id': 'flight-1',
          'player_id': 'player-1',
          'hole_number': 1,
          'shot_number': 1,
          'club_id': 'club-1',
          'started_at': '2026-08-02T10:00:00.000Z',
          'ended_at': '2026-08-02T10:00:30.000Z',
          'start_location': '{"type":"Point","coordinates":[-122.4194,37.7749]}',
          'end_location': '{"type":"Point","coordinates":[-122.4195,37.7750]}',
          'lie': 'fairway',
          'distance_yards': 250.0,
          'distance_meters': 228.6,
          'conditions': '{"wind":"10mph"}',
          'result': 'fairway_hit',
          'is_penalty': 0,
          'is_provisional': 0,
          'is_mulligan': 0,
          'merged_into_shot_id': null,
          'source': 'manual',
          'confidence': 0.95,
          'sync_status': 'synced',
          'idempotency_key': 'idem-1',
          'server_sync_status': 'synced',
          'created_at': '2026-08-02T10:00:00.000Z',
          'updated_at': '2026-08-02T10:00:30.000Z',
        };

        final shot = Shot.fromMap(map);

        expect(shot.id, 'shot-1');
        expect(shot.roundId, 'round-1');
        expect(shot.holeNumber, 1);
        expect(shot.shotNumber, 1);
        expect(shot.clubId, 'club-1');
        expect(shot.lie, ShotLie.fairway);
        expect(shot.distanceYards, 250.0);
        expect(shot.distanceMeters, 228.6);
        expect(shot.result, ShotResult.fairwayHit);
        expect(shot.isPenalty, false);
        expect(shot.isProvisional, false);
        expect(shot.isMulligan, false);
        expect(shot.source, ShotSource.manual);
        expect(shot.confidence, 0.95);
        expect(shot.syncStatus, SyncStatus.synced);
      });

      test('toMap / fromMap round-trip preserves data', () {
        final original = _createTestShot();

        final map = original.toMap();
        final restored = Shot.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.roundId, original.roundId);
        expect(restored.flightId, original.flightId);
        expect(restored.playerId, original.playerId);
        expect(restored.holeNumber, original.holeNumber);
        expect(restored.shotNumber, original.shotNumber);
        expect(restored.clubId, original.clubId);
        expect(restored.lie, original.lie);
        expect(restored.distanceYards, original.distanceYards);
        expect(restored.distanceMeters, original.distanceMeters);
        expect(restored.result, original.result);
        expect(restored.isPenalty, original.isPenalty);
        expect(restored.isProvisional, original.isProvisional);
        expect(restored.isMulligan, original.isMulligan);
        expect(restored.source, original.source);
        expect(restored.syncStatus, original.syncStatus);
      });

      test('toJson creates correct JSON structure', () {
        final shot = _createTestShot();

        final json = shot.toJson();

        expect(json['id'], 'shot-1');
        expect(json['roundId'], 'round-1');
        expect(json['holeNumber'], 1);
        expect(json['shotNumber'], 1);
        expect(json['clubId'], 'club-1');
        expect(json['lie'], 'fairway');
        expect(json['distanceYards'], 250.0);
        expect(json['isPenalty'], true);
        expect(json['isProvisional'], false);
        expect(json['isMulligan'], false);
        expect(json['source'], 'manual');
      });

      test('fromJson reconstructs shot correctly', () {
        final json = {
          'id': 'shot-1',
          'roundId': 'round-1',
          'flightId': 'flight-1',
          'playerId': 'player-1',
          'holeNumber': 1,
          'shotNumber': 1,
          'clubId': 'club-1',
          'startedAt': '2026-08-02T10:00:00.000Z',
          'endedAt': '2026-08-02T10:00:30.000Z',
          'startLocation': '{"type":"Point","coordinates":[-122.4194,37.7749]}',
          'endLocation': '{"type":"Point","coordinates":[-122.4195,37.7750]}',
          'lie': 'fairway',
          'distanceYards': 250.0,
          'distanceMeters': 228.6,
          'conditions': '{"wind":"10mph"}',
          'result': 'fairway_hit',
          'isPenalty': true,
          'isProvisional': false,
          'isMulligan': false,
          'mergedIntoShotId': null,
          'source': 'manual',
          'confidence': 0.95,
          'syncStatus': 'pending',
          'idempotencyKey': 'idem-1',
          'createdAt': '2026-08-02T10:00:00.000Z',
          'updatedAt': '2026-08-02T10:00:30.000Z',
        };

        final shot = Shot.fromJson(json);

        expect(shot.id, 'shot-1');
        expect(shot.roundId, 'round-1');
        expect(shot.holeNumber, 1);
        expect(shot.lie, ShotLie.fairway);
        expect(shot.distanceYards, 250.0);
        expect(shot.result, ShotResult.fairwayHit);
        expect(shot.isPenalty, true);
        expect(shot.source, ShotSource.manual);
      });

      test('toJson / fromJson round-trip preserves data', () {
        final original = _createTestShot();

        final json = original.toJson();
        final restored = Shot.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.roundId, original.roundId);
        expect(restored.holeNumber, original.holeNumber);
        expect(restored.shotNumber, original.shotNumber);
        expect(restored.lie, original.lie);
        expect(restored.distanceYards, original.distanceYards);
        expect(restored.result, original.result);
        expect(restored.isPenalty, original.isPenalty);
        expect(restored.isProvisional, original.isProvisional);
        expect(restored.isMulligan, original.isMulligan);
      });
    });

    group('ShotLie enum', () {
      test('fromString parses standard values', () {
        expect(ShotLie.fromString('fairway'), ShotLie.fairway);
        expect(ShotLie.fromString('rough'), ShotLie.rough);
        expect(ShotLie.fromString('bunker'), ShotLie.bunker);
        expect(ShotLie.fromString('green'), ShotLie.green);
        expect(ShotLie.fromString('water'), ShotLie.water);
        expect(ShotLie.fromString('out_of_bounds'), ShotLie.outOfBounds);
      });

      test('fromString handles alternative formats', () {
        expect(ShotLie.fromString('FAIRWAY'), ShotLie.fairway);
        expect(ShotLie.fromString('tee-box'), ShotLie.teebox);
        expect(ShotLie.fromString('OUT_OF_BOUNDS'), ShotLie.outOfBounds);
      });

      test('fromString returns other for unknown values', () {
        expect(ShotLie.fromString('unknown'), ShotLie.other);
        expect(ShotLie.fromString('foobar'), ShotLie.other);
        expect(ShotLie.fromString(null), ShotLie.other);
      });

      test('toApiValue returns correct API strings', () {
        expect(ShotLie.teebox.toApiValue(), 'tee_box');
        expect(ShotLie.fairway.toApiValue(), 'fairway');
        expect(ShotLie.rough.toApiValue(), 'rough');
        expect(ShotLie.bunker.toApiValue(), 'bunker');
        expect(ShotLie.water.toApiValue(), 'water');
        expect(ShotLie.penalty.toApiValue(), 'penalty');
        expect(ShotLie.green.toApiValue(), 'green');
        expect(ShotLie.putt.toApiValue(), 'putt');
        expect(ShotLie.outOfBounds.toApiValue(), 'out_of_bounds');
        expect(ShotLie.cartPath.toApiValue(), 'cart_path');
      });
    });

    group('ShotResult enum', () {
      test('fromString parses standard values', () {
        expect(ShotResult.fromString('fairway_hit'), ShotResult.fairwayHit);
        expect(ShotResult.fromString('green_hit'), ShotResult.greenHit);
        expect(ShotResult.fromString('in_bunker'), ShotResult.inBunker);
        expect(ShotResult.fromString('in_water'), ShotResult.inWater);
        expect(ShotResult.fromString('out_of_bounds'), ShotResult.outOfBounds);
      });

      test('fromString handles alternative formats', () {
        expect(ShotResult.fromString('fairwayHit'), ShotResult.fairwayHit);
        expect(ShotResult.fromString('GREEN_HIT'), ShotResult.greenHit);
      });

      test('fromString returns unknown for unknown values', () {
        expect(ShotResult.fromString('unknown'), ShotResult.unknown);
        expect(ShotResult.fromString(null), ShotResult.unknown);
      });

      test('toApiValue returns correct API strings', () {
        expect(ShotResult.fairwayHit.toApiValue(), 'fairway_hit');
        expect(ShotResult.greenHit.toApiValue(), 'green_hit');
        expect(ShotResult.inBunker.toApiValue(), 'in_bunker');
        expect(ShotResult.inWater.toApiValue(), 'in_water');
        expect(ShotResult.outOfBounds.toApiValue(), 'out_of_bounds');
        expect(ShotResult.penalty.toApiValue(), 'penalty');
        expect(ShotResult.mulligan.toApiValue(), 'mulligan');
        expect(ShotResult.provisional.toApiValue(), 'provisional');
      });
    });

    group('derived state', () {
      test('isEnded returns true when endedAt is set', () {
        final shot = _createTestShot();
        expect(shot.isEnded, true);
      });

      test('isEnded returns false when endedAt is null', () {
        final shot = _createTestShot().copyWith(
          endedAt: null,
          clearEndedAt: true,
        );
        expect(shot.isEnded, false);
      });

      test('isActive returns true when shot is started but not ended', () {
        final shot = _createTestShot().copyWith(
          endedAt: null,
          clearEndedAt: true,
        );
        expect(shot.isActive, true);
      });

      test('isActive returns false when shot is ended', () {
        final shot = _createTestShot();
        expect(shot.isActive, false);
      });

      test('isMerged returns true when mergedIntoShotId is set', () {
        final shot = _createTestShot().copyWith(
          mergedIntoShotId: 'target-shot-id',
        );
        expect(shot.isMerged, true);
      });

      test('isMerged returns false when mergedIntoShotId is null', () {
        final shot = _createTestShot();
        expect(shot.isMerged, false);
      });
    });

    group('copyWith', () {
      test('preserves unmodified fields', () {
        final original = _createTestShot();

        final copied = original.copyWith(clubId: 'new-club-id');

        expect(copied.id, original.id);
        expect(copied.roundId, original.roundId);
        expect(copied.holeNumber, original.holeNumber);
        expect(copied.shotNumber, original.shotNumber);
        expect(copied.lie, original.lie);
        expect(copied.distanceYards, original.distanceYards);
      });

      test('updates specified fields', () {
        final original = _createTestShot();

        final copied = original.copyWith(
          clubId: 'new-club-id',
          lie: ShotLie.bunker,
          distanceYards: 100.0,
          isPenalty: true,
        );

        expect(copied.clubId, 'new-club-id');
        expect(copied.lie, ShotLie.bunker);
        expect(copied.distanceYards, 100.0);
        expect(copied.isPenalty, true);
      });

      test('clearClubId sets clubId to null', () {
        final original = _createTestShot();

        final copied = original.copyWith(clearClubId: true);

        expect(copied.clubId, null);
      });

      test('clearLie sets lie to null', () {
        final original = _createTestShot();

        final copied = original.copyWith(clearLie: true);

        expect(copied.lie, null);
      });

      test('clearResult sets result to null', () {
        final original = _createTestShot();

        final copied = original.copyWith(clearResult: true);

        expect(copied.result, null);
      });
    });

    group('equality', () {
      test('identical shots are equal', () {
        final shot1 = _createTestShot();
        final shot2 = _createTestShot();

        expect(shot1, equals(shot2));
      });

      test('different shots are not equal', () {
        final shot1 = _createTestShot();
        final shot2 = _createTestShot().copyWith(id: 'different-id');

        expect(shot1, isNot(equals(shot2)));
      });
    });
  });
}

Shot _createTestShot() {
  return Shot(
    id: 'shot-1',
    roundId: 'round-1',
    flightId: 'flight-1',
    playerId: 'player-1',
    holeNumber: 1,
    shotNumber: 1,
    clubId: 'club-1',
    startedAt: DateTime.parse('2026-08-02T10:00:00Z'),
    endedAt: DateTime.parse('2026-08-02T10:00:30Z'),
    startLocation: '{"type":"Point","coordinates":[-122.4194,37.7749]}',
    endLocation: '{"type":"Point","coordinates":[-122.4195,37.7750]}',
    lie: ShotLie.fairway,
    distanceYards: 250.0,
    distanceMeters: 228.6,
    conditions: '{"wind":"10mph"}',
    result: ShotResult.fairwayHit,
    isPenalty: true,
    isProvisional: false,
    isMulligan: false,
    source: ShotSource.manual,
    confidence: 0.95,
    syncStatus: SyncStatus.pending,
    idempotencyKey: 'idem-1',
    serverSyncStatus: SyncStatus.pending,
    createdAt: DateTime.parse('2026-08-02T10:00:00Z'),
    updatedAt: DateTime.parse('2026-08-02T10:00:30Z'),
  );
}
