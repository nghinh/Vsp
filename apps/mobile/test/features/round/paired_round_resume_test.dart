// Where holes 10 to 18 live, after the app has been closed and reopened.
//
// Long Biên has three đường of nine holes and a round there is a pairing
// chosen on the day: A then B, or C then A. Round hole 10 is hole 1 of
// whichever nine came second, and the active round screen has always known how
// to do that translation — given the second đường.
//
// It was given one when the round started and not when the round was resumed,
// because nothing in between carried it. The round setup screen passed it
// straight into the active round and never into the stored round; the API
// column existed and RoundResponse did not expose it; the local rounds table
// had no column for it. So a golfer who started A+B, closed the app on the 9th
// and came back to the 10th got a map that said the hole had not been
// surveyed — while the geometry sat in the database under Đường B, hole 1.
//
// Four links in that chain, and a break in any one of them looks identical
// from the tee.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/features/round/data/round_history_repository.dart';

void main() {
  Round paired({int? backNine}) => Round(
    id: 'r1',
    courseId: 1351, // Đường A
    backNineCourseId: backNine,
    courseName: 'Long Biên Golf Course',
    status: RoundStatus.inProgress,
    startedAt: DateTime.utc(2026, 8, 16, 6),
    packageVersion: 'v1',
    createdAt: DateTime.utc(2026, 8, 16, 6),
    updatedAt: DateTime.utc(2026, 8, 16, 6),
  );

  group('the round remembers its second nine', () {
    test('through the local database', () {
      // The round table is where a resumed round is read from, so a field that
      // does not survive toMap/fromMap does not survive closing the app.
      final restored = Round.fromMap(paired(backNine: 1352).toMap());

      expect(restored.backNineCourseId, 1352);
    });

    test('and a round on one course keeps no second nine', () {
      final restored = Round.fromMap(paired().toMap());

      expect(restored.backNineCourseId, isNull);
    });

    test('a row written before the column existed reads as null', () {
      // Every in-progress round on an installed app is such a row. It must
      // read back as "no pairing" rather than throwing.
      final row = paired(backNine: 1352).toMap()..remove('back_nine_course_id');

      expect(Round.fromMap(row).backNineCourseId, isNull);
    });

    test('two rounds differing only in their second nine are not equal', () {
      // Equatable decides whether a rebuild happens. Left out of props, a
      // round that gained its pairing would compare equal to one without.
      expect(paired(backNine: 1352), isNot(equals(paired(backNine: 1353))));
      expect(paired(backNine: 1352), equals(paired(backNine: 1352)));
    });
  });

  group('the round remembers its second nine through the API', () {
    test('the history list carries it', () {
      final round = roundFromApiJson({
        'id': 'r1',
        'courseId': 1351,
        'backNineCourseId': 1352,
        'courseName': 'Long Biên Golf Course',
        'status': 'IN_PROGRESS',
        'startedAt': '2026-08-16T06:00:00Z',
        'createdAt': '2026-08-16T06:00:00Z',
      });

      expect(round.backNineCourseId, 1352);
    });

    test('a server that does not send it is not an error', () {
      // Older deployments. The round then behaves as it did before this
      // existed, which is the safe direction to fail in.
      final round = roundFromApiJson({
        'id': 'r1',
        'courseId': 1351,
        'courseName': 'Long Biên Golf Course',
        'status': 'IN_PROGRESS',
        'startedAt': '2026-08-16T06:00:00Z',
        'createdAt': '2026-08-16T06:00:00Z',
      });

      expect(round.backNineCourseId, isNull);
    });
  });

  group('which course a hole belongs to', () {
    // The translation ActiveRoundScreen does, stated here as the rule it is:
    // holes 1–9 are the first đường, 10–18 the second, and without a second
    // every hole belongs to the first — including a tenth it does not have.
    int? courseFor(int hole, {required int first, int? second}) =>
        second != null && hole > 9 ? second : first;
    int holeOnCourse(int hole, {int? second}) =>
        second != null && hole > 9 ? hole - 9 : hole;

    test('a paired round sends hole 10 to the second đường as its hole 1', () {
      expect(courseFor(10, first: 1351, second: 1352), 1352);
      expect(holeOnCourse(10, second: 1352), 1);
      expect(courseFor(18, first: 1351, second: 1352), 1352);
      expect(holeOnCourse(18, second: 1352), 9);
    });

    test('the front nine is untouched', () {
      expect(courseFor(9, first: 1351, second: 1352), 1351);
      expect(holeOnCourse(9, second: 1352), 9);
    });

    test('without a second đường, hole 10 asks a nine for a hole it has not', () {
      // This is the bug, written down. The request is well-formed and the
      // answer is empty, which the map reports as "not surveyed" — the one
      // explanation that is not what happened.
      expect(courseFor(10, first: 1351), 1351);
      expect(holeOnCourse(10), 10);
    });
  });
}
