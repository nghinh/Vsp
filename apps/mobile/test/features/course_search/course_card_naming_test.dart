// What a search result calls itself.
//
// A golfer searches for the club. The card showed `courseName ?? facilityName`,
// which was fine while every facility held one course named "<club> —
// Championship" and the club's name sat inside the course's. Loading the real
// đường broke it: searching "Long Biên" returned three cards reading "Đường A",
// "Đường B" and "Đường C", the club's name nowhere on screen — a search that
// worked and looked like it had failed.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';

CourseSearchResult result({required String facility, String? course}) =>
    CourseSearchResult(
      courseId: 1,
      facilityId: 1,
      facilityName: facility,
      courseName: course,
      holesCount: 9,
      hasPackage: false,
      updateAvailable: false,
    );

void main() {
  group('naming a search result', () {
    test('leads with the club, which is what was searched for', () {
      final r = result(facility: 'Long Biên Golf Course', course: 'Đường A');
      // The course keeps its own identity for the round and the tee picker.
      expect(r.displayName, 'Đường A');

      expect(r.clubName, 'Long Biên Golf Course');
    });

    test('names the đường underneath it', () {
      final r = result(facility: 'Long Biên Golf Course', course: 'Đường A');

      expect(r.unitName, 'Đường A');
    });

    /// A facility with one course called "<club> — Championship" would print
    /// the club's name twice, once in each line.
    test('says nothing twice for a seeded Championship course', () {
      final r = result(
        facility: 'Tam Đảo Golf Resort',
        course: 'Tam Đảo Golf Resort — Championship',
      );

      expect(r.clubName, 'Tam Đảo Golf Resort');
      expect(r.unitName, isNull);
    });

    test('copes with a result carrying no course name at all', () {
      final r = result(facility: 'Sapa Grand Golf Course');

      expect(r.clubName, 'Sapa Grand Golf Course');
      expect(r.unitName, isNull);
    });

    /// Kings Island's courses have their own names and are not "Đường"
    /// anything — they still belong under the club.
    test('names a course that is not a đường', () {
      final r = result(
        facility: 'BRG Kings Island Golf Resort',
        course: 'Mountain View Course',
      );

      expect(r.clubName, 'BRG Kings Island Golf Resort');
      expect(r.unitName, 'Mountain View Course');
    });
  });
}
