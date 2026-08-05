// Course Search API — VSP Mobile App
//
// API client for course search, nearby, favorites, and recent endpoints.
// All methods return structured results or throw VspApiException.

import '../../../core/network/api_client.dart';
import '../../domain/models/course_search_result.dart';
import '../../domain/models/favorite_course.dart';
import '../../domain/models/recent_course.dart';

/// Request parameters for course search.
class CourseSearchParams {
  final String? query;
  final double? latitude;
  final double? longitude;
  final double? radiusMeters;
  final int page;
  final int size;
  final int? downloadedVersion;

  const CourseSearchParams({
    this.query,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.page = 0,
    this.size = 20,
    this.downloadedVersion,
  });

  /// Build query parameters map for API call.
  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (query != null && query!.isNotEmpty) params['q'] = query!;
    if (latitude != null) params['lat'] = latitude.toString();
    if (longitude != null) params['lng'] = longitude.toString();
    if (radiusMeters != null) params['radiusMeters'] = radiusMeters.toString();
    if (downloadedVersion != null) {
      params['downloadedVersion'] = downloadedVersion.toString();
    }
    return params;
  }

  /// True if this is a nearby search (has lat/lng).
  bool get isNearbySearch => latitude != null && longitude != null;
}

/// Course search API client — wraps all /courses/search and user-scoped endpoints.
///
/// Endpoints:
/// - GET /courses/search — text and/or geographic search
/// - GET /courses/nearby — pure nearby search
/// - GET /courses/{courseId}/search-result — single course search result
/// - GET /users/me/favorites — list favorites
/// - POST /users/me/favorites/{courseId} — add favorite
/// - DELETE /users/me/favorites/{courseId} — remove favorite
/// - GET /users/me/recent — list recent courses
/// - POST /users/me/recent/{courseId} — record a view
class CourseSearchApi {
  final ApiClient _apiClient;

  CourseSearchApi({required ApiClient apiClient}) : _apiClient = apiClient;

  // ─── Course Search ──────────────────────────────────────────────────────────

  /// GET /courses/search
  ///
  /// Supports three modes:
  /// - Text-only: provide [query]
  /// - Nearby-only: provide [latitude], [longitude], [radiusMeters]
  /// - Combined: provide both text and geographic params
  ///
  /// Pass [downloadedVersion] to get [CourseSearchResult.updateAvailable] computed
  /// server-side.
  Future<CourseSearchPage> searchCourses(CourseSearchParams params) async {
    final response = await _apiClient.get(
      '/courses/search',
      queryParams: params.toQueryParams(),
    );
    return CourseSearchPage.fromJson(response as Map<String, dynamic>);
  }

  /// GET /courses/nearby
  ///
  /// Pure nearby search — returns courses ordered by distance.
  /// Uses ST_DWithin with GIST spatial index (server-side).
  Future<CourseSearchPage> findNearbyCourses({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _apiClient.get(
      '/courses/nearby',
      queryParams: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radiusMeters': radiusMeters.toString(),
        'page': page.toString(),
        'size': size.toString(),
      },
    );
    return CourseSearchPage.fromJson(response as Map<String, dynamic>);
  }

  /// GET /courses/{courseId}/search-result
  ///
  /// Returns a single course search result with full DataFreshness.
  Future<CourseSearchResult> getCourseSearchResult(int courseId) async {
    final response = await _apiClient.get('/courses/$courseId/search-result');
    return CourseSearchResult.fromJson(response as Map<String, dynamic>);
  }

  // ─── Favorites ───────────────────────────────────────────────────────────────

  /// GET /users/me/favorites
  ///
  /// Returns all favorited courses for the authenticated golfer.
  Future<List<FavoriteCourse>> getFavorites() async {
    final response = await _apiClient.get('/users/me/favorites');
    final list = response as List<dynamic>;
    return list
        .map((e) => FavoriteCourse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /users/me/favorites/{courseId}
  ///
  /// Adds a course to the authenticated golfer's favorites.
  /// Returns 201 Created on success.
  Future<void> addFavorite(int courseId) async {
    await _apiClient.post('/users/me/favorites/$courseId');
  }

  /// DELETE /users/me/favorites/{courseId}
  ///
  /// Removes a course from the authenticated golfer's favorites.
  /// Returns 204 No Content on success.
  Future<void> removeFavorite(int courseId) async {
    await _apiClient.delete('/users/me/favorites/$courseId');
  }

  // ─── Recent Courses ─────────────────────────────────────────────────────────

  /// GET /users/me/recent
  ///
  /// Returns the most recently viewed courses for the authenticated golfer.
  /// Returns up to [limit] entries (default 10, max 10).
  Future<List<RecentCourse>> getRecentCourses({int limit = 10}) async {
    final response = await _apiClient.get(
      '/users/me/recent',
      queryParams: {'limit': limit.toString()},
    );
    final list = response as List<dynamic>;
    return list
        .map((e) => RecentCourse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /users/me/recent/{courseId}
  ///
  /// Records a course view for the authenticated golfer.
  /// Updates viewedAt if the course was already recently viewed.
  /// Enforces 10-entry per-user cap (server-side trim).
  Future<void> recordRecentView(int courseId) async {
    await _apiClient.post('/users/me/recent/$courseId');
  }
}
