// Scorecard Integration Tests — VSP Mobile App
//
// End-to-end integration tests for the scorecard feature.
// Tests: full round flow (hole 1-18), score persistence, offline recovery.
//
// Story 5.3 — Slice 7: Integration & Full Round Flow

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/application/score/scorecard_cubit.dart';
import 'package:vsp_mobile/application/score/scorecard_state.dart';
import 'package:vsp_mobile/domain/models/score.dart';
import 'package:vsp_mobile/domain/models/score_value_objects.dart';
import 'package:vsp_mobile/domain/repositories/score_repository.dart';

// ─── Mock ScoreRepository with Persistence ─────────────────────────────────

/// Mock score repository that persists scores in memory for integration testing.
class MockScoreRepository implements ScoreRepository {
  final Map<String, Score> _scoreMap = {};
  final List<Score> _scores = [];

  Score? _lastUpserted;

  @override
  Future<void> upsertScore(Score score) async {
    _lastUpserted = score;
    final key = '${score.flightId}_${score.holeId}_${score.playerId}';
    _scoreMap[key] = score;
    _scores.removeWhere((s) =>
        s.flightId == score.flightId &&
        s.holeId == score.holeId &&
        s.playerId == score.playerId);
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
    final key = '${flightId}_${holeId}_$playerId';
    return _scoreMap[key];
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
    _scoreMap.clear();
    _scores.clear();
    _lastUpserted = null;
  }

  int get scoreCount => _scores.length;
}

// ─── Test Helpers ─────────────────────────────────────────────────────────────

const testFlightId = 'flight-integration-test';
const testPlayer1 = 'player-1';
const testPlayer2 = 'player-2';
const testPlayer3 = 'player-3';
const testPlayer4 = 'player-4';

final testHoleIds = List.generate(18, (i) => 'hole-${i + 1}');
final testHolePars = {
  for (int i = 0; i < 18; i++)
    'hole-${i + 1}': [4, 4, 3, 4, 5, 4, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 4][i]
};

List<String> get playerIds => [testPlayer1, testPlayer2, testPlayer3, testPlayer4];

ScorecardCubit buildTestCubit(MockScoreRepository repo) => ScorecardCubit(
      flightId: testFlightId,
      holeIds: testHoleIds,
      playerIds: playerIds,
      playerNames: {
        testPlayer1: 'Nguyen Van A',
        testPlayer2: 'Tran Van B',
        testPlayer3: 'Le Van C',
        testPlayer4: 'Ho Van D',
      },
      holePars: testHolePars,
      isTournamentMode: false,
      scoreRepository: repo,
    );

// ─── Integration Tests ─────────────────────────────────────────────────────────

void main() {
  group('Scorecard Integration — Full Round Flow', () {
    late MockScoreRepository repo;

    setUp(() {
      repo = MockScoreRepository();
    });

    tearDown(() {
      repo.clear();
    });

    test('initial state is at hole 1', () {
      final cubit = buildTestCubit(repo);
      expect(cubit.state.currentHoleIndex, 0);
      expect(cubit.state.currentHoleNumber, 1);
      expect(cubit.state.totalHoles, 18);
      expect(cubit.state.isOffline, false);
      cubit.close();
    });

    test('can enter score on all 18 holes for one player', () async {
      final cubit = buildTestCubit(repo);

      for (int hole = 0; hole < 18; hole++) {
        // Navigate to hole
        if (hole > 0) {
          cubit.navigateToNextHole();
        }

        // Enter a score (par + some variation)
        final score = testHolePars[testHoleIds[hole]]! + (hole % 3);
        await cubit.setGrossScore(testPlayer1, score);
      }

      // Verify all 18 scores are stored
      expect(repo.scoreCount, 18);

      // Verify each hole has the correct score
      for (int hole = 0; hole < 18; hole++) {
        final score = await repo.getScore(
          flightId: testFlightId,
          holeId: testHoleIds[hole],
          playerId: testPlayer1,
        );
        expect(score, isNotNull);
        expect(score?.grossScore, testHolePars[testHoleIds[hole]]! + (hole % 3));
      }

      cubit.close();
    });

    test('can enter scores for all 4 players on all 18 holes', () async {
      final cubit = buildTestCubit(repo);

      for (int hole = 0; hole < 18; hole++) {
        if (hole > 0) {
          cubit.navigateToNextHole();
        }

        // Enter scores for all 4 players
        for (final playerId in playerIds) {
          final basePar = testHolePars[testHoleIds[hole]]!;
          final playerVariation = playerIds.indexOf(playerId);
          await cubit.setGrossScore(playerId, basePar + playerVariation);
        }
      }

      // Should have 72 total scores (18 holes × 4 players)
      expect(repo.scoreCount, 72);

      // Verify each player has 18 scores
      for (final playerId in playerIds) {
        final playerScores = await repo.getScoresForPlayer(
          flightId: testFlightId,
          playerId: playerId,
        );
        expect(playerScores.length, 18);
      }

      cubit.close();
    });

    test('offline flag is set when scores are entered', () async {
      final cubit = buildTestCubit(repo);

      expect(cubit.state.isOffline, false);

      await cubit.setGrossScore(testPlayer1, 4);

      expect(cubit.state.isOffline, true);

      cubit.close();
    });

    test('scores have correct sync status (local)', () async {
      final cubit = buildTestCubit(repo);

      await cubit.setGrossScore(testPlayer1, 4);
      await cubit.setGrossScore(testPlayer2, 5);

      final score1 = await repo.getScore(
        flightId: testFlightId,
        holeId: 'hole-1',
        playerId: testPlayer1,
      );
      final score2 = await repo.getScore(
        flightId: testFlightId,
        holeId: 'hole-1',
        playerId: testPlayer2,
      );

      expect(score1?.syncStatus, ScoreSyncStatus.local);
      expect(score2?.syncStatus, ScoreSyncStatus.local);
      expect(score1?.version, 1);
      expect(score2?.version, 1);

      cubit.close();
    });

    blocTest<ScorecardCubit, ScorecardScreenState>(
      'loadScores recovers persisted scores on init',
      build: () {
        final cubit = buildTestCubit(repo);
        return cubit;
      },
      act: (cubit) async {
        // Enter some scores
        await cubit.setGrossScore(testPlayer1, 4);
        await cubit.setGrossScore(testPlayer2, 5);
        cubit.navigateToNextHole();
        await cubit.setGrossScore(testPlayer1, 3);
      },
      verify: (cubit) async {
        // Create a new cubit with same repo (simulating app restart)
        final newCubit = buildTestCubit(repo);
        await newCubit.loadScores();

        expect(newCubit.state.scores.isNotEmpty, true);

        // Verify scores are recovered
        final score1 = newCubit.state.getScore(testPlayer1, 'hole-1');
        final score2 = newCubit.state.getScore(testPlayer2, 'hole-1');
        final score3 = newCubit.state.getScore(testPlayer1, 'hole-2');

        expect(score1?.grossScore, 4);
        expect(score2?.grossScore, 5);
        expect(score3?.grossScore, 3);

        newCubit.close();
      },
    );

    test('can update score after navigating away and back', () async {
      final cubit = buildTestCubit(repo);

      // Enter score on hole 1
      await cubit.setGrossScore(testPlayer1, 4);
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.grossScore, 4);

      // Navigate to hole 2
      cubit.navigateToNextHole();
      expect(cubit.state.currentHoleNumber, 2);

      // Navigate back to hole 1
      cubit.navigateToPreviousHole();
      expect(cubit.state.currentHoleNumber, 1);

      // Update score on hole 1
      await cubit.setGrossScore(testPlayer1, 5);
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.grossScore, 5);

      // Navigate to hole 2 and back to hole 1
      cubit.navigateToNextHole();
      cubit.navigateToPreviousHole();
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.grossScore, 5);

      cubit.close();
    });

    test('can enter progressive fields along with gross score', () async {
      final cubit = buildTestCubit(repo);

      await cubit.setGrossScore(testPlayer1, 4);
      await cubit.incrementPutts(testPlayer1);
      await cubit.incrementPutts(testPlayer1);
      await cubit.incrementPenalties(testPlayer1);

      final score = await repo.getScore(
        flightId: testFlightId,
        holeId: 'hole-1',
        playerId: testPlayer1,
      );

      expect(score?.grossScore, 4);
      expect(score?.putts, 2);
      expect(score?.penalties, 1);

      cubit.close();
    });

    test('setFairwayHit, setGir, setBunker work correctly', () async {
      final cubit = buildTestCubit(repo);

      await cubit.setGrossScore(testPlayer1, 4);
      await cubit.setFairwayHit(testPlayer1, true);
      await cubit.setGir(testPlayer1, true);
      await cubit.setBunker(testPlayer1, false);

      final score = await repo.getScore(
        flightId: testFlightId,
        holeId: 'hole-1',
        playerId: testPlayer1,
      );

      expect(score?.fairwayHit, true);
      expect(score?.gir, true);
      expect(score?.bunker, false);

      cubit.close();
    });

    test('can navigate through holes 1 to 18 in sequence', () async {
      final cubit = buildTestCubit(repo);

      for (int i = 0; i < 17; i++) {
        cubit.navigateToNextHole();
      }

      expect(cubit.state.currentHoleNumber, 18);
      expect(cubit.state.isLastHole, true);
      expect(cubit.state.canGoForward, false);

      cubit.close();
    });

    test('hole navigation saves scores before moving', () async {
      final cubit = buildTestCubit(repo);

      // Enter score on hole 1
      await cubit.setGrossScore(testPlayer1, 4);

      // Navigate to hole 2
      cubit.navigateToNextHole();

      // Score should still be saved
      final score1 = await repo.getScore(
        flightId: testFlightId,
        holeId: 'hole-1',
        playerId: testPlayer1,
      );
      expect(score1?.grossScore, 4);

      // Enter score on hole 2
      await cubit.setGrossScore(testPlayer1, 5);

      // Navigate back to hole 1
      cubit.navigateToPreviousHole();

      // Score on hole 1 should still be 4
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.grossScore, 4);

      // Score on hole 2 should still be 5
      final score2 = await repo.getScore(
        flightId: testFlightId,
        holeId: 'hole-2',
        playerId: testPlayer1,
      );
      expect(score2?.grossScore, 5);

      cubit.close();
    });
  });

  group('Scorecard Integration — Offline Recovery', () {
    late MockScoreRepository repo;

    setUp(() {
      repo = MockScoreRepository();
    });

    tearDown(() {
      repo.clear();
    });

    test('scores persist in repository after app restart', () async {
      // Simulate app running
      {
        final cubit = buildTestCubit(repo);
        await cubit.setGrossScore(testPlayer1, 4);
        await cubit.setGrossScore(testPlayer2, 5);
        cubit.navigateToNextHole();
        await cubit.setGrossScore(testPlayer1, 3);
        await cubit.setGrossScore(testPlayer2, 4);
        cubit.close();
      }

      // Simulate app restart - repository still has data
      expect(repo.scoreCount, 4);

      // Create new cubit with same repo (app restart)
      {
        final newCubit = buildTestCubit(repo);
        await newCubit.loadScores();

        // Verify data recovered
        expect(newCubit.state.getScore(testPlayer1, 'hole-1')?.grossScore, 4);
        expect(newCubit.state.getScore(testPlayer2, 'hole-1')?.grossScore, 5);
        expect(newCubit.state.getScore(testPlayer1, 'hole-2')?.grossScore, 3);
        expect(newCubit.state.getScore(testPlayer2, 'hole-2')?.grossScore, 4);

        newCubit.close();
      }
    });

    test('getScoresForFlight returns all scores for round', () async {
      {
        final cubit = buildTestCubit(repo);

        // Enter scores on holes 1-5 for player 1
        for (int hole = 0; hole < 5; hole++) {
          if (hole > 0) cubit.navigateToNextHole();
          await cubit.setGrossScore(testPlayer1, 4);
        }

        // Enter scores on holes 1-3 for player 2
        cubit.navigateToHoleIndex(0);
        for (int hole = 0; hole < 3; hole++) {
          if (hole > 0) cubit.navigateToNextHole();
          await cubit.setGrossScore(testPlayer2, 5);
        }

        cubit.close();
      }

      // Verify all scores retrieved
      final allScores = await repo.getScoresForFlight(testFlightId);
      expect(allScores.length, 8); // 5 + 3

      // Verify scores for specific hole
      final hole1Scores = await repo.getScoresForHole(
        flightId: testFlightId,
        holeId: 'hole-1',
      );
      expect(hole1Scores.length, 2); // Player 1 and Player 2

      // Verify scores for specific player
      final player1Scores = await repo.getScoresForPlayer(
        flightId: testFlightId,
        playerId: testPlayer1,
      );
      expect(player1Scores.length, 5);
    });

    test('scores with local sync status can be retrieved', () async {
      {
        final cubit = buildTestCubit(repo);
        await cubit.setGrossScore(testPlayer1, 4);
        await cubit.setGrossScore(testPlayer2, 5);
        cubit.close();
      }

      final localScores = await repo.getScoresBySyncStatus(ScoreSyncStatus.local);
      expect(localScores.length, 2);
    });
  });

  group('Scorecard Integration — Score Validation', () {
    late MockScoreRepository repo;

    setUp(() {
      repo = MockScoreRepository();
    });

    tearDown(() {
      repo.clear();
    });

    test('gross score validated to range 1-30', () async {
      final cubit = buildTestCubit(repo);

      // Valid score
      await cubit.setGrossScore(testPlayer1, 4);
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.grossScore, 4);

      // Score clamped to max 30 on decrement
      await cubit.decrementGrossScore(testPlayer1, by: 50);
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.grossScore, 1);

      cubit.close();
    });

    test('putts validated to range 0-15', () async {
      final cubit = buildTestCubit(repo);

      await cubit.setGrossScore(testPlayer1, 4);

      // Increment putts
      for (int i = 0; i < 20; i++) {
        await cubit.incrementPutts(testPlayer1);
      }
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.putts, 15);

      // Decrement below 0
      for (int i = 0; i < 20; i++) {
        await cubit.decrementPutts(testPlayer1);
      }
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.putts, 0);

      cubit.close();
    });

    test('penalties validated to range 0-10', () async {
      final cubit = buildTestCubit(repo);

      await cubit.setGrossScore(testPlayer1, 4);

      for (int i = 0; i < 15; i++) {
        await cubit.incrementPenalties(testPlayer1);
      }
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.penalties, 10);

      for (int i = 0; i < 15; i++) {
        await cubit.decrementPenalties(testPlayer1);
      }
      expect(cubit.state.getScore(testPlayer1, 'hole-1')?.penalties, 0);

      cubit.close();
    });

    test('Score.isValid validates correctly', () {
      // Valid score
      final validScore = Score(
        id: 'test-1',
        flightId: testFlightId,
        holeId: 'hole-1',
        playerId: testPlayer1,
        grossScore: 4,
        putts: 2,
        penalties: 0,
        fairwayHit: true,
        gir: true,
        bunker: false,
        updatedAt: DateTime.now(),
      );
      expect(validScore.isValid, true);
      expect(validScore.validate(), isEmpty);

      // Invalid score - out of range
      final invalidScore = Score(
        id: 'test-2',
        flightId: testFlightId,
        holeId: 'hole-1',
        playerId: testPlayer1,
        grossScore: 35, // Out of range
        putts: 20, // Out of range
        updatedAt: DateTime.now(),
      );
      expect(invalidScore.isValid, false);
      expect(invalidScore.validate(), isNotEmpty);
    });
  });
}
