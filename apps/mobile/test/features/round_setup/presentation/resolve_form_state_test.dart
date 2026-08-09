// What the round setup form draws for each bloc state.
//
// This file exists because of a bug on the happy path. The screen resolved its
// state with `(state as RoundSetupError).lastState!` — an assumption that
// anything not Ready must be an Error. Three states are neither, and two of
// them are the ones that mean the round *started*, so every successful tap on
// "Bắt đầu vòng đấu" threw
//
//     type 'RoundSetupRoundStarted' is not a subtype of type
//     'RoundSetupError' in type cast
//
// which Flutter drew as a full-screen red error page for the one frame between
// the tap and the push to the round screen. It flashed and vanished, so it read
// as a rendering glitch rather than a thrown exception, and it survived because
// this screen had no tests of any kind.
//
// The rule these pin is simple and total: no state may throw, and none may
// blank the form the golfer was just looking at.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/round_setup_screen.dart';
import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const form = RoundSetupReady(courseId: 8, courseName: 'Long Thành');
  const otherForm = RoundSetupReady(courseId: 2, courseName: 'Sky Lake');

  /// Every state the bloc can emit. A new one added here without a case in
  /// resolveFormState should fail these, not the golfer's screen.
  final allStates = <RoundSetupState>[
    const RoundSetupInitial(),
    const RoundSetupLoading(),
    form,
    const RoundSetupRoundStarted(
      roundId: 'r-1',
      courseId: 8,
      courseName: 'Long Thành',
    ),
    const RoundSetupLocalRoundSaved(
      courseId: 8,
      courseName: 'Long Thành',
      localRoundId: 'local-1',
    ),
    const RoundSetupError(message: 'boom'),
    const RoundSetupError(message: 'boom', lastState: form),
  ];

  group('no state throws', () {
    test('with a form already built', () {
      for (final state in allStates) {
        expect(
          () => resolveFormState(state, form),
          returnsNormally,
          reason: '${state.runtimeType} threw',
        );
      }
    });

    test('with no form ever built', () {
      for (final state in allStates) {
        expect(
          () => resolveFormState(state, null),
          returnsNormally,
          reason: '${state.runtimeType} threw',
        );
      }
    });
  });

  group('starting a round keeps the form on screen', () {
    test('RoundSetupRoundStarted holds the last form', () {
      // The exact state that used to throw. It arrives on the frame the round
      // is created and is replaced by the round screen a frame later; drawing
      // nothing — or an error — in between is what the golfer saw.
      const started = RoundSetupRoundStarted(
        roundId: 'r-1',
        courseId: 8,
        courseName: 'Long Thành',
      );

      expect(resolveFormState(started, form), same(form));
    });

    test('RoundSetupLocalRoundSaved holds the last form', () {
      const saved = RoundSetupLocalRoundSaved(
        courseId: 8,
        courseName: 'Long Thành',
        localRoundId: 'local-1',
      );

      expect(resolveFormState(saved, form), same(form));
    });
  });

  group('the rest', () {
    test('a ready state is itself, not whatever was cached', () {
      expect(resolveFormState(otherForm, form), same(otherForm));
    });

    test('an error carrying a form shows that form, not the stale one', () {
      const failed = RoundSetupError(message: 'boom', lastState: otherForm);

      expect(resolveFormState(failed, form), same(otherForm));
    });

    test('an error with no form of its own falls back to the last one', () {
      expect(
        resolveFormState(const RoundSetupError(message: 'boom'), form),
        same(form),
      );
    });

    test('null only when nothing has ever been ready', () {
      expect(resolveFormState(const RoundSetupLoading(), null), isNull);
      expect(
        resolveFormState(
          const RoundSetupRoundStarted(
            roundId: 'r-1',
            courseId: 8,
            courseName: 'Long Thành',
          ),
          null,
        ),
        isNull,
      );
    });
  });
}
