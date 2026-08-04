// Score Repository Interface — VSP Mobile App
//
// Abstract repository interface for Score persistence.
// Implementations: ScoreRepositoryImpl (SQLite).
//
// Story 5.3 — Slice 2: Score SQLite Persistence

import '../models/score.dart';
import '../models/score_value_objects.dart';

/// Repository interface for Score persistence operations.
///
/// Abstracted to allow different persistence backends (SQLite, mock for tests).
abstract class ScoreRepository {
  /// Persist a score (insert or update).
  /// Uses upsert semantics: creates if not exists, updates if exists.
  Future<void> upsertScore(Score score);

  /// Get a score by its unique ID.
  Future<Score?> getScoreById(String id);

  /// Get the score for a specific player on a specific hole within a flight.
  /// Returns null if no score exists yet.
  Future<Score?> getScore({
    required String flightId,
    required String holeId,
    required String playerId,
  });

  /// Get all scores for a specific hole within a flight.
  Future<List<Score>> getScoresForHole({
    required String flightId,
    required String holeId,
  });

  /// Get all scores for a specific player within a flight.
  Future<List<Score>> getScoresForPlayer({
    required String flightId,
    required String playerId,
  });

  /// Get all scores for a flight.
  Future<List<Score>> getScoresForFlight(String flightId);

  /// Get all scores with a specific sync status.
  Future<List<Score>> getScoresBySyncStatus(ScoreSyncStatus status);

  /// Update the sync status of a score.
  Future<void> updateSyncStatus(String scoreId, ScoreSyncStatus status);
}
