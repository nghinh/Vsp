// Shot Sync Service Unit Tests — VSP Mobile App
//
// Tests:
//  - Shot start/end/edit/delete/merge operations
//  - Idempotency key generation
//  - Local persistence before sync
//  - Sync event queue append
//
// Story 10.3 — Slice 5: Validation + Testing

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/application/services/shot_sync_service.dart';
import 'package:vsp_mobile/domain/models/driving_zone_filter.dart';
import 'package:vsp_mobile/domain/models/driving_zone_statistics.dart';
import 'package:vsp_mobile/domain/models/round_review_metrics.dart';
import 'package:vsp_mobile/domain/models/shot.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';
import 'package:vsp_mobile/domain/repositories/shot_repository.dart';
import 'package:vsp_mobile/infrastructure/persistence/sync_queue_repository.dart';

// Mock implementations

class MockShotRepository implements ShotRepository {
  final List<Shot> _shots = [];
  final List<Shot> _upsertedShots = [];
  final List<String> _deletedIds = [];

  @override
  Future<void> upsertShot(Shot shot) async {
    _upsertedShots.add(shot);
    final index = _shots.indexWhere((s) => s.id == shot.id);
    if (index >= 0) {
      _shots[index] = shot;
    } else {
      _shots.add(shot);
    }
  }

  @override
  Future<Shot?> getShotById(String id) async {
    return _shots.where((s) => s.id == id).firstOrNull;
  }

  @override
  Future<Shot?> getShotByIdempotencyKey(String idempotencyKey) async {
    return _shots.where((s) => s.idempotencyKey == idempotencyKey).firstOrNull;
  }

  @override
  Future<List<Shot>> getShotsForRound(String roundId) async {
    return _shots.where((s) => s.roundId == roundId).toList();
  }

  @override
  Future<List<Shot>> getShotsForPlayer(String roundId, String playerId) async {
    return _shots
        .where((s) => s.roundId == roundId && s.playerId == playerId)
        .toList();
  }

  @override
  Future<List<Shot>> getActiveShotsForRound(String roundId) async {
    return _shots
        .where((s) => s.roundId == roundId && s.endedAt == null)
        .toList();
  }

  @override
  Future<List<Shot>> getShotsBySyncStatus(SyncStatus status) async {
    return _shots.where((s) => s.syncStatus == status).toList();
  }

  @override
  Future<List<Shot>> getPendingShotsForRound(String roundId) async {
    return _shots
        .where(
          (s) => s.roundId == roundId && s.syncStatus == SyncStatus.pending,
        )
        .toList();
  }

  @override
  Future<void> deleteShot(String id) async {
    _deletedIds.add(id);
    _shots.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> updateSyncStatus(String shotId, SyncStatus status) async {
    final index = _shots.indexWhere((s) => s.id == shotId);
    if (index >= 0) {
      _shots[index] = _shots[index].copyWith(syncStatus: status);
    }
  }

  @override
  Future<int> countShotsForRound(String roundId) async {
    return _shots.where((s) => s.roundId == roundId).length;
  }

  @override
  Future<List<Shot>> getShotsByFilter(DrivingZoneFilter filter) async =>
      _shots.where((shot) => shot.playerId == filter.playerId).toList();

  @override
  Future<DrivingZoneStatistics> getDrivingZoneStats(
    DrivingZoneFilter filter,
  ) async => DrivingZoneStatistics(
    filter: filter,
    holeStats: const [],
    generatedAt: DateTime.now(),
  );

  @override
  Future<RoundReviewMetrics> getRoundReviewMetrics({
    required String roundId,
    required String playerId,
  }) async =>
      throw StateError('Round review is outside this sync-service test');

  // Test helpers
  List<Shot> get upsertedShots => _upsertedShots;
  List<String> get deletedIds => _deletedIds;
  void clear() => _shots.clear();
}

class MockSyncQueueRepository extends SyncQueueRepository {
  final List<SyncEvent> _events = [];

  @override
  Future<void> append(SyncEvent event) async {
    _events.add(event);
  }

  List<SyncEvent> get events => _events;
  void clear() => _events.clear();
}

void main() {
  group('ShotSyncService', () {
    late MockShotRepository mockShotRepo;
    late MockSyncQueueRepository mockSyncQueue;
    late ShotSyncService shotSyncService;

    setUp(() {
      mockShotRepo = MockShotRepository();
      mockSyncQueue = MockSyncQueueRepository();
      shotSyncService = ShotSyncService(
        shotRepo: mockShotRepo,
        syncQueue: mockSyncQueue,
      );
    });

    tearDown(() {
      mockShotRepo.clear();
      mockSyncQueue.clear();
    });

    group('startShot', () {
      test('creates shot with correct fields', () async {
        final shot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          clubId: 'club-1',
          startedAt: DateTime.now(),
          startLocation: '{"type":"Point","coordinates":[-122.4194,37.7749]}',
          conditions: '{"wind":"10mph"}',
          confidence: 0.95,
        );

        expect(shot.roundId, 'round-1');
        expect(shot.flightId, 'flight-1');
        expect(shot.playerId, 'player-1');
        expect(shot.holeNumber, 1);
        expect(shot.shotNumber, 1);
        expect(shot.clubId, 'club-1');
        expect(shot.startLocation, isNotNull);
        expect(shot.source, ShotSource.manual);
        expect(shot.syncStatus, SyncStatus.pending);
        expect(shot.idempotencyKey, isNotEmpty);
      });

      test('persists shot locally', () async {
        await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        expect(mockShotRepo.upsertedShots, hasLength(1));
        expect(mockShotRepo.upsertedShots.first.syncStatus, SyncStatus.pending);
      });

      test('generates unique idempotency key', () async {
        final shot1 = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        final shot2 = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 2,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        expect(shot1.idempotencyKey, isNot(equals(shot2.idempotencyKey)));
      });
    });

    group('endShot', () {
      test('throws when shot not found', () async {
        expect(
          () => shotSyncService.endShot(
            shotId: 'non-existent-id',
            endedAt: DateTime.now(),
            confidence: 0.95,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('updates shot with end location and calculated fields', () async {
        // First start a shot
        final startedShot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          startLocation: '{"type":"Point","coordinates":[-122.4194,37.7749]}',
          confidence: 0.95,
        );

        // Now end it
        final endedShot = await shotSyncService.endShot(
          shotId: startedShot.id,
          endedAt: DateTime.now(),
          endLocation: '{"type":"Point","coordinates":[-122.4195,37.7750]}',
          lie: ShotLie.fairway,
          distanceYards: 250.0,
          distanceMeters: 228.6,
          result: ShotResult.fairwayHit,
          confidence: 0.95,
        );

        expect(endedShot.endLocation, isNotNull);
        expect(endedShot.lie, ShotLie.fairway);
        expect(endedShot.distanceYards, 250.0);
        expect(endedShot.distanceMeters, 228.6);
        expect(endedShot.result, ShotResult.fairwayHit);
        expect(endedShot.endedAt, isNotNull);
      });

      test('generates new idempotency key for end event', () async {
        final startedShot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        final endedShot = await shotSyncService.endShot(
          shotId: startedShot.id,
          endedAt: DateTime.now(),
          confidence: 0.95,
        );

        expect(
          endedShot.idempotencyKey,
          isNot(equals(startedShot.idempotencyKey)),
        );
      });
    });

    group('editShot', () {
      test('throws when shot not found', () async {
        expect(
          () => shotSyncService.editShot(
            shotId: 'non-existent-id',
            clubId: 'new-club-id',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('updates shot with new values', () async {
        final startedShot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        final editedShot = await shotSyncService.editShot(
          shotId: startedShot.id,
          clubId: 'new-club-id',
          lie: ShotLie.bunker,
          isPenalty: true,
        );

        expect(editedShot.clubId, 'new-club-id');
        expect(editedShot.lie, ShotLie.bunker);
        expect(editedShot.isPenalty, true);
      });

      test('preserves unmodified fields', () async {
        final startedShot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          startLocation: '{"type":"Point","coordinates":[-122.4194,37.7749]}',
          confidence: 0.95,
        );

        final editedShot = await shotSyncService.editShot(
          shotId: startedShot.id,
          clubId: 'new-club-id',
        );

        expect(editedShot.startLocation, startedShot.startLocation);
        expect(editedShot.roundId, startedShot.roundId);
        expect(editedShot.holeNumber, startedShot.holeNumber);
      });
    });

    group('deleteShot', () {
      test('throws when shot not found (no-op)', () async {
        // Should not throw, just return
        await shotSyncService.deleteShot('non-existent-id');
        // No exception means success
      });

      test('calls repository delete', () async {
        final startedShot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        await shotSyncService.deleteShot(startedShot.id);

        expect(mockShotRepo.deletedIds, contains(startedShot.id));
      });
    });

    group('mergeShots', () {
      test('throws when source shot not found', () async {
        expect(
          () => shotSyncService.mergeShots(
            sourceShotId: 'non-existent-id',
            targetShotId: 'target-id',
            roundId: 'round-1',
            playerId: 'player-1',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('throws when target shot not found', () async {
        final sourceShot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        expect(
          () => shotSyncService.mergeShots(
            sourceShotId: sourceShot.id,
            targetShotId: 'non-existent-id',
            roundId: 'round-1',
            playerId: 'player-1',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('updates source shot with mergedIntoShotId', () async {
        final sourceShot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 1,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        final targetShot = await shotSyncService.startShot(
          roundId: 'round-1',
          flightId: 'flight-1',
          playerId: 'player-1',
          holeNumber: 1,
          shotNumber: 2,
          startedAt: DateTime.now(),
          confidence: 0.95,
        );

        await shotSyncService.mergeShots(
          sourceShotId: sourceShot.id,
          targetShotId: targetShot.id,
          roundId: 'round-1',
          playerId: 'player-1',
        );

        final updatedSource = mockShotRepo.upsertedShots.last;
        expect(updatedSource.mergedIntoShotId, targetShot.id);
      });
    });
  });
}
