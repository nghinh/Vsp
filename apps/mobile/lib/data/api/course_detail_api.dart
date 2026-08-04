// Course Detail API — VSP Mobile App
//
// API client for course detail endpoint.
// Mirrors CourseDetailDto from packages/contracts/schemas/course.yaml.

import '../../../core/network/api_client.dart';
import '../../domain/models/course_detail.dart';

/// Course detail API client — wraps GET /courses/{id}.
class CourseDetailApi {
  final ApiClient _apiClient;

  CourseDetailApi({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /courses/{courseId}
  ///
  /// Returns full course detail with all AC-1 fields.
  /// Throws VspApiException on error (404 COURSE_001 if not found).
  Future<CourseDetail> getCourseDetail(int courseId) async {
    final response = await _apiClient.get('/courses/$courseId');
    return CourseDetail.fromJson(response as Map<String, dynamic>);
  }
}
