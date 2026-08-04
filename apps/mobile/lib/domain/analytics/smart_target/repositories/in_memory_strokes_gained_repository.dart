// InMemoryStrokesGainedRepository Stub — VSP Mobile App
//
// In-memory stub implementation of StrokesGainedRepository for testing.
//
// Story 11.4 — Slice 1: Data Access Interfaces + In-Memory Stubs

import 'strokes_gained_repository.dart';

/// In-memory stub for StrokesGainedRepository.
///
/// Provides synthetic data for unit testing without requiring
/// the full 11.3 implementation.
class InMemoryStrokesGainedRepository implements StrokesGainedRepository {
  final Map<String, StrokesGainedResult> _results = {};
  StrokesGainedSummary? _summary;

  InMemoryStrokesGainedRepository({
    List<StrokesGainedResult>? seeds,
    StrokesGainedSummary? summary,
  }) {
    if (seeds != null) {
      for (final r in seeds) {
        _results['${r.playerId}:${r.clubId}'] = r;
      }
    }
    _summary = summary;
  }

  void addResult(StrokesGainedResult result) {
    _results['${result.playerId}:${result.clubId}'] = result;
  }

  void setSummary(StrokesGainedSummary summary) {
    _summary = summary;
  }

  void clear() {
    _results.clear();
    _summary = null;
  }

  @override
  Future<StrokesGainedResult?> getByClub(String playerId, String clubId) async {
    return _results['$playerId:$clubId'];
  }

  @override
  Future<List<StrokesGainedResult>> getAllForPlayer(String playerId) async {
    return _results.values.where((r) => r.playerId == playerId).toList();
  }

  @override
  Future<StrokesGainedSummary?> getSummaryForPlayer(String playerId) async {
    return _summary?.playerId == playerId ? _summary : null;
  }
}
