// InMemoryClubPerformanceRepository Stub — VSP Mobile App
//
// In-memory stub implementation of ClubPerformanceRepository for testing.
//
// Story 11.4 — Slice 1: Data Access Interfaces + In-Memory Stubs

import 'club_performance_repository.dart';

/// In-memory stub for ClubPerformanceRepository.
///
/// Provides synthetic data for unit testing without requiring
/// the full 11.1 implementation.
class InMemoryClubPerformanceRepository implements ClubPerformanceRepository {
  final Map<String, ClubPerformanceStats> _stats = {};

  InMemoryClubPerformanceRepository({List<ClubPerformanceStats>? seeds}) {
    if (seeds != null) {
      for (final stat in seeds) {
        _stats[stat.clubId] = stat;
      }
    }
  }

  void addStats(ClubPerformanceStats stats) {
    _stats[stats.clubId] = stats;
  }

  void clear() => _stats.clear();

  @override
  Future<ClubPerformanceStats?> getByClubId(String clubId) async {
    return _stats[clubId];
  }

  @override
  Future<List<ClubPerformanceStats>> getAllForPlayer(String playerId) async {
    // Player ID not used in stub — return all.
    return _stats.values.toList();
  }

  @override
  Future<List<ClubPerformanceStats>> getReliableClubs(
    String playerId, {
    int minSampleCount = 5,
  }) async {
    return _stats.values.where((s) => s.sampleCount >= minSampleCount).toList();
  }

  @override
  Future<bool> hasSufficientData(String playerId, {int minClubs = 3}) async {
    return _stats.values.length >= minClubs;
  }
}
