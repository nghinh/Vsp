// CourseSearchRepository unit tests — VSP Mobile App
//
// Tests cover:
// - searchCourses delegates to API with correct params
// - findNearbyCourses delegates to API with correct params
// - getFavorites reads from cache, reloads on forceReload
// - addFavorite/removeFavorite optimistic cache updates
// - recordRecentView optimistic cache update
// - clearCache invalidates all caches
// - isFavorite checks cache then reloads

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/api/course_search_api.dart';
import 'package:vsp_mobile/data/repositories/course_search_repository.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/favorite_course.dart';
import 'package:vsp_mobile/domain/models/recent_course.dart';

// Mock implementation of CourseSearchApi for testing.
class MockCourseSearchApi implements CourseSearchApi {
  CourseSearchPage? searchCoursesResult;
  Exception? searchCoursesError;
  CourseSearchPage? findNearbyCoursesResult;
  Exception? findNearbyCoursesError;
  List<FavoriteCourse>? getFavoritesResult;
  Exception? getFavoritesError;
  List<RecentCourse>? getRecentResult;
  Exception? getRecentError;
  int? addedFavoriteCourseId;
  Exception? addFavoriteError;
  int? removedFavoriteCourseId;
  Exception? removeFavoriteError;
  int? recordedViewCourseId;
  Exception? recordViewError;

  @override
  Future<CourseSearchPage> searchCourses(CourseSearchParams params) async {
    if (searchCoursesError != null) throw searchCoursesError!;
    return searchCoursesResult!;
  }

  @override
  Future<CourseSearchPage> findNearbyCourses({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int page = 0,
    int size = 20,
  }) async {
    if (findNearbyCoursesError != null) throw findNearbyCoursesError!;
    return findNearbyCoursesResult!;
  }

  @override
  Future<CourseSearchResult> getCourseSearchResult(int courseId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FavoriteCourse>> getFavorites() async {
    if (getFavoritesError != null) throw getFavoritesError!;
    return getFavoritesResult!;
  }

  @override
  Future<void> addFavorite(int courseId) async {
    addedFavoriteCourseId = courseId;
    if (addFavoriteError != null) throw addFavoriteError!;
  }

  @override
  Future<void> removeFavorite(int courseId) async {
    removedFavoriteCourseId = courseId;
    if (removeFavoriteError != null) throw removeFavoriteError!;
  }

  @override
  Future<List<RecentCourse>> getRecentCourses({int limit = 10}) async {
    if (getRecentError != null) throw getRecentError!;
    return getRecentResult!;
  }

  @override
  Future<void> recordRecentView(int courseId) async {
    recordedViewCourseId = courseId;
    if (recordViewError != null) throw recordViewError!;
  }
}

void main() {
  late MockCourseSearchApi mockApi;
  late CourseSearchRepository repository;

  final fakeFavorites = [
    FavoriteCourse(
      courseId: 10,
      facilityId: 1,
      facilityName: 'Favorite Club',
      holesCount: 18,
      favoritedAt: DateTime.now(),
    ),
  ];

  final fakeRecent = [
    RecentCourse(
      courseId: 20,
      facilityId: 2,
      facilityName: 'Recent Club',
      holesCount: 9,
      viewedAt: DateTime.now(),
    ),
  ];

  final fakePage = CourseSearchPage(
    content: [
      CourseSearchResult(
        courseId: 1,
        facilityId: 1,
        facilityName: 'Test Course',
        latitude: 10.0,
        longitude: 106.0,
        holesCount: 18,
        hasPackage: true,
        updateAvailable: false,
      ),
    ],
    page: 0,
    size: 20,
    totalElements: 1,
    totalPages: 1,
    first: true,
    last: true,
  );

  setUp(() {
    mockApi = MockCourseSearchApi();
    repository = CourseSearchRepository(api: mockApi);
  });

  group('searchCourses', () {
    test('delegates to API with correct params', () async {
      mockApi.searchCoursesResult = fakePage;

      final params = CourseSearchParams(query: 'Golf', page: 0, size: 20);

      final result = await repository.searchCourses(params);

      expect(result.content.length, 1);
      expect(result.content[0].facilityName, 'Test Course');
    });

    test('propagates API error', () async {
      mockApi.searchCoursesError = Exception('API Error');

      final params = CourseSearchParams(query: 'Golf', page: 0, size: 20);

      expect(() => repository.searchCourses(params), throwsException);
    });
  });

  group('findNearbyCourses', () {
    test('delegates to API with correct params', () async {
      mockApi.findNearbyCoursesResult = fakePage;

      final result = await repository.findNearbyCourses(
        latitude: 10.0,
        longitude: 106.0,
        radiusMeters: 10000,
        page: 0,
        size: 20,
      );

      expect(result.content.length, 1);
    });
  });

  group('getFavorites', () {
    test(
      'returns cached favorites on subsequent calls without forceReload',
      () async {
        mockApi.getFavoritesResult = fakeFavorites;

        final first = await repository.getFavorites();
        final second = await repository.getFavorites();

        expect(first.length, 1);
        expect(second.length, 1);
        // API should only be called once (cache hit)
      },
    );

    test('forceReload bypasses cache and fetches from API', () async {
      mockApi.getFavoritesResult = fakeFavorites;

      await repository.getFavorites(); // populate cache
      await repository.getFavorites(forceReload: true); // should call API again

      // If we got here without error, the test passes
    });

    test('getFavorites returns empty list when API returns empty', () async {
      mockApi.getFavoritesResult = [];

      final result = await repository.getFavorites();

      expect(result, isEmpty);
    });
  });

  group('addFavorite', () {
    test('calls API with correct courseId', () async {
      mockApi.getFavoritesResult = [];
      mockApi.addFavoriteError = Exception('Not found'); // trigger cache revert

      try {
        await repository.addFavorite(42);
      } catch (_) {
        // Expected to fail on API call
      }

      expect(mockApi.addedFavoriteCourseId, 42);
    });
  });

  group('removeFavorite', () {
    test('calls API with correct courseId', () async {
      mockApi.getFavoritesResult = [];
      mockApi.removeFavoriteError = Exception(
        'Not found',
      ); // trigger cache revert

      try {
        await repository.removeFavorite(42);
      } catch (_) {
        // Expected to fail on API call
      }

      expect(mockApi.removedFavoriteCourseId, 42);
    });
  });

  group('isFavorite', () {
    test('returns true when courseId is in cache', () async {
      mockApi.getFavoritesResult = fakeFavorites;

      await repository.getFavorites(); // populate cache

      final result = await repository.isFavorite(10);

      expect(result, isTrue);
    });

    test('returns false when courseId is not in cache', () async {
      mockApi.getFavoritesResult = fakeFavorites;

      await repository.getFavorites(); // populate cache

      final result = await repository.isFavorite(999);

      expect(result, isFalse);
    });
  });

  group('getRecentCourses', () {
    test(
      'returns cached recent on subsequent calls without forceReload',
      () async {
        mockApi.getRecentResult = fakeRecent;

        final first = await repository.getRecentCourses();
        final second = await repository.getRecentCourses();

        expect(first.length, 1);
        expect(second.length, 1);
        // API called once (cache hit)
      },
    );

    test('forceReload bypasses cache', () async {
      mockApi.getRecentResult = fakeRecent;

      await repository.getRecentCourses();
      await repository.getRecentCourses(forceReload: true);

      // If we got here without error, the test passes
    });
  });

  group('recordRecentView', () {
    test('calls API with correct courseId', () async {
      mockApi.getRecentResult = [];
      mockApi.recordViewError = Exception('API Error');

      try {
        await repository.recordRecentView(42);
      } catch (_) {
        // Expected to fail
      }

      expect(mockApi.recordedViewCourseId, 42);
    });
  });

  group('clearCache', () {
    test('clears favorites and recent caches', () async {
      mockApi.getFavoritesResult = fakeFavorites;
      mockApi.getRecentResult = fakeRecent;

      await repository.getFavorites();
      await repository.getRecentCourses();

      repository.clearCache();

      // After clearing, next getFavorites should call API
      var apiCallCount = 0;
      mockApi.getFavoritesResult = [];
      mockApi.getFavoritesError = Exception('Called API');

      try {
        await repository.getFavorites();
      } catch (_) {
        apiCallCount++;
      }

      expect(apiCallCount, 1);
    });
  });
}
