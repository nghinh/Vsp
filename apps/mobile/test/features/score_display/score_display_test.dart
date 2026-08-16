// The three ways a round reads.
//
// Gross and to-par are arithmetic on what is already on the card. Net is not:
// it needs the golfer's playing handicap and the club's stroke index, and
// half the country's cards carry no index. What is asserted most here is the
// refusal — a number that looks like a net score and is built on a guessed
// allocation is worse than no number, because nobody can tell by looking.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/score_display/score_display.dart';

void main() {
  // Three holes of a par-4, par-3, par-5, played 5, 3, 7.
  const gross = {1: 5, 2: 3, 3: 7};
  const pars = {1: 4, 2: 3, 3: 5};
  const indexes = {1: 1, 2: 18, 3: 9};

  ScoreDisplay card({Map<int, int> si = indexes, int? handicap}) =>
      ScoreDisplay(
        grossByHole: gross,
        parByHole: pars,
        strokeIndexes: si,
        handicap: handicap,
      );

  group('gross and to par', () {
    test('gross is the strokes, added up', () {
      expect(card().total(ScoreDisplayMode.gross), 15);
    });

    test('to par counts only the holes actually played', () {
      // 5−4, 3−3, 7−5 = +3 through three holes.
      expect(card().total(ScoreDisplayMode.toPar), 3);
      expect(card().label(ScoreDisplayMode.toPar), '+3');
    });

    test('level par reads E, and under par keeps its sign', () {
      final level = ScoreDisplay(
        grossByHole: const {1: 4},
        parByHole: const {1: 4},
      );
      final under = ScoreDisplay(
        grossByHole: const {1: 3},
        parByHole: const {1: 4},
      );

      expect(level.label(ScoreDisplayMode.toPar), 'E');
      expect(under.label(ScoreDisplayMode.toPar), '-1');
    });

    test('nothing scored yet is not zero', () {
      const empty = ScoreDisplay(grossByHole: {}, parByHole: pars);

      expect(empty.total(ScoreDisplayMode.gross), isNull);
      expect(empty.label(ScoreDisplayMode.gross), '—');
    });
  });

  group('net', () {
    test('takes a shot off the holes the index gives it on', () {
      // Handicap 2: shots on index 1 and 2. Here only hole 1 (index 1).
      expect(card(handicap: 2).total(ScoreDisplayMode.net), 14);
    });

    test('a handicap bigger than the card laps it', () {
      // 20 over 18 holes: one shot everywhere, two on indexes 1 and 2.
      final c = card(handicap: 20);

      expect(c.strokesOn(1), 2);   // index 1
      expect(c.strokesOn(3), 1);   // index 9
      expect(c.strokesOn(2), 1);   // index 18
      expect(c.total(ScoreDisplayMode.net), 15 - 4);
    });

    test('a plus handicap gives shots back on the easiest holes', () {
      final c = card(handicap: -1);

      expect(c.strokesOn(2), -1);  // index 18, the easiest
      expect(c.strokesOn(1), 0);
      expect(c.total(ScoreDisplayMode.net), 16);
    });

    /// Half the country's cards publish no index. Without one there is no
    /// allocation, and a net score would be a guess wearing a number.
    test('refuses without a stroke index', () {
      final c = card(si: const {}, handicap: 20);

      expect(c.canShowNet, isFalse);
      expect(c.total(ScoreDisplayMode.net), isNull);
      expect(c.label(ScoreDisplayMode.net), '—');
    });

    test('refuses without a handicap', () {
      final c = card();

      expect(c.canShowNet, isFalse);
      expect(c.total(ScoreDisplayMode.net), isNull);
    });

    test('gross and to par still work where net cannot', () {
      final c = card(si: const {});

      expect(c.total(ScoreDisplayMode.gross), 15);
      expect(c.total(ScoreDisplayMode.toPar), 3);
    });
  });
}
