// Tests for the two tabs a golfer's own courses live in.
//
// Tapping a favourite recorded the view and then ran a comment:
// `// Navigate to course detail (placeholder)`. Same for Recent. So the tab
// holding a golfer's home course was the one place they could not open it from,
// and — because round setup opens this screen in selection mode — picking a
// course to play from Favourites did nothing at all.
//
// The fix needed a contract change rather than a Navigator.push. Round setup
// used to receive a whole CourseSearchResult, and a favourite carries no
// latitude or longitude, so returning one would have meant inventing
// coordinates for a course whose position the app knows perfectly well but not
// in that object. [CourseSelection] is the two fields round setup actually
// read.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/course_selection.dart';
import 'package:vsp_mobile/domain/models/favorite_course.dart';
import 'package:vsp_mobile/domain/models/recent_course.dart';

FavoriteCourse _favorite({String? courseName}) => FavoriteCourse(
  courseId: 10,
  facilityId: 1,
  facilityName: 'BRG Kings Island',
  courseName: courseName,
  holesCount: 18,
  favoritedAt: DateTime.utc(2026, 8, 1),
);

RecentCourse _recent({String? courseName}) => RecentCourse(
  courseId: 11,
  facilityId: 2,
  facilityName: 'Long Thành',
  courseName: courseName,
  holesCount: 18,
  viewedAt: DateTime.utc(2026, 8, 2),
);

void main() {
  test(
    'a favourite can be turned into a selection without inventing a position',
    () {
      final selection = CourseSelection.fromFavorite(
        _favorite(courseName: 'Mountainview'),
      );

      expect(selection.courseId, 10);
      expect(selection.displayName, 'Mountainview');
    },
  );

  test('a recent course carries the same two fields', () {
    final selection = CourseSelection.fromRecent(_recent(courseName: 'A'));

    expect(selection.courseId, 11);
    expect(selection.displayName, 'A');
  });

  test('a course with no name of its own falls back to the facility', () {
    // Common in the data: the facility is named and the course inside it is
    // not. Showing an empty line where the golfer expects their home club is
    // worse than showing the club.
    expect(
      CourseSelection.fromFavorite(_favorite()).displayName,
      'BRG Kings Island',
    );
    expect(CourseSelection.fromRecent(_recent()).displayName, 'Long Thành');
  });

  test('a search result converts the same way', () {
    final selection = CourseSelection.fromSearchResult(
      const CourseSearchResult(
        courseId: 12,
        facilityId: 3,
        facilityName: 'Vinpearl',
        courseName: 'Championship',
        latitude: 10.7,
        longitude: 106.7,
        holesCount: 18,
        hasPackage: false,
        updateAvailable: false,
      ),
    );

    // All three tabs return the same thing, so round setup has one shape to
    // handle rather than one working tab and two dead ones.
    expect(
      selection,
      const CourseSelection(courseId: 12, displayName: 'Championship'),
    );
  });
}
