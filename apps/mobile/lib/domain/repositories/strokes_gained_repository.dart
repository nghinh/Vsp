// Strokes Gained Repository Interface — VSP Mobile App
//
// Abstract repository interface for Strokes Gained persistence.
// Implementations: StrokesGainedRepositoryImpl (SQLite).
//
// Story 11.3 — Slice 2: Repository + OpenAPI

import '../models/strokes_gained.dart';

/// Repository interface for Strokes Gained persistence operations.
abstract class StrokesGainedRepository {
  /// Persist a Strokes Gained summary.
  Future<void> saveSummary(StrokesGainedSummary summary);

  /// Get the most recent Strokes Gained summary for a player and round.
  Future<StrokesGainedSummary?> getSummaryByRound(
    String playerId,
    String roundId,
  );

  /// Get the most recent Strokes Gained summary for a player within a date range.
  Future<StrokesGainedSummary?> getSummaryByDateRange(
    String playerId,
    DateTime start,
    DateTime end,
  );

  /// Get all Strokes Gained summaries for a player.
  Future<List<StrokesGainedSummary>> getSummariesByPlayer(String playerId);

  /// Delete a Strokes Gained summary by ID.
  Future<void> deleteSummary(String id);

  /// Save benchmark data for a player.
  Future<void> saveBenchmark(SGBenchmarkData benchmark, String playerId);

  /// Get benchmark data for a player, type, and category.
  Future<SGBenchmarkData?> getBenchmark(
    String playerId,
    SGBenchmarkType type,
    SGCategory category,
  );

  /// Get all benchmarks for a player and type.
  Future<List<SGBenchmarkData>> getBenchmarksByType(
    String playerId,
    SGBenchmarkType type,
  );
}
