// Target Repository Interface — VSP Mobile App
//
// Repository interface for target persistence and retrieval.
// Abstracts SQLite local storage so the cubit remains testable.
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import '../domain/target_model.dart';

/// Repository interface for target persistence.
///
/// Implementations handle SQLite local storage via TargetLocalStore.
/// The interface is designed to be stubbable for testing and
/// future server sync (if multi-device sharing is added).
abstract class TargetRepository {
  /// Persists a target. Upserts by id.
  Future<void> saveTarget(TargetModel target);

  /// Retrieves the target for a given round + hole, or null if none exists.
  Future<TargetModel?> getTarget(String roundId, int holeNumber);

  /// Removes the target for a given round + hole.
  Future<void> deleteTarget(String roundId, int holeNumber);

  /// Returns all targets for a round.
  Future<List<TargetModel>> getTargetsForRound(String roundId);

  /// Closes the underlying database connection.
  Future<void> close();
}
