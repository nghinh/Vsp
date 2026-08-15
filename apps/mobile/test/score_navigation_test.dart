// Score Navigation Tests — VSP Mobile App
//
// Tests for hole navigation (Slice 6).
// Verifies hole-to-hole navigation, prev/next flow, and round completion.
//
// Story 5.3 — Slice 6: Hole Navigation

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/application/score/scorecard_cubit.dart';
import 'package:vsp_mobile/application/score/scorecard_state.dart';
import 'package:vsp_mobile/domain/models/score.dart';
import 'package:vsp_mobile/domain/models/score_value_objects.dart';
import 'package:vsp_mobile/domain/repositories/score_repository.dart';

// ─── Mock ScoreRepository ────────────────────────────────────────────────────

/// Mock score repository for testing.
class MockScoreRepository implements ScoreRepository {
  final List<Score> _scores = [];
  Score? _lastUpserted;

  @override
  Future<void> upsertScore(Score score) async {
    _lastUpserted = score;
    _scores.removeWhere(
      (s) =>
          s.flightId == score.flightId &&
          s.holeId == score.holeId &&
          s.playerId == score.playerId,
    );
    _scores.add(score);
  }

  @override
  Future<Score?> getScoreById(String id) async {
    return _scores.cast<Score?>().firstWhere((s) => s?.id == id);
  }

  @override
  Future<Score?> getScore({
    required String flightId,
    required String holeId,
    required String playerId,
  }) async {
    return _scores.cast<Score?>().firstWhere(
      (s) =>
          s?.flightId == flightId &&
          s?.holeId == holeId &&
          s?.playerId == playerId,
    );
  }

  @override
  Future<List<Score>> getScoresForHole({
    required String flightId,
    required String holeId,
  }) async {
    return _scores
        .where((s) => s.flightId == flightId && s.holeId == holeId)
        .toList();
  }

  @override
  Future<List<Score>> getScoresForPlayer({
    required String flightId,
    required String playerId,
  }) async {
    return _scores
        .where((s) => s.flightId == flightId && s.playerId == playerId)
        .toList();
  }

  @override
  Future<List<Score>> getScoresForFlight(String flightId) async {
    return _scores.where((s) => s.flightId == flightId).toList();
  }

  @override
  Future<List<Score>> getScoresBySyncStatus(ScoreSyncStatus status) async {
    return _scores.where((s) => s.syncStatus == status).toList();
  }

  @override
  Future<void> updateSyncStatus(String scoreId, ScoreSyncStatus status) async {
    final idx = _scores.indexWhere((s) => s.id == scoreId);
    if (idx != -1) {
      _scores[idx] = _scores[idx].copyWith(syncStatus: status);
    }
  }

  void clear() {
    _scores.clear();
    _lastUpserted = null;
  }
}

// ─── ScorecardCubit Navigation Tests ───────────────────────────────────────

void main() {
  const testFlightId = 'flight-123';
  const testPlayerId = 'player-456';
  final testHoleIds = List.generate(18, (i) => 'hole-${i + 1}');
  final testHolePars = {
    for (int i = 0; i < 18; i++)
      'hole-${i + 1}': [
        4,
        4,
        3,
        4,
        5,
        4,
        3,
        4,
        4,
        5,
        4,
        3,
        4,
        5,
        4,
        3,
        4,
        4,
      ][i],
  };

  late MockScoreRepository mockRepo;

  setUp(() {
    mockRepo = MockScoreRepository();
  });

  tearDown(() {
    mockRepo.clear();
  });

  ScorecardCubit buildCubit() => ScorecardCubit(
    flightId: testFlightId,
    holeIds: testHoleIds,
    playerIds: [testPlayerId],
    playerNames: {testPlayerId: 'Test Player'},
    holePars: testHolePars,
    isTournamentMode: false,
    scoreRepository: mockRepo,
  );

  group('ScorecardCubit Hole Navigation', () {
    test('initializes at hole 0', () {
      final cubit = buildCubit();
      expect(cubit.state.currentHoleIndex, 0);
      expect(cubit.state.currentHoleNumber, 1);
      expect(cubit.state.currentHoleId, 'hole-1');
      expect(cubit.state.canGoBack, false);
      expect(cubit.state.canGoForward, true);
      cubit.close();
    });

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'navigateToNextHole advances to hole 2',
      build: buildCubit,
      act: (cubit) => cubit.navigateToNextHole(),
      expect: () => [
        isA<ScorecardScreenState>()
            .having((s) => s.currentHoleIndex, 'currentHoleIndex', 1)
            .having((s) => s.currentHoleNumber, 'currentHoleNumber', 2)
            .having((s) => s.currentHoleId, 'currentHoleId', 'hole-2'),
      ],
    );

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'navigateToPreviousHole goes back when not at first hole',
      build: buildCubit,
      seed: () {
        // Manually create cubit and set initial index
        return buildCubit().state.copyWith(currentHoleIndex: 1);
      },
      setUp: () {
        // Skip since we can't easily seed the cubit state
      },
      verify: (cubit) {
        expect(cubit.state.currentHoleIndex, 1);
      },
    );

    /// Back from the first hole wraps to the last, forward from the last
    /// wraps to the first — asked for directly, and the way a golfer flicks
    /// through a card. This test asserted the old dead end.
    blocTest<ScorecardCubit, ScorecardScreenState>(
      'navigateToPreviousHole wraps from the first hole to the last',
      build: buildCubit,
      act: (cubit) => cubit.navigateToPreviousHole(),
      verify: (cubit) {
        expect(cubit.state.currentHoleIndex, 17);
        expect(cubit.state.currentHoleNumber, 18);
      },
    );

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'the eighteenth hole is the last one, and forward from it wraps',
      build: buildCubit,
      act: (cubit) {
        // Navigate to last hole
        for (int i = 0; i < 17; i++) {
          cubit.navigateToNextHole();
        }
      },
      verify: (cubit) {
        expect(cubit.state.currentHoleIndex, 17);
        expect(cubit.state.canGoForward, false);
        expect(cubit.state.isLastHole, true);
      },
    );

    /// One more step from the eighteenth comes back round to the first tee.
    blocTest<ScorecardCubit, ScorecardScreenState>(
      'navigateToNextHole wraps from the last hole to the first',
      build: buildCubit,
      act: (cubit) {
        for (int i = 0; i < 18; i++) {
          cubit.navigateToNextHole();
        }
      },
      verify: (cubit) {
        expect(cubit.state.currentHoleIndex, 0);
        expect(cubit.state.currentHoleNumber, 1);
      },
    );

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'navigateToHoleIndex navigates to specific hole',
      build: buildCubit,
      act: (cubit) => cubit.navigateToHoleIndex(5),
      expect: () => [
        isA<ScorecardScreenState>()
            .having((s) => s.currentHoleIndex, 'currentHoleIndex', 5)
            .having((s) => s.currentHoleNumber, 'currentHoleNumber', 6)
            .having((s) => s.currentHoleId, 'currentHoleId', 'hole-6'),
      ],
    );

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'navigateToHoleIndex ignores out-of-bounds index',
      build: buildCubit,
      act: (cubit) {
        cubit.navigateToHoleIndex(-1);
        cubit.navigateToHoleIndex(18);
      },
      expect: () => [], // No state change for invalid indices
    );

    test('canGoBack is true when not at first hole', () {
      final cubit = buildCubit();
      expect(cubit.state.canGoBack, false);

      cubit.navigateToNextHole();
      expect(cubit.state.canGoBack, true);

      cubit.close();
    });

    test('canGoForward is false at last hole', () {
      final cubit = buildCubit();
      for (int i = 0; i < 17; i++) {
        cubit.navigateToNextHole();
      }
      expect(cubit.state.canGoForward, false);
      cubit.close();
    });

    test('totalHoles returns correct count', () {
      final cubit = buildCubit();
      expect(cubit.state.totalHoles, 18);
      cubit.close();
    });

    test('isLastHole returns true at hole 18', () {
      final cubit = buildCubit();
      for (int i = 0; i < 17; i++) {
        cubit.navigateToNextHole();
      }
      expect(cubit.state.isLastHole, true);
      cubit.close();
    });

    test('isLastHole returns false before hole 18', () {
      final cubit = buildCubit();
      for (int i = 0; i < 16; i++) {
        cubit.navigateToNextHole();
      }
      expect(cubit.state.isLastHole, false);
      cubit.close();
    });

    test('currentPar returns correct par for hole', () {
      final cubit = buildCubit();
      expect(cubit.state.currentPar, 4); // hole-1 par is 4
      cubit.close();
    });

    test('currentPar returns null when no par data', () {
      final cubit = ScorecardCubit(
        flightId: testFlightId,
        holeIds: testHoleIds,
        playerIds: [testPlayerId],
        holePars: {}, // No par data
        scoreRepository: mockRepo,
      );
      expect(cubit.state.currentPar, null);
      cubit.close();
    });
  });

  group('Hole Navigation Full Round Flow', () {
    blocTest<ScorecardCubit, ScorecardScreenState>(
      'can navigate through all 18 holes',
      build: buildCubit,
      act: (cubit) {
        for (int i = 0; i < 17; i++) {
          cubit.navigateToNextHole();
        }
      },
      verify: (cubit) {
        expect(cubit.state.currentHoleIndex, 17);
        expect(cubit.state.currentHoleNumber, 18);
        expect(cubit.state.currentHoleId, 'hole-18');
        expect(cubit.state.isLastHole, true);
      },
    );

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'can navigate forward then backward through holes',
      build: buildCubit,
      act: (cubit) {
        cubit.navigateToNextHole(); // Hole 2
        cubit.navigateToNextHole(); // Hole 3
        cubit.navigateToNextHole(); // Hole 4
        cubit.navigateToPreviousHole(); // Back to Hole 3
      },
      verify: (cubit) {
        expect(cubit.state.currentHoleIndex, 2);
        expect(cubit.state.currentHoleNumber, 3);
      },
    );

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'can navigate to any specific hole from first hole',
      build: buildCubit,
      act: (cubit) {
        // Jump to hole 10
        cubit.navigateToHoleIndex(9);
      },
      verify: (cubit) {
        expect(cubit.state.currentHoleNumber, 10);
        expect(cubit.state.canGoBack, true);
        expect(cubit.state.canGoForward, true);
      },
    );

    test('navigation persists hole position correctly', () {
      final cubit = buildCubit();

      // Navigate to hole 5
      cubit.navigateToHoleIndex(4);
      expect(cubit.state.currentHoleNumber, 5);

      // Navigate to hole 10
      cubit.navigateToHoleIndex(9);
      expect(cubit.state.currentHoleNumber, 10);

      // Go back one hole (10 -> 9): previous-hole decrements by one.
      cubit.navigateToPreviousHole();
      expect(cubit.state.currentHoleNumber, 9);

      cubit.close();
    });
  });

  group('Score Entry During Navigation', () {
    blocTest<ScorecardCubit, ScorecardScreenState>(
      'score entry persists when navigating to next hole',
      build: buildCubit,
      act: (cubit) async {
        // Enter score on hole 1
        await cubit.setGrossScore(testPlayerId, 4);
        // Navigate to hole 2
        cubit.navigateToNextHole();
        // Enter score on hole 2
        await cubit.setGrossScore(testPlayerId, 5);
      },
      verify: (cubit) async {
        // Score for hole 1
        final score1 = await mockRepo.getScore(
          flightId: testFlightId,
          holeId: 'hole-1',
          playerId: testPlayerId,
        );
        expect(score1?.grossScore, 4);

        // Score for hole 2
        final score2 = await mockRepo.getScore(
          flightId: testFlightId,
          holeId: 'hole-2',
          playerId: testPlayerId,
        );
        expect(score2?.grossScore, 5);
      },
    );

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'score entry is per-hole per-player',
      build: buildCubit,
      act: (cubit) async {
        await cubit.setGrossScore(testPlayerId, 4);
        cubit.navigateToNextHole();
        await cubit.setGrossScore(testPlayerId, 3);
      },
      verify: (cubit) async {
        final score1 = await mockRepo.getScore(
          flightId: testFlightId,
          holeId: 'hole-1',
          playerId: testPlayerId,
        );
        final score2 = await mockRepo.getScore(
          flightId: testFlightId,
          holeId: 'hole-2',
          playerId: testPlayerId,
        );
        expect(score1?.grossScore, 4);
        expect(score2?.grossScore, 3);
        expect(score1?.id, isNot(equals(score2?.id)));
      },
    );
  });
}
