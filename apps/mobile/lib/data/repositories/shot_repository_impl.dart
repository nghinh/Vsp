// Shot Repository Implementation — VSP Mobile App
//
// SQLite-backed implementation of ShotRepository.
//
// Story 10.3 — Slice 1: Domain + Persistence

import 'dart:math' as math;

import '../../domain/models/driving_zone_filter.dart';
import '../../domain/models/driving_zone_statistics.dart';
import '../../domain/models/incomplete_data_warning.dart';
import '../../domain/models/round_review_metrics.dart';
import '../../domain/models/shot.dart';
import '../../domain/models/shot_metrics.dart';
import '../../domain/models/sync_status.dart';
import '../../domain/repositories/shot_repository.dart';
import '../local/daos/shot_dao.dart';

/// SQLite-backed implementation of ShotRepository.
class ShotRepositoryImpl implements ShotRepository {
  final ShotDao _shotDao;

  ShotRepositoryImpl({ShotDao? shotDao}) : _shotDao = shotDao ?? ShotDao();

  @override
  Future<void> upsertShot(Shot shot) async {
    await _shotDao.upsert(shot);
  }

  @override
  Future<Shot?> getShotById(String id) async {
    return _shotDao.getById(id);
  }

  @override
  Future<Shot?> getShotByIdempotencyKey(String idempotencyKey) async {
    return _shotDao.getByIdempotencyKey(idempotencyKey);
  }

  @override
  Future<List<Shot>> getShotsForRound(String roundId) async {
    return _shotDao.getByRoundId(roundId);
  }

  @override
  Future<List<Shot>> getShotsForPlayer(String roundId, String playerId) async {
    return _shotDao.getByRoundAndPlayer(roundId, playerId);
  }

  @override
  Future<List<Shot>> getActiveShotsForRound(String roundId) async {
    return _shotDao.getActiveByRoundId(roundId);
  }

  @override
  Future<List<Shot>> getShotsBySyncStatus(SyncStatus status) async {
    return _shotDao.getBySyncStatus(status);
  }

  @override
  Future<List<Shot>> getPendingShotsForRound(String roundId) async {
    return _shotDao.getPendingByRoundId(roundId);
  }

  @override
  Future<void> deleteShot(String id) async {
    await _shotDao.softDelete(id);
  }

  @override
  Future<void> updateSyncStatus(String shotId, SyncStatus status) async {
    final shot = await _shotDao.getById(shotId);
    if (shot == null) return;
    final updated = shot.copyWith(
      syncStatus: status,
      updatedAt: DateTime.now(),
    );
    await _shotDao.upsert(updated);
  }

  @override
  Future<int> countShotsForRound(String roundId) async {
    return _shotDao.countByRoundId(roundId);
  }

  @override
  Future<List<Shot>> getShotsByFilter(DrivingZoneFilter filter) async {
    final shots = await _shotDao.getBySyncStatus(SyncStatus.synced);
    return shots.where((shot) {
      if (shot.playerId != filter.playerId || shot.isMerged) return false;
      if (filter.timeRange.start != null &&
          shot.startedAt.isBefore(filter.timeRange.start!)) {
        return false;
      }
      if (filter.timeRange.end != null &&
          shot.startedAt.isAfter(filter.timeRange.end!)) {
        return false;
      }
      if (filter.clubIds.isNotEmpty && !filter.clubIds.contains(shot.clubId)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<DrivingZoneStatistics> getDrivingZoneStats(
    DrivingZoneFilter filter,
  ) async {
    final shots = await getShotsByFilter(filter);
    final grouped = <String, List<Shot>>{};
    for (final shot in shots.where((shot) => shot.clubId != null)) {
      grouped
          .putIfAbsent('${shot.holeNumber}:${shot.clubId}', () => [])
          .add(shot);
    }
    final holeStats = grouped.entries.map((entry) {
      final group = entry.value;
      final distances = group
          .map((shot) => shot.distanceYards)
          .whereType<double>()
          .toList();
      return HoleZoneStats(
        holeNumber: group.first.holeNumber,
        clubId: group.first.clubId!,
        totalShots: group.length,
        zoneCells: const [],
        averageDistanceYards: distances.isEmpty
            ? null
            : distances.reduce((a, b) => a + b) / distances.length,
        averageDistanceMeters: distances.isEmpty
            ? null
            : distances.reduce((a, b) => a + b) * 0.9144 / distances.length,
        lastUpdated: group
            .map((shot) => shot.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b),
      );
    }).toList();
    return DrivingZoneStatistics(
      filter: filter,
      holeStats: holeStats,
      generatedAt: DateTime.now().toUtc(),
      isSampleInsufficient: shots.length < filter.minimumShotCount,
    );
  }

  @override
  Future<RoundReviewMetrics> getRoundReviewMetrics({
    required String roundId,
    required String playerId,
  }) async {
    final shots = (await _shotDao.getByRoundAndPlayer(
      roundId,
      playerId,
    )).where((shot) => !shot.isMerged).toList();
    final byClub = <String, List<Shot>>{};
    for (final shot in shots.where((shot) => shot.clubId != null)) {
      byClub.putIfAbsent(shot.clubId!, () => []).add(shot);
    }
    final clubMetrics = byClub.entries.map((entry) {
      final distances =
          entry.value
              .map((shot) => shot.distanceYards)
              .whereType<double>()
              .toList()
            ..sort();
      final average = distances.isEmpty
          ? null
          : distances.reduce((a, b) => a + b) / distances.length;
      final variance = average == null
          ? null
          : distances.fold<double>(
                  0,
                  (sum, value) => sum + math.pow(value - average, 2),
                ) /
                distances.length;
      final lieCounts = <String, int>{};
      for (final shot in entry.value.where((shot) => shot.lie != null)) {
        lieCounts.update(
          shot.lie!.name,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      final bestCount = entry.value
          .where(
            (shot) =>
                shot.result == ShotResult.fairwayHit ||
                shot.result == ShotResult.greenHit,
          )
          .length;
      return ClubShotMetrics(
        clubId: entry.key,
        totalShots: entry.value.length,
        averageDistanceYards: average,
        averageDistanceMeters: average == null ? null : average * 0.9144,
        medianDistanceYards: distances.isEmpty
            ? null
            : distances[distances.length ~/ 2],
        minDistanceYards: distances.isEmpty ? null : distances.first,
        maxDistanceYards: distances.isEmpty ? null : distances.last,
        standardDeviationYards: variance == null ? null : math.sqrt(variance),
        lieDistribution: lieCounts.entries
            .map(
              (lie) => LieDistribution(
                lie: lie.key,
                shotCount: lie.value,
                percentage: lie.value * 100 / entry.value.length,
              ),
            )
            .toList(),
        bestResultCount: bestCount,
        bestResultRate: entry.value.isEmpty
            ? null
            : bestCount * 100 / entry.value.length,
      );
    }).toList();
    final penalties = shots.where((shot) => shot.isPenalty).length;
    final now = DateTime.now().toUtc();
    return RoundReviewMetrics(
      scoring: RoundScoringSummary(
        roundId: roundId,
        playerId: playerId,
        totalGrossScore: shots.length + penalties,
        totalPenalties: penalties,
      ),
      shotMetrics: ShotMetrics(
        roundId: roundId,
        playerId: playerId,
        clubMetrics: clubMetrics,
        totalShots: shots.length,
      ),
      incompleteDataWarning: shots.length < 5
          ? IncompleteDataWarning.forTotalShots(
              requiredMinimum: 5,
              actualCount: shots.length,
              generatedAt: now,
            )
          : null,
      generatedAt: now,
    );
  }
}
