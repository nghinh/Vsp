// Strokes Gained Repository Implementation — VSP Mobile App
//
// SQLite-backed implementation of StrokesGainedRepository.
//
// Story 11.3 — Slice 2: Repository + OpenAPI

import '../../domain/models/strokes_gained.dart';
import '../../domain/repositories/strokes_gained_repository.dart';
import '../local/daos/strokes_gained_dao.dart';

/// SQLite-backed implementation of StrokesGainedRepository.
class StrokesGainedRepositoryImpl implements StrokesGainedRepository {
  final StrokesGainedDao _dao;

  StrokesGainedRepositoryImpl({StrokesGainedDao? dao})
    : _dao = dao ?? StrokesGainedDao();

  @override
  Future<void> saveSummary(StrokesGainedSummary summary) async {
    await _dao.upsertSummary(summary);
  }

  @override
  Future<StrokesGainedSummary?> getSummaryByRound(
    String playerId,
    String roundId,
  ) async {
    return _dao.getSummaryByRound(playerId, roundId);
  }

  @override
  Future<StrokesGainedSummary?> getSummaryByDateRange(
    String playerId,
    DateTime start,
    DateTime end,
  ) async {
    return _dao.getSummaryByDateRange(playerId, start, end);
  }

  @override
  Future<List<StrokesGainedSummary>> getSummariesByPlayer(
    String playerId,
  ) async {
    return _dao.getSummariesByPlayer(playerId);
  }

  @override
  Future<void> deleteSummary(String id) async {
    await _dao.deleteSummary(id);
  }

  @override
  Future<void> saveBenchmark(SGBenchmarkData benchmark, String playerId) async {
    await _dao.upsertBenchmark(benchmark, playerId);
  }

  @override
  Future<SGBenchmarkData?> getBenchmark(
    String playerId,
    SGBenchmarkType type,
    SGCategory category,
  ) async {
    return _dao.getBenchmark(playerId, type, category);
  }

  @override
  Future<List<SGBenchmarkData>> getBenchmarksByType(
    String playerId,
    SGBenchmarkType type,
  ) async {
    return _dao.getBenchmarksByType(playerId, type);
  }
}
