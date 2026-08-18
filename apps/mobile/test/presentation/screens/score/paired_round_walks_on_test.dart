// A round on two nines can be played past the turn.
//
// Found by the tour that photographs an eighteen at Long Biên: it pressed "Hố
// sau" eighteen times and came back with a card of ten holes. The screenshot
// filed as the 10th showed "Hố 1 trên 18", and the round summary said it out
// loud — "mình đánh 10 hố được 49 gậy".
//
// A round on Đường A + Đường B has eighteen holes numbered 1-9 and then 1-9
// again, because each đường numbers its own from one. The scorecard navigates
// by index, which is right; it also accepts a hole *number* from the round
// around it, so that automatic hole detection can move it, and it resolved
// that number with `indexOf` — which answers with the first match.
//
// So on reaching index 9 — hole 1 of Đường B, the tenth hole of the round —
// the card reported "hole 1" outward, that number came straight back, and the
// golfer was returned to the first tee of Đường A. Pressing "Hố sau" from the
// 9th replayed the front nine on top of the scores already on it, and the back
// nine could not be reached at all. On the app's only genuine eighteen.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/application/score/scorecard_state.dart';

/// The hole ids of a round on two nines, as a paired round builds them.
const _paired = [
  '1', '2', '3', '4', '5', '6', '7', '8', '9', // Đường A
  '1', '2', '3', '4', '5', '6', '7', '8', '9', // Đường B
];

/// A single eighteen-hole course, where every number is used once.
const _eighteen = [
  '1', '2', '3', '4', '5', '6', '7', '8', '9',
  '10', '11', '12', '13', '14', '15', '16', '17', '18',
];

ScorecardScreenState _at(int index, {List<String> holes = _paired}) =>
    ScorecardScreenState(
      flightId: 'r1',
      holeIds: holes,
      playerIds: const ['p1'],
      currentHoleIndex: index,
    );

void main() {
  test('the premise: a paired round reuses nine numbers', () {
    // If this stops being true the guard below is not needed — and if it is
    // quietly changed, this is where to look.
    expect(_paired, hasLength(18));
    expect(_paired.toSet(), hasLength(9));
    expect(_paired.indexOf('1'), 0);
    expect(_paired.lastIndexOf('1'), 9);
  });

  group('the round reporting where the card already is', () {
    test('does not send the tenth hole back to the first', () {
      // Index 9 is the tenth hole of the round and it is numbered 1.
      final card = _at(9);
      expect(card.holeIds[card.currentHoleIndex], '1');

      expect(
        card.holeIndexToShow(1),
        isNull,
        reason: 'this is the defect: indexOf("1") is 0, and moving there '
            'replays the front nine over its own scores',
      );
    });

    test('nor any other hole of the second nine', () {
      for (var i = 9; i < 18; i++) {
        expect(
          _at(i).holeIndexToShow(i - 8),
          isNull,
          reason: 'hole ${i - 8} of Đường B is index $i, not index ${i - 9}',
        );
      }
    });

    test('and the first nine is left alone too', () {
      expect(_at(3).holeIndexToShow(4), isNull);
    });
  });

  group('a genuine move is still followed', () {
    // The sync exists because detection can move the golfer while they are
    // looking at the card. A guard that turned it off would be its own bug.
    test('forward within the nine being played', () {
      expect(_at(0).holeIndexToShow(5), 4);
    });

    test('backward', () {
      expect(_at(4).holeIndexToShow(2), 1);
    });

    test('and on a course whose eighteen holes have eighteen numbers', () {
      expect(_at(0, holes: _eighteen).holeIndexToShow(12), 11);
      expect(_at(11, holes: _eighteen).holeIndexToShow(12), isNull);
    });
  });

  group('nothing to move to', () {
    test('a hole this round does not play', () {
      expect(_at(0).holeIndexToShow(14), isNull);
    });

    test('an empty card', () {
      expect(
        _at(0, holes: const []).holeIndexToShow(1),
        isNull,
        reason: 'a card with no holes on it cannot be indexed into',
      );
    });
  });
}
