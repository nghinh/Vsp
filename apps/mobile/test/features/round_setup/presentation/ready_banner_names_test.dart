// What "Sẵn sàng ngoại tuyến" is claiming.
//
// Reported from a phone on 17/8/2026, and it is the third time this banner has
// looked like a download that would not stick. The golfer picked Đường B on
// Long Biên, downloaded it, and got a green banner reading "Sẵn sàng ngoại
// tuyến" — with no subject. They then picked Đường A → Đường B and got "Chưa
// tải dữ liệu Đường A".
//
// Both sentences are true. Read one after the other they say the download did
// not work, because the first one never said what it covered. The failing side
// of this banner has named its đường since the two-package round was fixed;
// the succeeding side never did, and an unnamed success beside a named failure
// is not a wording problem, it is a missing fact.
//
// Long Biên has three đường and six pairings of them, so "which one is ready"
// is a real question with nine possible answers.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const duongA = LayoutOption(id: 21, name: 'Đường A', holeCount: 9);
  const duongB = LayoutOption(id: 22, name: 'Đường B', holeCount: 9);
  const duongC = LayoutOption(id: 23, name: 'Đường C', holeCount: 9);

  RoundSetupReady form({
    required List<LayoutOption> layouts,
    int? courseId = 21,
    int? selected,
    int? second,
  }) => RoundSetupReady(
    courseId: courseId,
    courseName: 'Long Biên Golf Course',
    layouts: layouts,
    selectedLayoutId: selected,
    selectedSecondLayoutId: second,
  );

  group('on a club with several đường', () {
    test('a single nine is named', () {
      final state = form(
        layouts: const [duongA, duongB, duongC],
        selected: 22,
      );

      expect(state.readyCourseNames, 'Đường B');
    });

    test('a pairing names both, in playing order', () {
      // The exact selection from the screenshot. "Sẵn sàng ngoại tuyến" here
      // has to mean two packages, not one.
      final state = form(
        layouts: const [duongA, duongB, duongC],
        selected: 21,
        second: 22,
      );

      expect(state.readyCourseNames, 'Đường A + Đường B');
    });

    test('and the order is the round\'s, not the list\'s', () {
      final state = form(
        layouts: const [duongA, duongB, duongC],
        selected: 23,
        second: 21,
      );

      expect(state.readyCourseNames, 'Đường C + Đường A');
    });
  });

  group('on a club with one layout', () {
    test('nothing is named, because nothing is ambiguous', () {
      // "Sẵn sàng ngoại tuyến — Championship" on a course with one course is
      // noise, and this banner has enough of that already.
      final state = form(
        layouts: const [
          LayoutOption(id: 30, name: 'Championship', holeCount: 18),
        ],
        courseId: 30,
        selected: 30,
      );

      expect(state.readyCourseNames, isNull);
    });
  });

  group('the two sides of the banner agree', () {
    test('what is named missing is one of the đường named ready', () {
      // The property that was broken: the failing banner talked about Đường A
      // while the succeeding one had talked about nothing at all, so the
      // golfer could not tell they were about the same round.
      final state = form(
        layouts: const [duongA, duongB, duongC],
        selected: 21,
        second: 22,
      );

      final ready = state.readyCourseNames!;
      expect(ready, contains('Đường A'));
      expect(ready, contains('Đường B'));
      expect(ready, isNot(contains('Đường C')));
    });
  });
}
