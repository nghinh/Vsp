import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/score.dart';
import 'package:vsp_mobile/domain/models/score_value_objects.dart';
import 'package:vsp_mobile/features/round/presentation/round_completion_bloc.dart';

/// The round summary built `players: []` unconditionally — the code carried a
/// comment saying a real implementation would fetch the hole scores, and never
/// did. A golfer who had entered a full card was told "Chưa có dữ liệu điểm".
///
/// These exercise [buildPlayerSummaries], the aggregation the summary now
/// runs over the `scores` rows the scorecard writes.
void main() {
  Score score(
    String holeId, {
    int? gross,
    String player = 'p1',
    int? putts,
    bool? gir,
  }) => Score(
    id: 'r1_${holeId}_$player',
    flightId: 'r1',
    holeId: holeId,
    playerId: player,
    grossScore: gross,
    putts: putts,
    gir: gir,
    syncStatus: ScoreSyncStatus.local,
    updatedAt: DateTime.utc(2026, 8, 11),
  );

  test('totals strokes and par across the holes played', () {
    final players = buildPlayerSummaries(
      scores: [
        score('1', gross: 5, putts: 2, gir: true),
        score('2', gross: 3),
        score('3', gross: 4),
      ],
      parByHole: {1: 4, 2: 3, 3: 5},
      playerNames: {'p1': 'Nghi'},
    );

    expect(players, hasLength(1));
    final card = players.single;
    expect(card.playerName, 'Nghi');
    expect(card.holes, hasLength(3));
    expect(card.totalStrokes, 12);
    expect(card.totalPar, 12);
    expect(card.relativeScore, 0);
    expect(card.totalPutts, 2);
    expect(card.girCount, 1);
  });

  test('a hole opened but never scored is not counted as a zero', () {
    final players = buildPlayerSummaries(
      scores: [score('1', gross: 4), score('2')],
      parByHole: {1: 4, 2: 4},
      playerNames: const {},
    );

    expect(players.single.holes, hasLength(1));
    expect(players.single.holes.single.holeNumber, 1);
    expect(players.single.totalStrokes, 4);
  });

  test('holes with unknown par keep their strokes out of the par maths', () {
    // A device with no course package: the strokes are real, par is not
    // invented, and the golfer is not reported as +9 against a par of zero.
    final players = buildPlayerSummaries(
      scores: [score('1', gross: 5), score('2', gross: 4)],
      parByHole: const {},
      playerNames: const {},
    );

    expect(players.single.totalStrokes, 9);
    expect(players.single.totalPar, 0);
    expect(players.single.relativeScore, 0);
  });

  test('par is counted only for the holes that have one', () {
    final players = buildPlayerSummaries(
      scores: [score('1', gross: 5), score('2', gross: 4)],
      parByHole: {1: 4}, // hole 2 missing from the package
      playerNames: const {},
    );

    expect(players.single.totalStrokes, 9);
    expect(players.single.totalPar, 4);
    expect(players.single.relativeScore, 1);
  });

  test('holes come back in play order regardless of write order', () {
    final players = buildPlayerSummaries(
      scores: [
        score('11', gross: 4),
        score('2', gross: 5),
        score('7', gross: 3),
      ],
      parByHole: {2: 4, 7: 3, 11: 4},
      playerNames: const {},
    );

    expect(players.single.holes.map((h) => h.holeNumber), [2, 7, 11]);
  });

  test('splits a flight into one card per player', () {
    final players = buildPlayerSummaries(
      scores: [
        score('1', gross: 4, player: 'p2'),
        score('1', gross: 5, player: 'p1'),
        score('2', gross: 3, player: 'p1'),
      ],
      parByHole: {1: 4, 2: 3},
      playerNames: {'p1': 'An', 'p2': 'Bình'},
    );

    expect(players.map((p) => p.playerName), ['An', 'Bình']);
    expect(players.first.totalStrokes, 8);
    expect(players.last.totalStrokes, 4);
  });

  test('falls back to the player id when the round recorded no names', () {
    // `players` is never written during play, so the card must still be
    // readable rather than blank.
    final players = buildPlayerSummaries(
      scores: [score('1', gross: 4, player: 'guest-2')],
      parByHole: {1: 4},
      playerNames: const {},
    );

    expect(players.single.playerName, 'guest-2');
  });

  test('an empty round produces no cards, not an empty card', () {
    expect(
      buildPlayerSummaries(
        scores: const [],
        parByHole: const {},
        playerNames: const {},
      ),
      isEmpty,
    );
  });
}
