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
import 'package:vsp_mobile/domain/models/score.dart';
import 'package:vsp_mobile/domain/models/score_value_objects.dart';
import 'package:vsp_mobile/domain/repositories/score_repository.dart';
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

/// A card the cubit can read without a database behind it.
class FakeScoreRepository implements ScoreRepository {
  FakeScoreRepository(this.scores);

  final List<Score> scores;

  @override
  Future<List<Score>> getScoresForFlight(String flightId) async =>
      scores.where((s) => s.flightId == flightId).toList();

  @override
  Future<void> upsertScore(Score score) async {}
  @override
  Future<Score?> getScoreById(String id) async => null;
  @override
  Future<Score?> getScore({
    required String flightId,
    required String holeId,
    required String playerId,
  }) async => null;
  @override
  Future<List<Score>> getScoresForHole({
    required String flightId,
    required String holeId,
  }) async => [];
  @override
  Future<List<Score>> getScoresForPlayer({
    required String flightId,
    required String playerId,
  }) async => [];
  @override
  Future<List<Score>> getScoresBySyncStatus(ScoreSyncStatus status) async => [];
  @override
  Future<void> updateSyncStatus(String scoreId, ScoreSyncStatus status) async {}
}

Score _card({
  required String flightId,
  required String holeId,
  required String playerId,
  required int grossScore,
  int? putts,
}) => Score(
  id: '${flightId}_${holeId}_$playerId',
  flightId: flightId,
  holeId: holeId,
  playerId: playerId,
  grossScore: grossScore,
  putts: putts,
  updatedAt: DateTime.utc(2026, 8, 12),
);

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

    // A golfer who keeps a card but tracks no shots is the ordinary case: the
    // shot store then knows neither the score nor where it was played, and the
    // screen reported "Unknown Course" and a gross of nothing.
    test('a card with no shots still reports its strokes and its course', () async {
      final cubit = RoundReviewCubit(
        shotRepository: mockRepo,
        scoreRepository: FakeScoreRepository([
          _card(
            flightId: 'round-1',
            holeId: 'hole-1',
            playerId: 'player-1',
            grossScore: 5,
            putts: 2,
          ),
          _card(
            flightId: 'round-1',
            holeId: 'hole-2',
            playerId: 'player-1',
            grossScore: 4,
            putts: 1,
          ),
        ]),
      );

      await cubit.loadRoundReview(
        roundId: 'round-1',
        playerId: 'player-1',
        courseName: 'Tân Sơn Nhất',
        roundDate: DateTime.utc(2026, 8, 12),
      );

      final state = cubit.state as RoundReviewLoaded;
      expect(state.metrics.scoring.totalGrossScore, 9);
      expect(state.metrics.scoring.totalPutts, 3);
      expect(state.metrics.courseName, 'Tân Sơn Nhất');
      expect(state.metrics.roundDate, DateTime.utc(2026, 8, 12));
      await cubit.close();
    });

    test('a playing partner\'s card is not read as the golfer\'s own', () async {
      final cubit = RoundReviewCubit(
        shotRepository: mockRepo,
        scoreRepository: FakeScoreRepository([
          _card(
            flightId: 'round-1',
            holeId: 'hole-1',
            playerId: 'partner-9',
            grossScore: 7,
          ),
        ]),
      );

      await cubit.loadRoundReview(roundId: 'round-1', playerId: 'player-1');

      final state = cubit.state as RoundReviewLoaded;
      expect(state.metrics.scoring.totalGrossScore, 0);
      await cubit.close();
    });

    // Round totals alone left a golfer unable to see what they shot on any
    // given hole.
    test('the card is reported hole by hole, in order', () async {
      final cubit = RoundReviewCubit(
        shotRepository: mockRepo,
        scoreRepository: FakeScoreRepository([
          _card(
            flightId: 'round-1',
            holeId: '3',
            playerId: 'player-1',
            grossScore: 6,
            putts: 2,
          ),
          _card(
            flightId: 'round-1',
            holeId: '1',
            playerId: 'player-1',
            grossScore: 4,
            putts: 1,
          ),
        ]),
      );

      await cubit.loadRoundReview(roundId: 'round-1', playerId: 'player-1');

      final state = cubit.state as RoundReviewLoaded;
      expect(state.holeScores.map((h) => h.holeNumber), [1, 3]);
      expect(state.holeScores.map((h) => h.strokes), [4, 6]);
      expect(state.holeScores.map((h) => h.putts), [1, 2]);
      // No course was named, so no par is known — reported as 0 rather than
      // guessed.
      expect(state.holeScores.every((h) => h.par == 0), isTrue);
      await cubit.close();
    });

    test('retry keeps the course the caller named', () async {
      final cubit = RoundReviewCubit(
        shotRepository: mockRepo,
        scoreRepository: FakeScoreRepository(const []),
      );

      await cubit.loadRoundReview(
        roundId: 'round-1',
        playerId: 'player-1',
        courseName: 'Tân Sơn Nhất',
      );
      await cubit.retry();

      final state = cubit.state as RoundReviewLoaded;
      expect(state.metrics.courseName, 'Tân Sơn Nhất');
      await cubit.close();
    });
  });
}
