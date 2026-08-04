// Driving Zone Cubit Tests — VSP Mobile App
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/driving_zone_filter.dart';
import 'package:vsp_mobile/domain/models/driving_zone_statistics.dart';
import 'package:vsp_mobile/domain/models/shot.dart';
import 'package:vsp_mobile/domain/models/round_review_metrics.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';
import 'package:vsp_mobile/domain/repositories/shot_repository.dart';
import 'package:vsp_mobile/presentation/cubit/driving_zone/driving_zone_cubit.dart';
import 'package:vsp_mobile/presentation/cubit/driving_zone/driving_zone_state.dart';

// ─── Mock Repository ─────────────────────────────────────────────────────────

class MockShotRepository implements ShotRepository {
  DrivingZoneFilter? lastFilter;
  DrivingZoneStatistics? mockStats;
  Exception? mockError;

  @override
  Future<List<Shot>> getShotsByFilter(DrivingZoneFilter filter) async => [];

  @override
  Future<DrivingZoneStatistics> getDrivingZoneStats(DrivingZoneFilter filter) async {
    lastFilter = filter;
    if (mockError != null) throw mockError!;
    return mockStats ?? _emptyStats(filter);
  }

  @override
  Future<RoundReviewMetrics> getRoundReviewMetrics({
    required String roundId,
    required String playerId,
  }) async => throw UnimplementedError();

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

  DrivingZoneStatistics _emptyStats(DrivingZoneFilter filter) {
    return DrivingZoneStatistics(
      filter: filter,
      holeStats: const [],
      generatedAt: DateTime.now(),
      isSampleInsufficient: true,
    );
  }
}

void main() {
  group('DrivingZoneCubit', () {
    late MockShotRepository mockRepo;

    setUp(() {
      mockRepo = MockShotRepository();
    });

    test('initial state is DrivingZoneInitial', () {
      final cubit = DrivingZoneCubit(shotRepository: mockRepo);
      expect(cubit.state, isA<DrivingZoneInitial>());
      cubit.close();
    });

    test('currentFilter is null until first load', () {
      final cubit = DrivingZoneCubit(shotRepository: mockRepo);
      expect(cubit.currentFilter, isNull);
      cubit.close();
    });

    blocTest<DrivingZoneCubit, DrivingZoneState>(
      'loadWithFilter emits [Loading, Empty] when no shots found',
      setUp: () {
        mockRepo.mockStats = DrivingZoneStatistics(
          filter: DrivingZoneFilter.defaultFilter(playerId: 'p1'),
          holeStats: const [],
          generatedAt: DateTime.now(),
          isSampleInsufficient: true,
        );
      },
      build: () => DrivingZoneCubit(shotRepository: mockRepo),
      act: (cubit) => cubit.loadWithFilter(
        DrivingZoneFilter.defaultFilter(playerId: 'p1'),
      ),
      expect: () => [
        isA<DrivingZoneLoading>(),
        isA<DrivingZoneEmpty>(),
      ],
    );

    blocTest<DrivingZoneCubit, DrivingZoneState>(
      'loadWithFilter emits [Loading, Loaded] when stats are available',
      setUp: () {
        mockRepo.mockStats = DrivingZoneStatistics(
          filter: DrivingZoneFilter.defaultFilter(playerId: 'p1'),
          holeStats: [
            HoleZoneStats(
              holeNumber: 1,
              clubId: 'driver',
              totalShots: 30,
              zoneCells: const [],
            ),
          ],
          generatedAt: DateTime.now(),
          isSampleInsufficient: false,
        );
      },
      build: () => DrivingZoneCubit(shotRepository: mockRepo),
      act: (cubit) => cubit.loadWithFilter(
        DrivingZoneFilter.defaultFilter(playerId: 'p1'),
      ),
      expect: () => [
        isA<DrivingZoneLoading>(),
        isA<DrivingZoneLoaded>(),
      ],
    );

    blocTest<DrivingZoneCubit, DrivingZoneState>(
      'loadWithFilter emits [Loading, Error] when repository throws',
      setUp: () {
        mockRepo.mockError = Exception('Network error');
      },
      build: () => DrivingZoneCubit(shotRepository: mockRepo),
      act: (cubit) => cubit.loadWithFilter(
        DrivingZoneFilter.defaultFilter(playerId: 'p1'),
      ),
      expect: () => [
        isA<DrivingZoneLoading>(),
        isA<DrivingZoneError>(),
      ],
    );

    blocTest<DrivingZoneCubit, DrivingZoneState>(
      'updateTimeRange calls loadWithFilter with new time range',
      setUp: () {
        mockRepo.mockStats = DrivingZoneStatistics(
          filter: DrivingZoneFilter.defaultFilter(playerId: 'p1'),
          holeStats: const [],
          generatedAt: DateTime.now(),
        );
      },
      build: () => DrivingZoneCubit(shotRepository: mockRepo),
      act: (cubit) async {
        await cubit.loadWithFilter(
          DrivingZoneFilter.defaultFilter(playerId: 'p1'),
        );
        await cubit.updateTimeRange(TimeRange.last30Days());
      },
      verify: (_) {
        expect(mockRepo.lastFilter!.timeRange.isEmpty, false);
      },
    );

    blocTest<DrivingZoneCubit, DrivingZoneState>(
      'retry re-loads the last filter',
      setUp: () {
        mockRepo.mockError = Exception('Network error');
      },
      build: () => DrivingZoneCubit(shotRepository: mockRepo),
      act: (cubit) async {
        await cubit.loadWithFilter(
          DrivingZoneFilter.defaultFilter(playerId: 'p1'),
        );
        mockRepo.mockError = null;
        mockRepo.mockStats = DrivingZoneStatistics(
          filter: DrivingZoneFilter.defaultFilter(playerId: 'p1'),
          holeStats: const [],
          generatedAt: DateTime.now(),
        );
        await cubit.retry();
      },
      expect: () => [
        isA<DrivingZoneLoading>(),
        isA<DrivingZoneError>(),
        isA<DrivingZoneLoading>(),
        isA<DrivingZoneEmpty>(),
      ],
    );
  });
}
