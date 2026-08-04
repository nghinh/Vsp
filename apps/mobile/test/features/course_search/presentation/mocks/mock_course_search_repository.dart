// Mock Course Search Repository — Test Helper
//
// Mock implementation of CourseSearchRepository for BLoC unit tests.

import 'package:vsp_mobile/data/api/course_search_api.dart';
import 'package:vsp_mobile/data/repositories/course_search_repository.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/favorite_course.dart';
import 'package:vsp_mobile/domain/models/recent_course.dart';

class MockCourseSearchRepository implements CourseSearchRepository {
  // Favorites
  List<FavoriteCourse> mockFavorites = [];
  List<FavoriteCourse> mockGetFavorites = [];
  Exception? mockGetFavoritesError;

  // Recent
  List<RecentCourse> mockRecentCourses = [];
  List<RecentCourse> mockGetRecentCourses = [];
  Exception? mockGetRecentCoursesError;

  // Search
  CourseSearchPage? mockSearchPage;
  CourseSearchPage? mockNearbyPage;
  Exception? mockSearchError;

  @override
  Future<CourseSearchPage> searchCourses(CourseSearchParams params) async {
    if (mockSearchError != null) throw mockSearchError!;
    return mockSearchPage ??
        CourseSearchPage(
          content: const [],
          page: 0,
          size: 20,
          totalElements: 0,
          totalPages: 0,
          first: true,
          last: true,
        );
  }

  @override
  Future<CourseSearchPage> findNearbyCourses({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int page = 0,
    int size = 20,
  }) async {
    if (mockSearchError != null) throw mockSearchError!;
    return mockNearbyPage ??
        CourseSearchPage(
          content: const [],
          page: 0,
          size: 20,
          totalElements: 0,
          totalPages: 0,
          first: true,
          last: true,
        );
  }

  @override
  Future<CourseSearchResult> getCourseSearchResult(int courseId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FavoriteCourse>> getFavorites({bool forceReload = false}) async {
    if (mockGetFavoritesError != null) throw mockGetFavoritesError!;
    return mockGetFavorites;
  }

  @override
  Future<void> addFavorite(int courseId) async {
    mockFavorites.add(
      FavoriteCourse(
        courseId: courseId,
        facilityId: 0,
        facilityName: '',
        holesCount: 0,
        favoritedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> removeFavorite(int courseId) async {
    mockFavorites = mockFavorites.where((f) => f.courseId != courseId).toList();
  }

  @override
  Future<bool> isFavorite(int courseId) async {
    return mockFavorites.any((f) => f.courseId == courseId);
  }

  @override
  Future<List<RecentCourse>> getRecentCourses({
    bool forceReload = false,
    int limit = 10,
  }) async {
    if (mockGetRecentCoursesError != null) throw mockGetRecentCoursesError!;
    return mockGetRecentCourses;
  }

  @override
  Future<void> recordRecentView(int courseId) async {}

  @override
  void clearCache() {
    mockFavorites = [];
  }
}
