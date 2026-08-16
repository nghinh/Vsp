// The đường the golfer chose has to reach the round.
//
// Reported from a course: picking Long Biên Đường B produced an eighteen-hole
// round on Đường A. Three separate consequences of one cause — the choice
// stopped at the form. Holes 10 to 18 do not exist on a nine, so the map had
// no geometry, the green had no position, and the screen fell back to
// satellite imagery over the golfer's own street.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const duongA = LayoutOption(id: 1351, name: 'Đường A', holeCount: 9);
  const duongB = LayoutOption(id: 1352, name: 'Đường B', holeCount: 9);
  const duongC = LayoutOption(id: 1353, name: 'Đường C', holeCount: 9);
  const championship =
      LayoutOption(id: 3, name: 'Championship', holeCount: 18);

  /// The state after the picker has landed on the club — which sets courseId
  /// to whichever đường the search returned, not to the one the golfer wants.
  RoundSetupReady form({
    required List<LayoutOption> layouts,
    int? selected,
    int? second,
    String? holes,
    int courseId = 1351,
  }) =>
      RoundSetupReady(
        courseId: courseId,
        courseName: 'Long Biên Golf Course',
        layouts: layouts,
        selectedLayoutId: selected,
        selectedSecondLayoutId: second,
        holes: holes,
      );

  group('how many holes the round plays', () {
    /// The bug, exactly: a nine that produced an eighteen.
    test('a single nine plays nine holes, not eighteen', () {
      final state = form(layouts: [duongA, duongB, duongC], selected: 1352);

      expect(state.holeNumbersInPlay, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });

    test('two nines paired play eighteen', () {
      final state = form(
        layouts: [duongA, duongB, duongC],
        selected: 1351,
        second: 1352,
      );

      expect(state.holeNumbersInPlay, hasLength(18));
      expect(state.holeNumbersInPlay.last, 18);
    });

    test('a real eighteen plays eighteen', () {
      final state = form(layouts: [championship], selected: 3);

      expect(state.holeNumbersInPlay, hasLength(18));
    });

    /// front9/back9 is an explicit decision about an eighteen and still wins.
    test('front nine and back nine still override', () {
      final front = form(
        layouts: [championship],
        selected: 3,
        holes: 'front9',
      );
      final back = form(layouts: [championship], selected: 3, holes: 'back9');

      expect(front.holeNumbersInPlay, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(back.holeNumbersInPlay, [10, 11, 12, 13, 14, 15, 16, 17, 18]);
    });

    test('before a choice is made it assumes an eighteen', () {
      final state = form(layouts: [duongA, duongB]);

      expect(state.holeNumbersInPlay, hasLength(18));
    });
  });

  group('which course the round is recorded against', () {
    /// The other half of the same bug: the form said B and the round opened
    /// on A, because courseId was still the club's landing course.
    test('the chosen đường wins over the club the picker landed on', () {
      final state = form(layouts: [duongA, duongB, duongC], selected: 1352);

      expect(state.playingCourseId, 1352);
      expect(state.courseId, 1351, reason: 'the picker value is left alone');
    });

    test('a paired round is recorded against the first đường', () {
      final state = form(
        layouts: [duongA, duongB, duongC],
        selected: 1353,
        second: 1351,
      );

      expect(state.playingCourseId, 1353);
      expect(state.segmentCourseIds, [1353, 1351]);
    });

    test('a club with one course needs no choice', () {
      final state = form(layouts: [championship], courseId: 3);

      expect(state.playingCourseId, 3);
    });
  });

  group('which packages the round needs', () {
    /// A downloaded Đường B kept being told to download, because readiness
    /// was checked against the club's landing course instead.
    test('a single nine needs only its own package', () {
      final state = form(layouts: [duongA, duongB, duongC], selected: 1352);

      expect(state.segmentCourseIds, [1352]);
    });

    test('a pairing needs both, in playing order', () {
      final state = form(
        layouts: [duongA, duongB, duongC],
        selected: 1351,
        second: 1353,
      );

      expect(state.segmentCourseIds, [1351, 1353]);
    });
  });
}
