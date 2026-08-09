// Course Selection — VSP Mobile App
//
// What comes back when a golfer picks a course to play.
//
// Round setup used to receive a whole [CourseSearchResult], which meant only
// the search tab could return one: a favourite and a recently-played course
// carry no coordinates, and building a search result for them would have meant
// inventing a latitude and longitude for a course whose position the app knows
// perfectly well but not in that object. So the Favourites and Recent tabs
// simply did nothing when tapped — in selection mode and out of it.
//
// Round setup only ever read two fields. This is those two fields.

import 'package:equatable/equatable.dart';

import 'course_search_result.dart';
import 'favorite_course.dart';
import 'recent_course.dart';

/// A course the golfer chose, from wherever they chose it.
class CourseSelection extends Equatable {
  final int courseId;

  /// Course name where there is one, otherwise the facility's.
  final String displayName;

  const CourseSelection({required this.courseId, required this.displayName});

  factory CourseSelection.fromSearchResult(CourseSearchResult course) =>
      CourseSelection(
        courseId: course.courseId,
        displayName: course.displayName,
      );

  factory CourseSelection.fromFavorite(FavoriteCourse favorite) =>
      CourseSelection(
        courseId: favorite.courseId,
        displayName: favorite.displayName,
      );

  factory CourseSelection.fromRecent(RecentCourse recent) => CourseSelection(
    courseId: recent.courseId,
    displayName: recent.displayName,
  );

  @override
  List<Object?> get props => [courseId, displayName];
}
