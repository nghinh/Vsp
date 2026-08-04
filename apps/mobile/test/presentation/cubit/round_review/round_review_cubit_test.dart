// Round Review Cubit Tests — VSP Mobile App
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/round_review_metrics.dart';
import 'package:vsp_mobile/domain/models/shot_metrics.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';
import 'package:vsp_mobile/domain/models/shot.dart';
import 'package:vsp_mobile/domain/models/driving_zone_filter.dart';
import 'package:vsp_mobile/domain/models/driving_zone_statistics.dart';
import 'package:vsp_mobile/domain/repositories/shot_repository.dart';
import 'package:vsp_mobile/presentation/cubit/round_review/round_review_cubit.dart';
import 'package:vsp_mobile/presentation/cubit/round_review/round_review_state.dart';

// ─── Mock Repository ─────────────────────────────────────────────────────────

class MockShotRepository implements ShotRepository {
  RoundReviewMetrics? mockMetrics;
  Exception? mockError;

  @override
  Future<RoundReviewMetrics> getRoundReviewMetrics({
    required String roundId,
    required String playerId,
  }) async {
    if (mockError != null) throw mockError!;
    return mockMetrics ?? _emptyMetrics(roundId, playerId);
  }

  @override
  Future<List<Shot>> getShotsByFilter(DrivingZoneFilter filter) async => [];

  @override
  Future<DrivingZoneStatistics> getDrivingZoneStats(DrivingZoneFilter filter) async =>
      throw UnimplementedError();

  // Stub remaining repository methods
  @override
  Future<void> upsertShot(Shot shot) async {}
  @override
  Future<Shot?> getShotById(String id) async => null;
  @override
  Future<Shot?> getShotByIdempotencyKey(String key) async => null;
  @override
  Future<List<Shot>> getShotsForRound(String roundId) async => [];
  @override
  Future<List<Shot>> getShotsForPlayer(String roundId, String playerId) async => [];
  @override
  Future<List<Shot>> getActiveShotsForRound(String roundId) async => [];
  @override
  Future<List<Shot>> getShotsBySyncStatus(SyncStatus status) async => [];
  @override
  Future<List<Shot>> getPendingShotsForRound(String roundId) async => [];
  @override
  Future<void> deleteShot(String id) async {}
  @override
  Future<void> updateSyncStatus(String shotId, SyncStatus status) async {}
  @override
  Future<int> countShotsForRound(String roundId) async => 0;

  RoundReviewMetrics _emptyMetrics(String roundId, String playerId) {
    return RoundReviewMetrics(
      scoring: RoundScoringSummary(
        roundId: roundId,
        playerId: playerId,
        totalGrossScore: 0,
      ),
      shotMetrics: const ShotMetrics(),
      generatedAt: DateTime.now(),
    );
  }
}

void main() {
  group('RoundReviewCubit', () {
    late MockShotRepository mockRepo;

    setUp(() {
      mockRepo = MockShotRepository();
    });

    test('initial state is RoundReviewInitial', () {
      final cubit = RoundReviewCubit(shotRepository: mockRepo);
      expect(cubit.state, isA<RoundReviewInitial>());
      cubit.close();
    });

    test('currentRoundId and currentPlayerId are null until first load', () {
      final cubit = RoundReviewCubit(shotRepository: mockRepo);
      expect(cubit.currentRoundId, isNull);
      expect(cubit.currentPlayerId, isNull);
      cubit.close();
    });

    blocTest<RoundReviewCubit, RoundReviewState>(
      'loadRoundReview emits [Loading, Loaded] when metrics available',
      setUp: () {
        mockRepo.mockMetrics = RoundReviewMetrics(
          scoring: const RoundScoringSummary(
            roundId: 'round-1',
            playerId: 'player-1',
            totalGrossScore: 80,
          ),
          shotMetrics: const ShotMetrics(totalShots: 42),
          generatedAt: DateTime.now(),
        );
      },
      build: () => RoundReviewCubit(shotRepository: mockRepo),
      act: (cubit) => cubit.loadRoundReview(
        roundId: 'round-1',
        playerId: 'player-1',
      ),
      expect: () => [
        isA<RoundReviewLoading>(),
        isA<RoundReviewLoaded>(),
      ],
    );

    blocTest<RoundReviewCubit, RoundReviewState>(
      'loadRoundReview emits [Loading, Error] when repository throws',
      setUp: () {
        mockRepo.mockError = Exception('Network error');
      },
      build: () => RoundReviewCubit(shotRepository: mockRepo),
      act: (cubit) => cubit.loadRoundReview(
        roundId: 'round-1',
        playerId: 'player-1',
      ),
      expect: () => [
        isA<RoundReviewLoading>(),
        isA<RoundReviewError>(),
      ],
    );

    blocTest<RoundReviewCubit, RoundReviewState>(
      'retry re-loads the last round',
      setUp: () {
        mockRepo.mockError = Exception('Network error');
      },
      build: () => RoundReviewCubit(shotRepository: mockRepo),
      act: (cubit) async {
        await cubit.loadRoundReview(
          roundId: 'round-1',
          playerId: 'player-1',
        );
        mockRepo.mockError = null;
        mockRepo.mockMetrics = RoundReviewMetrics(
          scoring: const RoundScoringSummary(
            roundId: 'round-1',
            playerId: 'player-1',
            totalGrossScore: 80,
          ),
          shotMetrics: const ShotMetrics(),
          generatedAt: DateTime.now(),
        );
        await cubit.retry();
      },
      expect: () => [
        isA<RoundReviewLoading>(),
        isA<RoundReviewError>(),
        isA<RoundReviewLoading>(),
        isA<RoundReviewLoaded>(),
      ],
    );

    blocTest<RoundReviewCubit, RoundReviewState>(
      'retry does nothing when no prior load',
      build: () => RoundReviewCubit(shotRepository: mockRepo),
      act: (cubit) => cubit.retry(),
      expect: () => [],
    );
  });
}
