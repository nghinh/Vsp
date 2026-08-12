// Writing a photographed card onto the scorecard.
//
// A scanned round has to be indistinguishable from a typed one once it lands:
// same rows in SQLite, same sync queue, same corrections afterwards. Only the
// typing is skipped. These pin that, and pin the two ways a card can be about
// a round it does not belong to.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/application/score/scorecard_cubit.dart';
import 'package:vsp_mobile/domain/models/score.dart';
import 'package:vsp_mobile/domain/models/score_value_objects.dart';
import 'package:vsp_mobile/domain/repositories/score_repository.dart';

class _InMemoryScoreRepository implements ScoreRepository {
  final List<Score> saved = [];

  @override
  Future<void> upsertScore(Score score) async {
    saved.removeWhere(
      (s) =>
          s.flightId == score.flightId &&
          s.holeId == score.holeId &&
          s.playerId == score.playerId,
    );
    saved.add(score);
  }

  @override
  Future<List<Score>> getScoresForFlight(String flightId) async =>
      saved.where((s) => s.flightId == flightId).toList();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const roundId = '2b1c0f74-0f2e-4a7f-9c3d-5a6b7c8d9e01';
  const playerId = '66';

  ScorecardCubit build(_InMemoryScoreRepository repository, {int holes = 18}) =>
      ScorecardCubit(
        flightId: roundId,
        holeIds: [for (var hole = 1; hole <= holes; hole++) '$hole'],
        playerIds: const [playerId],
        holePars: {for (var hole = 1; hole <= holes; hole++) '$hole': 4},
        scoreRepository: repository,
      );

  test('a confirmed card lands hole by hole on the scorecard', () async {
    final repository = _InMemoryScoreRepository();
    final cubit = build(repository);

    final written = await cubit.applyScannedStrokes(
      playerId: playerId,
      grossByHole: const {1: 5, 2: 4, 3: 6},
    );

    expect(written, 3);
    expect(repository.saved, hasLength(3));
    expect(
      repository.saved.firstWhere((s) => s.holeId == '3').grossScore,
      6,
    );
    await cubit.close();
  });

  test('a scanned hole is marked unsynced, exactly like a typed one', () async {
    // A scanned round that skipped the sync queue would sit on the phone
    // looking finished while the server held an empty card — the same failure
    // that once left every hand-entered round unsynced.
    final repository = _InMemoryScoreRepository();
    final cubit = build(repository);

    await cubit.applyScannedStrokes(
      playerId: playerId,
      grossByHole: const {7: 5},
    );

    expect(repository.saved.single.syncStatus, ScoreSyncStatus.local);
    expect(cubit.state.isOffline, isTrue);
    await cubit.close();
  });

  test('a hole this round does not play is not written', () async {
    // A card photographed on the wrong nine — or a back-nine round handed an
    // eighteen-hole card — would otherwise hang scores off hole ids the round
    // has never heard of, where nothing reads them and nothing removes them.
    final repository = _InMemoryScoreRepository();
    final cubit = build(repository, holes: 9);

    final written = await cubit.applyScannedStrokes(
      playerId: playerId,
      grossByHole: const {9: 4, 10: 5, 18: 6},
    );

    expect(written, 1);
    expect(repository.saved.map((s) => s.holeId), ['9']);
    await cubit.close();
  });

  test('re-scanning a card updates the holes rather than doubling them', () async {
    // The id is derived from round, hole and player, so a golfer who
    // photographs the card twice — or corrects one hole and scans again —
    // gets one row per hole either way.
    final repository = _InMemoryScoreRepository();
    final cubit = build(repository);

    await cubit.applyScannedStrokes(
      playerId: playerId,
      grossByHole: const {1: 5},
    );
    await cubit.applyScannedStrokes(
      playerId: playerId,
      grossByHole: const {1: 4},
    );

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.grossScore, 4);
    await cubit.close();
  });
}
