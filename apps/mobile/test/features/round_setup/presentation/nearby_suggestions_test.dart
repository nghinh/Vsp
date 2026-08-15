// What the course picker offers when a round is about to start.
//
// The picker listed the whole catalogue alphabetically under a heading that
// said these were the nearby ones. They were not: nothing had asked where the
// golfer was, so a golfer standing at Long Biên was offered ANARA Bình Tiên,
// 1,100 km away, at the top of the list.
//
// Nearby now means nearby — a GPS fix and the server's radius query — and the
// catalogue sits underneath it, minus whatever the nearby list already named.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/round_setup_event.dart';
import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  NearbyCourseSuggestion course(int id, String name, {double? km}) =>
      NearbyCourseSuggestion(
        courseId: id,
        courseName: name,
        distanceKm: km,
      );

  final anara = course(1, 'ANARA Bình Tiên Golf Club — Championship');
  final baNa = course(2, 'Ba Na Hills Golf Club — Championship');
  final longBien = course(3, 'Long Biên Golf Course');
  final kings = course(4, 'BRG Kings Island — Kings Course');

  group('catalogueBeyondNearby', () {
    test('a course listed as nearby is not repeated in the catalogue', () {
      final state = RoundSetupReady(
        nearbyCourses: [course(3, 'Long Biên Golf Course', km: 4.2)],
        allCourses: [anara, baNa, longBien, kings],
      );

      expect(
        state.catalogueBeyondNearby.map((c) => c.courseId),
        [1, 2, 4],
      );
    });

    test('without a fix the catalogue is untouched', () {
      // No permission, no signal, or nothing within the radius — all the same
      // answer, and the picker still lists everything it knows.
      final state = RoundSetupReady(allCourses: [anara, baNa, longBien]);

      expect(state.nearbyCourses, isEmpty);
      expect(state.catalogueBeyondNearby, hasLength(3));
    });

    test('nearby keeps the order the server sent, nearest first', () {
      final state = RoundSetupReady(
        nearbyCourses: [
          course(3, 'Long Biên Golf Course', km: 4.2),
          course(4, 'BRG Kings Island — Kings Course', km: 41.8),
        ],
        allCourses: [anara, baNa],
      );

      expect(state.nearbyCourses.map((c) => c.distanceKm), [4.2, 41.8]);
      // And the far half of the country is still reachable underneath.
      expect(state.catalogueBeyondNearby.map((c) => c.courseId), [1, 2]);
    });

    test('a catalogue that never loaded leaves nearby standing alone', () {
      final state = RoundSetupReady(
        nearbyCourses: [course(3, 'Long Biên Golf Course', km: 4.2)],
      );

      expect(state.catalogueBeyondNearby, isEmpty);
      expect(state.nearbyCourses, hasLength(1));
    });
  });
}
