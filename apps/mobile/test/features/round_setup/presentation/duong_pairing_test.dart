// Which đường a round is played on, as the setup form works it out.
//
// A club may hold several. Long Biên has đường A, B and C of nine holes each,
// and a round there is a pairing the golfer chooses on the day — so the form
// has to ask for the second one and the round has to carry both. Everything
// the server does with par depends on getting this list right: round hole 12
// on A+C is đường C's hole 3, and a missing second segment resolves it to a
// hole nobody played.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const duongA = LayoutOption(id: 21, name: 'Đường A', holeCount: 9);
  const duongB = LayoutOption(id: 22, name: 'Đường B', holeCount: 9);
  const duongC = LayoutOption(id: 23, name: 'Đường C', holeCount: 9);
  const eighteen = LayoutOption(id: 1, name: 'Championship', holeCount: 18);

  RoundSetupReady form({
    required List<LayoutOption> layouts,
    int? selected,
    int? second,
    int courseId = 21,
  }) => RoundSetupReady(
    courseId: courseId,
    courseName: 'Long Biên',
    layouts: layouts,
    selectedLayoutId: selected,
    selectedSecondLayoutId: second,
  );

  group('segmentCourseIds', () {
    test('a paired round names both đường, in playing order', () {
      final state = form(
        layouts: [duongA, duongB, duongC],
        selected: 21,
        second: 23,
      );

      expect(state.segmentCourseIds, [21, 23]);
    });

    test('a full eighteen names one', () {
      final state = form(layouts: [eighteen], selected: 1, courseId: 1);

      expect(state.segmentCourseIds, [1]);
    });

    test('falls back to the chosen course before the đường have loaded', () {
      // Course detail can be slow or unreachable; the golfer can still tee
      // off, and the round still has to say what it is played on.
      final state = form(layouts: const [], selected: null, courseId: 21);

      expect(state.segmentCourseIds, [21]);
    });
  });

  group('needsSecondLayout', () {
    test('a nine at a club with other đường needs a partner', () {
      expect(
        form(layouts: [duongA, duongB, duongC], selected: 21).needsSecondLayout,
        isTrue,
      );
    });

    test('an eighteen is a round on its own', () {
      // Kings Island: three full courses, and picking one is the whole round.
      const kings = LayoutOption(id: 31, name: "King's", holeCount: 18);
      const lakeside = LayoutOption(id: 32, name: 'Lakeside', holeCount: 18);
      expect(
        form(layouts: [kings, lakeside], selected: 31).needsSecondLayout,
        isFalse,
      );
    });

    test('a lone nine has nothing to pair with', () {
      expect(form(layouts: [duongA], selected: 21).needsSecondLayout, isFalse);
    });
  });

  test('changing the first đường drops the second', () {
    // A+B and B+? are different rounds. Carrying the old partner across a
    // change would keep a pairing the golfer never chose — and the par of
    // nine holes they are not walking.
    final paired = form(
      layouts: [duongA, duongB, duongC],
      selected: 21,
      second: 23,
    );

    final changed = paired.copyWith(
      selectedLayoutId: 22,
      clearSecondLayout: true,
    );

    expect(changed.selectedSecondLayoutId, isNull);
    expect(changed.segmentCourseIds, [22]);
  });
}
