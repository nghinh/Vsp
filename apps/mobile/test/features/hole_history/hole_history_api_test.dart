// Reading a golfer's own record of a hole.
//
// The parsing matters more than it looks: this is shown on a tee box, and a
// hole never played must read as nothing at all rather than as a score of
// zero, which is what a naive default gives.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/hole_history/data/hole_history_api.dart';

void main() {
  group('parsing a hole history', () {
    test('scores, notes and the summary all come through', () {
      final history = HoleHistory.parse({
        'courseId': 1352,
        'holeNumber': 4,
        'timesPlayed': 3,
        'averageStrokes': 5.0,
        'bestStrokes': 4,
        'scores': [
          {
            'strokes': 4,
            'par': 4,
            'toPar': 0,
            'putts': 2,
            'playedAt': '2026-08-10T07:30:00Z',
          },
          {'strokes': 6, 'par': 4, 'toPar': 2},
        ],
        'notes': [
          {
            'id': 7,
            'note': 'Driver chạy vào rãnh — gỗ 3 là đủ',
            'createdAt': '2026-08-10T08:00:00Z',
          },
        ],
      });

      expect(history.timesPlayed, 3);
      expect(history.averageStrokes, 5.0);
      expect(history.bestStrokes, 4);
      expect(history.attempts, hasLength(2));
      expect(history.attempts.first.strokes, 4);
      expect(history.attempts.first.putts, 2);
      expect(history.attempts.first.playedAt?.day, 10);
      expect(history.notes.single.note, contains('gỗ 3'));
      expect(history.isEmpty, isFalse);
    });

    /// The case a golfer meets most often: a tee they have never stood on.
    test('a hole never played reports nothing, not zero', () {
      final history = HoleHistory.parse({
        'timesPlayed': 0,
        'averageStrokes': null,
        'bestStrokes': null,
        'scores': [],
        'notes': [],
      });

      expect(history.timesPlayed, 0);
      expect(history.averageStrokes, isNull);
      expect(history.bestStrokes, isNull);
      expect(history.isEmpty, isTrue);
    });

    test('a malformed payload is empty rather than a crash on a tee box', () {
      expect(HoleHistory.parse(null).isEmpty, isTrue);
      expect(HoleHistory.parse('nonsense').isEmpty, isTrue);
      expect(HoleHistory.parse(<String, dynamic>{}).isEmpty, isTrue);
    });

    test('rows missing what makes them a row are dropped, not defaulted', () {
      final history = HoleHistory.parse({
        'timesPlayed': 1,
        'scores': [
          {'par': 4},
          {'strokes': 5, 'par': 4},
        ],
        'notes': [
          {'id': 1, 'note': '   '},
          {'note': 'no id'},
          {'id': 2, 'note': 'kept'},
        ],
      });

      expect(history.attempts, hasLength(1));
      expect(history.attempts.single.strokes, 5);
      expect(history.notes, hasLength(1));
      expect(history.notes.single.note, 'kept');
    });

    test('a score with no par carries no to-par rather than a wrong one', () {
      final history = HoleHistory.parse({
        'scores': [
          {'strokes': 5},
        ],
      });

      expect(history.attempts.single.par, isNull);
      expect(history.attempts.single.toPar, isNull);
    });
  });
}
