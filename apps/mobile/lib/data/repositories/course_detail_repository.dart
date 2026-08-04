// Course Detail Repository — VSP Mobile App
//
// Repository wrapping CourseDetailApi.
// No local caching — always fetches fresh data for detail screen.

import '../../domain/models/course_detail.dart';
import '../api/course_detail_api.dart';

/// Repository for course detail.
class CourseDetailRepository {
  final CourseDetailApi _api;

  CourseDetailRepository({required CourseDetailApi api}) : _api = api;

  /// Fetch full course detail.
  ///
  /// AC-1: includes contact, coordinates, facilities, holes, tee sets,
  ///       local rules, ratings, conditions, and update time.
  /// AC-2: null fields rendered as "unavailable".
  /// AC-3: dataQuality field carries verification + accuracy class for badges.
  Future<CourseDetail> getCourseDetail(int courseId) {
    return _api.getCourseDetail(courseId);
  }
}
