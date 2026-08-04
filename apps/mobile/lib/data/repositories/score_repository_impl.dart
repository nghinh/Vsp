// Score Repository Implementation — VSP Mobile App
//
// SQLite-backed implementation of ScoreRepository.
// Uses ScoreDao for database operations.
//
// Story 5.3 — Slice 2: Score SQLite Persistence

import '../../domain/models/score.dart';
import '../../domain/models/score_value_objects.dart';
import '../../domain/repositories/score_repository.dart';
import '../local/daos/score_dao.dart';

/// SQLite-backed implementation of ScoreRepository.
class ScoreRepositoryImpl implements ScoreRepository {
  final ScoreDao _scoreDao;

  ScoreRepositoryImpl({ScoreDao? scoreDao})
    : _scoreDao = scoreDao ?? ScoreDao();

  @override
  Future<void> upsertScore(Score score) async {
    await _scoreDao.upsert(score);
  }

  @override
  Future<Score?> getScoreById(String id) async {
    return _scoreDao.getById(id);
  }

  @override
  Future<Score?> getScore({
    required String flightId,
    required String holeId,
    required String playerId,
  }) async {
    return _scoreDao.getByFlightHolePlayer(
      flightId: flightId,
      holeId: holeId,
      playerId: playerId,
    );
  }

  @override
  Future<List<Score>> getScoresForHole({
    required String flightId,
    required String holeId,
  }) async {
    return _scoreDao.getByFlightAndHole(flightId: flightId, holeId: holeId);
  }

  @override
  Future<List<Score>> getScoresForPlayer({
    required String flightId,
    required String playerId,
  }) async {
    return _scoreDao.getByFlightAndPlayer(
      flightId: flightId,
      playerId: playerId,
    );
  }

  @override
  Future<List<Score>> getScoresForFlight(String flightId) async {
    return _scoreDao.getByFlightId(flightId);
  }

  @override
  Future<List<Score>> getScoresBySyncStatus(ScoreSyncStatus status) async {
    return _scoreDao.getBySyncStatus(status);
  }

  @override
  Future<void> updateSyncStatus(String scoreId, ScoreSyncStatus status) async {
    final score = await _scoreDao.getById(scoreId);
    if (score == null) return;
    final updated = score.copyWith(
      syncStatus: status,
      updatedAt: DateTime.now(),
    );
    await _scoreDao.upsert(updated);
  }
}
