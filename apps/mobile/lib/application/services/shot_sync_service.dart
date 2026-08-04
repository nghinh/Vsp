// Shot Sync Service — VSP Mobile App
//
// Coordinates shot persistence and sync event queue for shot mutations.
// Per Story 10.3 Slice 1: Domain + Persistence
//
// Each shot mutation:
//  1. Writes to local SQLite first (offline durability)
//  2. Appends a ShotEvent to the SyncEventQueue with a UUID idempotency key
//  3. Sync worker picks up pending events and calls the backend API
//  4. On 2xx or X-Idempotent-Replay: true → mark synced
//  5. On 4xx → mark permanently failed (no retry)
//  6. On 5xx / network error → re-queue with backoff
//
// Integration with Epic 5 SyncEventQueue via SyncEvent.forScore() pattern.

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/models/shot.dart';
import '../../domain/models/sync_event.dart';
import '../../domain/models/sync_status.dart';
import '../../domain/repositories/shot_repository.dart';
import '../../infrastructure/persistence/sync_queue_repository.dart';

/// Shot event types for the sync queue.
enum ShotEventType {
  shotStarted,
  shotEnded,
  shotEdited,
  shotDeleted,
  shotsMerged;

  SyncEventType toSyncEventType() {
    switch (this) {
      case ShotEventType.shotStarted:
        return SyncEventType.shotStarted;
      case ShotEventType.shotEnded:
        return SyncEventType.shotEnded;
      case ShotEventType.shotEdited:
        return SyncEventType.shotEdited;
      case ShotEventType.shotDeleted:
        return SyncEventType.shotDeleted;
      case ShotEventType.shotsMerged:
        return SyncEventType.shotsMerged;
    }
  }
}

/// Service coordinating shot persistence and sync event queue.
///
/// Follows the Epic 5 SyncEventQueue pattern:
/// - All mutations are first persisted locally to SQLite
/// - A SyncEvent is appended to the queue with a UUID idempotency key
/// - The sync worker processes the queue with retry/backoff
///
/// Per Story 10.3 Slice 1.
class ShotSyncService {
  final ShotRepository _shotRepo;
  final SyncQueueRepository _syncQueue;
  final Uuid _uuid = const Uuid();

  ShotSyncService({
    required ShotRepository shotRepo,
    required SyncQueueRepository syncQueue,
  }) : _shotRepo = shotRepo,
       _syncQueue = syncQueue;

  // ─── Public API ─────────────────────────────────────────────────────────

  /// Start a new shot — persists locally and enqueues ShotStarted event.
  ///
  /// Generates a fresh UUID idempotency key for this shot.
  /// Returns the created shot with its idempotency key.
  Future<Shot> startShot({
    required String roundId,
    required String flightId,
    required String playerId,
    required int holeNumber,
    required int shotNumber,
    String? clubId,
    required DateTime startedAt,
    String? startLocation,
    String? conditions,
    required double? confidence,
  }) async {
    final idempotencyKey = _uuid.v4();
    final now = DateTime.now();
    final shotId = _uuid.v4();

    final shot = Shot(
      id: shotId,
      roundId: roundId,
      flightId: flightId,
      playerId: playerId,
      holeNumber: holeNumber,
      shotNumber: shotNumber,
      clubId: clubId,
      startedAt: startedAt,
      startLocation: startLocation,
      conditions: conditions,
      source: ShotSource.manual,
      confidence: confidence,
      syncStatus: SyncStatus.pending,
      idempotencyKey: idempotencyKey,
      serverSyncStatus: SyncStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    // Step 1: Persist locally (offline-first)
    await _shotRepo.upsertShot(shot);

    // Step 2: Append to sync queue
    await _appendShotEvent(
      eventType: ShotEventType.shotStarted,
      shotId: shotId,
      roundId: roundId,
      playerId: playerId,
      idempotencyKey: idempotencyKey,
      payload: _shotStartedPayload(shot),
    );

    return shot;
  }

  /// End an active shot — persists locally and enqueues ShotEnded event.
  Future<Shot> endShot({
    required String shotId,
    required DateTime endedAt,
    String? endLocation,
    ShotLie? lie,
    double? distanceYards,
    double? distanceMeters,
    ShotResult? result,
    String? conditions,
    required double? confidence,
  }) async {
    final existing = await _shotRepo.getShotById(shotId);
    if (existing == null) {
      throw StateError('Shot $shotId not found — cannot end');
    }

    final idempotencyKey = _uuid.v4();
    final now = DateTime.now();

    final updated = existing.copyWith(
      endedAt: endedAt,
      endLocation: endLocation,
      lie: lie,
      distanceYards: distanceYards,
      distanceMeters: distanceMeters,
      result: result,
      conditions: conditions,
      confidence: confidence,
      syncStatus: SyncStatus.pending,
      idempotencyKey: idempotencyKey,
      updatedAt: now,
    );

    // Step 1: Persist locally
    await _shotRepo.upsertShot(updated);

    // Step 2: Append to sync queue
    await _appendShotEvent(
      eventType: ShotEventType.shotEnded,
      shotId: shotId,
      roundId: updated.roundId,
      playerId: updated.playerId,
      idempotencyKey: idempotencyKey,
      payload: _shotEndedPayload(updated),
    );

    return updated;
  }

  /// Edit a shot — persists locally and enqueues ShotEdited event.
  Future<Shot> editShot({
    required String shotId,
    String? clubId,
    ShotLie? lie,
    ShotResult? result,
    double? distanceYards,
    double? distanceMeters,
    String? conditions,
    bool? isPenalty,
    bool? isProvisional,
    bool? isMulligan,
    double? confidence,
  }) async {
    final existing = await _shotRepo.getShotById(shotId);
    if (existing == null) {
      throw StateError('Shot $shotId not found — cannot edit');
    }

    final idempotencyKey = _uuid.v4();
    final now = DateTime.now();

    final updated = existing.copyWith(
      clubId: clubId,
      lie: lie,
      result: result,
      distanceYards: distanceYards,
      distanceMeters: distanceMeters,
      conditions: conditions,
      isPenalty: isPenalty,
      isProvisional: isProvisional,
      isMulligan: isMulligan,
      confidence: confidence,
      syncStatus: SyncStatus.pending,
      idempotencyKey: idempotencyKey,
      updatedAt: now,
    );

    // Step 1: Persist locally
    await _shotRepo.upsertShot(updated);

    // Step 2: Append to sync queue
    await _appendShotEvent(
      eventType: ShotEventType.shotEdited,
      shotId: shotId,
      roundId: updated.roundId,
      playerId: updated.playerId,
      idempotencyKey: idempotencyKey,
      payload: _shotEditedPayload(updated),
    );

    return updated;
  }

  /// Soft-delete a shot — persists locally and enqueues ShotDeleted event.
  Future<void> deleteShot(String shotId) async {
    final existing = await _shotRepo.getShotById(shotId);
    if (existing == null) return; // Already deleted or not found

    final idempotencyKey = _uuid.v4();

    // Step 1: Persist locally (soft delete via syncStatus = pending)
    await _shotRepo.deleteShot(shotId);

    // Step 2: Append to sync queue
    await _appendShotEvent(
      eventType: ShotEventType.shotDeleted,
      shotId: shotId,
      roundId: existing.roundId,
      playerId: existing.playerId,
      idempotencyKey: idempotencyKey,
      payload: jsonEncode({'shotId': shotId}),
    );
  }

  /// Merge two shots — persists locally and enqueues ShotsMerged event.
  Future<Shot> mergeShots({
    required String sourceShotId,
    required String targetShotId,
    required String roundId,
    required String playerId,
  }) async {
    final sourceShot = await _shotRepo.getShotById(sourceShotId);
    if (sourceShot == null) {
      throw StateError('Source shot $sourceShotId not found');
    }

    final targetShot = await _shotRepo.getShotById(targetShotId);
    if (targetShot == null) {
      throw StateError('Target shot $targetShotId not found');
    }

    final idempotencyKey = _uuid.v4();
    final now = DateTime.now();

    // Update source to mark as merged
    final updatedSource = sourceShot.copyWith(
      mergedIntoShotId: targetShotId,
      syncStatus: SyncStatus.pending,
      idempotencyKey: idempotencyKey,
      updatedAt: now,
    );

    // Step 1: Persist locally
    await _shotRepo.upsertShot(updatedSource);

    // Step 2: Append to sync queue
    await _appendShotEvent(
      eventType: ShotEventType.shotsMerged,
      shotId: sourceShotId,
      roundId: roundId,
      playerId: playerId,
      idempotencyKey: idempotencyKey,
      payload: jsonEncode({
        'sourceShotId': sourceShotId,
        'targetShotId': targetShotId,
      }),
    );

    return targetShot;
  }

  // ─── Sync Event Queue ──────────────────────────────────────────────────

  Future<void> _appendShotEvent({
    required ShotEventType eventType,
    required String shotId,
    required String roundId,
    required String playerId,
    required String idempotencyKey,
    required String payload,
  }) async {
    final syncEvent = SyncEvent(
      id: idempotencyKey,
      type: eventType.toSyncEventType(),
      entityId: shotId,
      payload: payload,
      state: SyncStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.now().toUtc(),
    );

    await _syncQueue.append(syncEvent);
  }

  // ─── Payload Builders ──────────────────────────────────────────────────

  String _shotStartedPayload(Shot shot) {
    return jsonEncode({
      'shotId': shot.id,
      'roundId': shot.roundId,
      'flightId': shot.flightId,
      'playerId': shot.playerId,
      'holeNumber': shot.holeNumber,
      'shotNumber': shot.shotNumber,
      'clubId': shot.clubId,
      'startedAt': shot.startedAt.toIso8601String(),
      'startLocation': shot.startLocation,
      'conditions': shot.conditions,
      'source': shot.source.name,
      'confidence': shot.confidence,
    });
  }

  String _shotEndedPayload(Shot shot) {
    return jsonEncode({
      'shotId': shot.id,
      'roundId': shot.roundId,
      'flightId': shot.flightId,
      'playerId': shot.playerId,
      'holeNumber': shot.holeNumber,
      'shotNumber': shot.shotNumber,
      'clubId': shot.clubId,
      'startedAt': shot.startedAt.toIso8601String(),
      'endedAt': shot.endedAt?.toIso8601String(),
      'startLocation': shot.startLocation,
      'endLocation': shot.endLocation,
      'lie': shot.lie?.toApiValue(),
      'distanceYards': shot.distanceYards,
      'distanceMeters': shot.distanceMeters,
      'conditions': shot.conditions,
      'result': shot.result?.toApiValue(),
      'isPenalty': shot.isPenalty,
      'isProvisional': shot.isProvisional,
      'isMulligan': shot.isMulligan,
      'source': shot.source.name,
      'confidence': shot.confidence,
    });
  }

  String _shotEditedPayload(Shot shot) {
    return jsonEncode({
      'shotId': shot.id,
      'roundId': shot.roundId,
      'playerId': shot.playerId,
      'clubId': shot.clubId,
      'endedAt': shot.endedAt?.toIso8601String(),
      'endLocation': shot.endLocation,
      'lie': shot.lie?.toApiValue(),
      'distanceYards': shot.distanceYards,
      'distanceMeters': shot.distanceMeters,
      'conditions': shot.conditions,
      'result': shot.result?.toApiValue(),
      'isPenalty': shot.isPenalty,
      'isProvisional': shot.isProvisional,
      'isMulligan': shot.isMulligan,
      'confidence': shot.confidence,
    });
  }
}
