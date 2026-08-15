// A round is a loop.
//
// Next on the 18th stopped, and back on the 1st stopped. A golfer standing on
// the 18th green who wanted to check the 1st had to press back seventeen
// times, and the two controls at the ends looked broken rather than finished.
//
// It wraps the round's own hole list rather than 1..18, so a nine wraps at the
// 9th and a round started on the 10th wraps through its own order.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/application/score/scorecard_cubit.dart';
import 'package:vsp_mobile/application/score/scorecard_state.dart';

void main() {
  group('stepping through the holes', () {
    ScorecardCubit cubitAt(int index, {int holes = 18}) {
      final ids = [for (var i = 1; i <= holes; i++) '$i'];
      final cubit = ScorecardCubit(
        flightId: 'flight-1',
        holeIds: ids,
        playerIds: const ['p1'],
      );
      cubit.emit(
        ScorecardScreenState(
          flightId: 'flight-1',
          holeIds: ids,
          currentHoleIndex: index,
        ),
      );
      return cubit;
    }

    test('next on the last hole comes round to the first', () {
      final cubit = cubitAt(17);

      cubit.navigateToNextHole();

      expect(cubit.state.currentHoleIndex, 0);
    });

    test('back on the first hole comes round to the last', () {
      final cubit = cubitAt(0);

      cubit.navigateToPreviousHole();

      expect(cubit.state.currentHoleIndex, 17);
    });

    test('still steps one at a time in the middle', () {
      final cubit = cubitAt(5);

      cubit.navigateToNextHole();
      expect(cubit.state.currentHoleIndex, 6);

      cubit.navigateToPreviousHole();
      expect(cubit.state.currentHoleIndex, 5);
    });

    /// It wraps the round's own list, not a hardcoded eighteen.
    test('a nine wraps at the ninth', () {
      final cubit = cubitAt(8, holes: 9);

      cubit.navigateToNextHole();

      expect(cubit.state.currentHoleIndex, 0);
    });

    test('a round with no holes does not move', () {
      final cubit = cubitAt(0, holes: 0);

      cubit.navigateToNextHole();
      cubit.navigateToPreviousHole();

      expect(cubit.state.currentHoleIndex, 0);
    });
  });
}
