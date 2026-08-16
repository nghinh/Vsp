// Crossing from one đường to another mid-round.
//
// A round of two nines changes course at hole 10, and the hole number alone
// cannot say so: round hole 10 is the back nine's hole 1. Navigating to
// "hole 1" without naming the course left the map on the front nine's first —
// the right number, the wrong hole, and nothing on screen to tell them apart.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/hole_map/presentation/hole_map_event.dart';

void main() {
  group('NavigateToHole', () {
    test('carries the đường when the round crosses to the back nine', () {
      const event = NavigateToHole(holeNumber: 1, courseId: '1352');

      expect(event.holeNumber, 1);
      expect(event.courseId, '1352');
    });

    /// Within one nine the course does not change, and saying nothing means
    /// "stay where you are" rather than "go to course null".
    test('a move within one đường names no course', () {
      const event = NavigateToHole(holeNumber: 4);

      expect(event.courseId, isNull);
    });

    /// The same hole on two đường is two different events — otherwise a bloc
    /// that dedupes on equality would ignore the crossing entirely.
    test('the same hole on two đường are different events', () {
      const front = NavigateToHole(holeNumber: 1, courseId: '1351');
      const back = NavigateToHole(holeNumber: 1, courseId: '1352');

      expect(front, isNot(equals(back)));
    });

    test('two moves to the same hole on the same đường are equal', () {
      expect(
        const NavigateToHole(holeNumber: 3, courseId: '1351'),
        const NavigateToHole(holeNumber: 3, courseId: '1351'),
      );
    });
  });
}
