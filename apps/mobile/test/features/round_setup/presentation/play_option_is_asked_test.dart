// The club with ten rounds in it has to ask which one.
//
// Reported from the course, with a screenshot of the setup form: "Vào bắt đầu
// vòng đấu không thấy hỏi đường (do chọn vòng gần đây nên nhớ đường lần trước
// luôn?)". The golfer's own guess at the cause was right.
//
// Long Biên has three nines. The recent-rounds list stores the đường that was
// played, so tapping "Đường A" there set courseId to 1351, and the form filled
// its own answer in: the radio arrived on "Đường A — 9 hố". A question that is
// already answered is not read as a question, and a golfer who came to play
// A+B started nine holes instead. The scorecard is right, the map is right,
// and the round is the wrong length — which is only discovered at the tenth
// tee, where there is nothing to do about it.
//
// So: where a club offers more than one round, the form arrives with nothing
// chosen and Start waits. Where it offers one, nothing is being asked and the
// form answers it itself.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/player.dart';
import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const duongA = LayoutOption(id: 1351, name: 'Đường A', holeCount: 9);
  const duongB = LayoutOption(id: 1352, name: 'Đường B', holeCount: 9);
  const duongC = LayoutOption(id: 1353, name: 'Đường C', holeCount: 9);
  const championship = LayoutOption(id: 3, name: 'Championship', holeCount: 18);

  const me = Player(id: '1', name: 'Me', isPrimary: true);

  /// The form as `_loadCourseOptions` builds it before it decides what to keep:
  /// the đường the picker carried in is already selected.
  RoundSetupReady loaded({
    required List<LayoutOption> layouts,
    required int courseId,
  }) => RoundSetupReady(
    courseId: courseId,
    courseName: 'Long Biên Golf Course',
    layouts: layouts,
    selectedLayoutId: courseId,
    players: const [me],
  );

  group('a club with several nines', () {
    test('arrives with no round chosen', () {
      final form = loaded(
        layouts: [duongA, duongB, duongC],
        courseId: 1351,
      ).askForPlayOption();

      expect(
        form.selectedLayoutId,
        isNull,
        reason: 'the đường the history carried in is not an answer',
      );
      expect(form.selectedSecondLayoutId, isNull);
      expect(form.selectedPlayOption, isNull);
      expect(form.awaitingPlayOption, isTrue);
    });

    test('holds Start until it is answered', () {
      final form = loaded(
        layouts: [duongA, duongB, duongC],
        courseId: 1351,
      ).askForPlayOption();

      expect(
        form.canStartRound,
        isFalse,
        reason: 'this is the whole defect — a nine-hole round nobody chose '
            'was one tap away and looked exactly like an eighteen',
      );

      // A+B, which is what the golfer had booked.
      final answered = form.copyWith(
        selectedLayoutId: 1351,
        selectedSecondLayoutId: 1352,
      );
      expect(answered.awaitingPlayOption, isFalse);
      expect(answered.canStartRound, isTrue);
      expect(answered.holeNumbersInPlay, hasLength(18));
    });

    test('and the golfer may still choose a single nine', () {
      final nine = loaded(layouts: [duongA, duongB, duongC], courseId: 1351)
          .askForPlayOption()
          .copyWith(selectedLayoutId: 1352);

      expect(nine.awaitingPlayOption, isFalse);
      expect(nine.canStartRound, isTrue);
      expect(nine.holeNumbersInPlay, hasLength(9));
    });
  });

  // The rule above is only worth anything if the form is built through it.
  // The bloc needs a course detail API, a profile repository, a bag
  // repository, secure storage and a round store to instantiate, and none of
  // that is on the path being checked — so the check is on the source.
  test('and the form is built through it', () {
    final source = File(
      'lib/features/round_setup/presentation/round_setup_bloc.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('askForPlayOption()'),
      reason: 'the golfer only gets asked if _loadCourseOptions asks',
    );
  });

  group('a club with one way to play it', () {
    test('keeps its answer and starts', () {
      final form = loaded(
        layouts: [championship],
        courseId: 3,
      ).askForPlayOption();

      expect(form.selectedLayoutId, 3);
      expect(form.awaitingPlayOption, isFalse);
      expect(form.canStartRound, isTrue);
    });

    test('as does a course whose detail never loaded', () {
      // Offline: no layouts, no tees, par 4 assumed. The golfer plays.
      final form = const RoundSetupReady(
        courseId: 1351,
        courseName: 'Long Biên Golf Course',
        players: [me],
      ).askForPlayOption();

      expect(form.awaitingPlayOption, isFalse);
      expect(form.canStartRound, isTrue);
    });
  });
}
