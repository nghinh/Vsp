// Round State Service — VSP Mobile App
//
// Coordinates round persistence, sync queue, and ActiveRoundGuard
// for the complete round lifecycle: start → score → end.
//
// Story 5.2: Persist Round Locally — Slice 4

import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/hole_score.dart';
import '../../domain/models/player.dart';
import '../../domain/models/round.dart';
import '../../domain/models/round_config.dart';
import '../../domain/models/round_sync_operation.dart';
import '../repositories/hole_score_repository.dart';
import '../repositories/player_repository.dart';
import '../repositories/round_repository.dart';
import '../../core/storage/round_sync_store.dart';
import 'active_round_guard.dart';

/// Sync state for the round's offline queue.
enum RoundSyncState {
  /// All changes have been synced to the server.
  synced,

  /// There are pending changes waiting to sync.
  pending,

  /// Sync is currently in progress.
  syncing,

  /// Sync failed and needs retry.
  failed,
}

/// Service coordinating round persistence, queue, and ActiveRoundGuard.
///
/// Orchestrates the round lifecycle:
/// - [startRound] — creates round in DB, enqueues sync event, records guard
/// - [updateHoleScore] — persists score and enqueues sync event
/// - [endRound] — marks round complete, enqueues sync, clears guard
///
/// Also handles recovery on app restart via [recoverActiveRound].
class RoundStateService {
  final RoundRepository _roundRepo;
  final HoleScoreRepository _scoreRepo;
  final PlayerRepository _playerRepo;
  final RoundSyncStore _syncStore;
  final ActiveRoundGuard _activeRoundGuard;
  final Uuid _uuid = const Uuid();

  RoundStateService({
    required RoundRepository roundRepo,
    required HoleScoreRepository scoreRepo,
    required PlayerRepository playerRepo,
    required RoundSyncStore syncStore,
    required ActiveRoundGuard activeRoundGuard,
  }) : _roundRepo = roundRepo,
       _scoreRepo = scoreRepo,
       _playerRepo = playerRepo,
       _syncStore = syncStore,
       _activeRoundGuard = activeRoundGuard;

  // -------------------------------------------------------------------------
  // Round lifecycle
  // -------------------------------------------------------------------------

  /// Start a new round with the given configuration and players.
  ///
  /// Persists the round and its players atomically, enqueues a `startRound`
  /// sync event, and records the active round in [ActiveRoundGuard] to
  /// prevent package version promotion during the round.
  Future<Round> startRound(RoundConfig config, List<Player> players) async {
    final now = DateTime.now();
    final roundId = _uuid.v4();

    // Resolve package version from config, defaulting to empty string if absent.
    final packageVersion = config.packageId ?? '';

    final round = Round(
      id: roundId,
      courseId: config.courseId,
      courseName: config.courseName,
      status: RoundStatus.inProgress,
      startedAt: now,
      endedAt: null,
      packageVersion: packageVersion,
      createdAt: now,
      updatedAt: now,
    );

    // Persist round and players atomically using a single transaction.
    // All repos share the same underlying SQLite connection (same file path)
    // so the transaction encompasses round + player inserts atomically.
    await _roundRepo.transactional((txn) async {
      // Insert round using the transaction directly.
      await txn.insert(
        'rounds',
        round.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // Insert players using the same transaction.
      for (final player in players) {
        await txn.insert(
          'players',
          player.toMap(roundId),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
      }
    });

    // Enqueue startRound sync event.
    final idempotencyKey = _syncStore.generateIdempotencyKey(
      roundId: roundId,
      operation: RoundSyncOperation.startRound,
    );
    await _syncStore.enqueueRoundOp(
      idempotencyKey: idempotencyKey,
      operation: RoundSyncOperation.startRound,
      roundId: roundId,
      payload: jsonEncode({
        'courseId': config.courseId,
        'courseName': config.courseName,
        'startedAt': now.toUtc().toIso8601String(),
        'playerIds': config.playerIds,
      }),
    );

    // Record in ActiveRoundGuard to prevent package updates during round.
    await _activeRoundGuard.recordRoundStart(config.courseId, roundId: roundId);

    return round;
  }

  /// Update a hole score for an active round.
  ///
  /// Persists the score and enqueues an `updateHoleScore` sync event
  /// with an idempotency key to prevent duplicates on retry.
  Future<void> updateHoleScore(String roundId, HoleScore score) async {
    // Persist score within a transaction.
    await _scoreRepo.updateScore(score);

    // Enqueue updateHoleScore sync event.
    final idempotencyKey = _syncStore.generateIdempotencyKey(
      roundId: roundId,
      operation: RoundSyncOperation.updateHoleScore,
    );
    await _syncStore.enqueueRoundOp(
      idempotencyKey: idempotencyKey,
      operation: RoundSyncOperation.updateHoleScore,
      roundId: roundId,
      payload: jsonEncode(score.toMap()),
    );
  }

  /// End an active round.
  ///
  /// Updates the round status to `completed`, sets `endedAt`, enqueues an
  /// `endRound` sync event, and clears the [ActiveRoundGuard] record to
  /// allow package version promotion.
  Future<void> endRound(String roundId) async {
    final round = await _roundRepo.getRound(roundId);
    if (round == null) return;

    final now = DateTime.now();
    final updatedRound = round.copyWith(
      status: RoundStatus.completed,
      endedAt: now,
      updatedAt: now,
    );

    await _roundRepo.updateRound(updatedRound);

    // Enqueue endRound sync event.
    final idempotencyKey = _syncStore.generateIdempotencyKey(
      roundId: roundId,
      operation: RoundSyncOperation.endRound,
    );
    await _syncStore.enqueueRoundOp(
      idempotencyKey: idempotencyKey,
      operation: RoundSyncOperation.endRound,
      roundId: roundId,
      payload: jsonEncode({'endedAt': now.toUtc().toIso8601String()}),
    );

    // Clear ActiveRoundGuard to allow package updates.
    await _activeRoundGuard.recordRoundEnd(round.courseId);
  }

  // -------------------------------------------------------------------------
  // Queries
  // -------------------------------------------------------------------------

  /// Return the currently active round, if any.
  Future<Round?> getActiveRound() => _roundRepo.getActiveRound();

  /// Return all hole scores for a round.
  Future<List<HoleScore>> getHoleScores(String roundId) =>
      _scoreRepo.getScoresForRound(roundId);

  // -------------------------------------------------------------------------
  // Sync state
  // -------------------------------------------------------------------------

  /// True if there are unsynced round changes.
  Future<bool> hasUnsyncedChanges() => _syncStore.hasPending();

  /// Number of pending sync entries for this round.
  Future<int> pendingSyncCount() => _syncStore.pendingCount();

  /// Current sync state for the round's offline queue.
  ///
  /// - `synced` — no pending entries
  /// - `pending` — entries waiting to sync
  /// - `failed` — at least one entry has exceeded retry limit
  /// - `syncing` — not tracked at the service level (sync worker state)
  Future<RoundSyncState> getSyncState() async {
    final pending = await _syncStore.pendingCount();
    if (pending == 0) return RoundSyncState.synced;

    // Check if any entry has exceeded retry limit (failed state).
    final entries = await _syncStore.dequeueAll();
    final hasFailed = entries.any((e) => e.retryCount >= 3);

    return hasFailed ? RoundSyncState.failed : RoundSyncState.pending;
  }

  // -------------------------------------------------------------------------
  // Recovery
  // -------------------------------------------------------------------------

  /// Recover and return the active round on app launch.
  ///
  /// Called by the app on startup to resume an incomplete round.
  /// Returns the round if one exists with status `inProgress`, otherwise null.
  Future<Round?> recoverActiveRound() => _roundRepo.getActiveRound();
}
