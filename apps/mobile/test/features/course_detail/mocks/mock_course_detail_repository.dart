// Mock Course Detail Repository — VSP Mobile App

import 'package:vsp_mobile/data/repositories/course_detail_repository.dart';
import 'package:vsp_mobile/domain/models/course_detail.dart';

/// Mock implementation of CourseDetailRepository for testing.
class MockCourseDetailRepository implements CourseDetailRepository {
  CourseDetail? mockCourseDetail;
  Exception? mockException;

  @override
  Future<CourseDetail> getCourseDetail(int courseId) async {
    if (mockException != null) {
      throw mockException!;
    }
    if (mockCourseDetail != null) {
      return mockCourseDetail!;
    }
    throw UnimplementedError('Mock not set up — call setMockCourseDetail() first');
  }
}
