// Course Search Repository — VSP Mobile App
//
// Repository wrapping CourseSearchApi with in-memory cache for favorites/recent.
// Mirrors BagRepository pattern from Story 2-3-B.
//
// Responsibilities:
// - Search: always fetches from API (no local cache — results are paginated)
// - Favorites: in-memory cache with optimistic updates
// - Recent: in-memory cache with optimistic updates

import '../../domain/models/course_search_result.dart';
import '../../domain/models/favorite_course.dart';
import '../../domain/models/recent_course.dart';
import '../api/course_search_api.dart';

/// Repository for course search, favorites, and recent courses.
///
/// Provides:
/// - Course search (text, nearby, combined) — always API
/// - Favorites list with local cache — AC-1
/// - Recent courses list with local cache — AC-1
///
/// Local caching strategy for favorites/recent:
/// - Read from cache first (optimistic)
/// - Refresh from API on explicit reload
/// - Write operations update cache optimistically
class CourseSearchRepository {
  final CourseSearchApi _api;

  /// In-memory cache of favorite courses (optimistic read).
  List<FavoriteCourse> _favoritesCache = [];

  /// In-memory cache of recent courses (optimistic read).
  List<RecentCourse> _recentCache = [];

  CourseSearchRepository({required CourseSearchApi api}) : _api = api;

  // ─── Search (always API) ───────────────────────────────────────────────────

  /// Search courses by text and/or geographic location.
  ///
  /// AC-1: text and geographic filters with paginated results.
  /// AC-2: nearby search uses index-aware spatial filtering (server-side).
  /// AC-3: results include verification, data freshness, download, update state.
  ///
  /// [params.latitude], [params.longitude], [params.radiusMeters] for nearby.
  /// [params.query] for text search.
  /// [params.downloadedVersion] to get [CourseSearchResult.updateAvailable] computed.
  Future<CourseSearchPage> searchCourses(CourseSearchParams params) {
    return _api.searchCourses(params);
  }

  /// Pure nearby search — courses ordered by distance from coordinates.
  ///
  /// AC-2: ST_DWithin with GIST spatial index (server-side).
  Future<CourseSearchPage> findNearbyCourses({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int page = 0,
    int size = 20,
  }) {
    return _api.findNearbyCourses(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      page: page,
      size: size,
    );
  }

  /// Get a single course search result with DataFreshness.
  Future<CourseSearchResult> getCourseSearchResult(int courseId) {
    return _api.getCourseSearchResult(courseId);
  }

  // ─── Favorites ─────────────────────────────────────────────────────────────

  /// Fetch all favorited courses for the authenticated user.
  ///
  /// Set [forceReload] to true to bypass cache and fetch from API.
  Future<List<FavoriteCourse>> getFavorites({bool forceReload = false}) async {
    if (!forceReload && _favoritesCache.isNotEmpty) {
      return _favoritesCache;
    }
    _favoritesCache = await _api.getFavorites();
    return _favoritesCache;
  }

  /// Add a course to favorites.
  ///
  /// Updates local cache optimistically.
  /// Records the view via [recordRecentView] on the same course.
  Future<void> addFavorite(int courseId) async {
    // Optimistic: add to cache immediately
    // Use a placeholder that will be replaced on next getFavorites
    final optimisticFavorite = FavoriteCourse(
      courseId: courseId,
      facilityId: 0, // Will be filled from API response
      facilityName: '',
      holesCount: 0,
      favoritedAt: DateTime.now(),
    );
    _favoritesCache = [optimisticFavorite, ..._favoritesCache];

    try {
      await _api.addFavorite(courseId);
      // Refresh to get full data with correct facility info
      _favoritesCache = await _api.getFavorites();
    } catch (_) {
      // Remove optimistic entry on failure
      _favoritesCache = _favoritesCache
          .where((f) => f.courseId != courseId)
          .toList();
      rethrow;
    }
  }

  /// Remove a course from favorites.
  ///
  /// Updates local cache optimistically.
  Future<void> removeFavorite(int courseId) async {
    final beforeCount = _favoritesCache.length;
    _favoritesCache = _favoritesCache
        .where((f) => f.courseId != courseId)
        .toList();

    try {
      await _api.removeFavorite(courseId);
    } catch (_) {
      // Revert optimistic removal on failure
      _favoritesCache = await _api.getFavorites();
      rethrow;
    }
  }

  /// Check if a course is in the favorites cache (optimistic).
  Future<bool> isFavorite(int courseId) async {
    if (_favoritesCache.any((f) => f.courseId == courseId)) return true;
    // Fallback: reload and check
    await getFavorites(forceReload: true);
    return _favoritesCache.any((f) => f.courseId == courseId);
  }

  // ─── Recent Courses ─────────────────────────────────────────────────────────

  /// Fetch recently viewed courses for the authenticated user.
  ///
  /// Set [forceReload] to true to bypass cache and fetch from API.
  Future<List<RecentCourse>> getRecentCourses({
    bool forceReload = false,
    int limit = 10,
  }) async {
    if (!forceReload && _recentCache.isNotEmpty) {
      return _recentCache;
    }
    _recentCache = await _api.getRecentCourses(limit: limit);
    return _recentCache;
  }

  /// Record a course view (adds or updates in recent list).
  ///
  /// AC-1: recent support.
  /// Enforces 10-entry cap server-side.
  /// Updates local cache optimistically.
  Future<void> recordRecentView(int courseId) async {
    // Optimistic: add/update in cache immediately
    final existingIdx = _recentCache.indexWhere((r) => r.courseId == courseId);
    final now = DateTime.now();
    if (existingIdx >= 0) {
      // Update existing entry (move to front)
      final existing = _recentCache.removeAt(existingIdx);
      _recentCache = [
        RecentCourse(
          courseId: existing.courseId,
          facilityId: existing.facilityId,
          facilityName: existing.facilityName,
          courseName: existing.courseName,
          address: existing.address,
          holesCount: existing.holesCount,
          viewedAt: now,
        ),
        ..._recentCache,
      ];
    } else {
      // Add optimistic entry
      _recentCache = [
        RecentCourse(
          courseId: courseId,
          facilityId: 0,
          facilityName: '',
          holesCount: 0,
          viewedAt: now,
        ),
        ..._recentCache,
      ];
    }

    try {
      await _api.recordRecentView(courseId);
      // Refresh to get full data
      _recentCache = await _api.getRecentCourses();
    } catch (_) {
      // Revert optimistic update on failure
      _recentCache = await _api.getRecentCourses();
      rethrow;
    }
  }

  // ─── Cache Invalidation ─────────────────────────────────────────────────────

  /// Clear all local caches (e.g., on logout).
  void clearCache() {
    _favoritesCache = [];
    _recentCache = [];
  }
}
