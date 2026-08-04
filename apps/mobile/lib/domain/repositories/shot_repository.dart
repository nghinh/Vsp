// Shot Repository Interface — VSP Mobile App
//
// Abstract repository interface for Shot persistence.
// Implementations: ShotRepositoryImpl (SQLite).
//
// Story 10.3 — Slice 1: Domain + Persistence

import '../models/shot.dart';
import '../models/sync_status.dart';
import '../models/driving_zone_filter.dart';
import '../models/driving_zone_statistics.dart';
import '../models/round_review_metrics.dart';

/// Repository interface for Shot persistence operations.
abstract class ShotRepository {
  /// Persist a shot (insert or update).
  Future<void> upsertShot(Shot shot);

  /// Get a shot by its unique ID.
  Future<Shot?> getShotById(String id);

  /// Get a shot by its idempotency key.
  Future<Shot?> getShotByIdempotencyKey(String idempotencyKey);

  /// Get all shots for a round.
  Future<List<Shot>> getShotsForRound(String roundId);

  /// Get all shots for a player in a round.
  Future<List<Shot>> getShotsForPlayer(String roundId, String playerId);

  /// Get all active (non-ended) shots for a round.
  Future<List<Shot>> getActiveShotsForRound(String roundId);

  /// Get all shots with a specific sync status.
  Future<List<Shot>> getShotsBySyncStatus(SyncStatus status);

  /// Get all pending shots for a round (local changes not yet synced).
  Future<List<Shot>> getPendingShotsForRound(String roundId);

  /// Soft-delete a shot.
  Future<void> deleteShot(String id);

  /// Update the sync status of a shot.
  Future<void> updateSyncStatus(String shotId, SyncStatus status);

  /// Count shots for a round.
  Future<int> countShotsForRound(String roundId);

  // ─── Analytics (Story 11.2) ───────────────────────────────────────────────────

  /// Get shots filtered by [filter] criteria.
  ///
  /// Falls back to local SQLite when API is unavailable.
  /// Returns empty list with [IncompleteDataWarning] when sample is insufficient.
  Future<List<Shot>> getShotsByFilter(DrivingZoneFilter filter);

  /// Get aggregated driving zone statistics for the given [filter].
  ///
  /// Per AC1: supports time, club, tee, and wind filters.
  /// Returns [DrivingZoneStatistics] with per-hole per-club zone cells.
  /// Surfaces [IncompleteDataWarning] when shot count < minimumShotCount.
  Future<DrivingZoneStatistics> getDrivingZoneStats(DrivingZoneFilter filter);

  /// Get round review metrics combining scoring and shot data.
  ///
  /// Per AC2: returns scoring summary + shot metrics with incomplete-data warnings.
  /// Returns [RoundReviewMetrics] for the given [roundId] and [playerId].
  Future<RoundReviewMetrics> getRoundReviewMetrics({
    required String roundId,
    required String playerId,
  });
}
