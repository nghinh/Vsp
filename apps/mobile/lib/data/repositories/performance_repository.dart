// PerformanceRepository — VSP Mobile App
//
// Repository for club performance and dispersion overlay data.
// Per Story 11.1 Slice 3 (Flutter).
//
// Provides caching for offline support.

import '../../core/network/api_client.dart';
import '../../domain/models/performance/club_performance_stats.dart';
import '../../domain/models/performance/dispersion_overlay.dart';
import '../api/performance_api.dart';

/// Repository for club performance data with caching.
/// Per Story 11.1 Slice 3: supports offline caching.
class PerformanceRepository {
  final PerformanceApi _api;
  final ApiClient _apiClient;

  /// In-memory cache for club performance stats.
  /// Key: "{bagId}-{clubId}"
  final Map<String, ClubPerformanceStats> _clubStatsCache = {};

  /// In-memory cache for bag performance.
  /// Key: "{bagId}"
  final Map<String, BagPerformance> _bagStatsCache = {};

  /// In-memory cache for dispersion overlays.
  /// Key: "{bagId}-{clubId}-{holeId}-{layoutId}"
  final Map<String, DispersionOverlay> _dispersionCache = {};

  PerformanceRepository({
    required PerformanceApi api,
    required ApiClient apiClient,
  }) : _api = api,
       _apiClient = apiClient {
    _setupTokenRefresh();
  }

  void _setupTokenRefresh() {
    // Note: In a real implementation, we'd hook into an auth state notifier.
    // For now, we rely on the caller to set the token.
  }

  /// Set the access token for authenticated requests.
  void setAccessToken(String? token) {
    _api.setAccessToken(token);
  }

  // ─── Club Performance ───────────────────────────────────────────────────────

  /// Fetch performance stats for a specific club.
  /// Uses cache if available and forceReload is false.
  Future<ClubPerformanceStats> getClubPerformance({
    required int bagId,
    required int clubId,
    bool forceReload = false,
  }) async {
    final cacheKey = '$bagId-$clubId';

    if (!forceReload && _clubStatsCache.containsKey(cacheKey)) {
      return _clubStatsCache[cacheKey]!;
    }

    try {
      final response = await _api.getClubPerformance(
        bagId: bagId,
        clubId: clubId,
      );
      _clubStatsCache[cacheKey] = response.stats;
      return response.stats;
    } on VspApiException {
      // On error, return cached value if available
      if (_clubStatsCache.containsKey(cacheKey)) {
        return _clubStatsCache[cacheKey]!;
      }
      rethrow;
    }
  }

  // ─── Bag Performance ────────────────────────────────────────────────────────

  /// Fetch performance stats for all clubs in a bag.
  /// Uses cache if available and forceReload is false.
  Future<BagPerformance> getBagPerformance({
    required int bagId,
    bool forceReload = false,
  }) async {
    final cacheKey = '$bagId';

    if (!forceReload && _bagStatsCache.containsKey(cacheKey)) {
      return _bagStatsCache[cacheKey]!;
    }

    try {
      final response = await _api.getBagPerformance(bagId: bagId);
      _bagStatsCache[cacheKey] = response.performance;

      // Also update individual club caches
      for (final club in response.performance.clubs) {
        _clubStatsCache['$bagId-${club.clubId}'] = club;
      }

      return response.performance;
    } on VspApiException {
      // On error, return cached value if available
      if (_bagStatsCache.containsKey(cacheKey)) {
        return _bagStatsCache[cacheKey]!;
      }
      rethrow;
    }
  }

  // ─── Dispersion Overlay ────────────────────────────────────────────────────

  /// Fetch dispersion overlay for a club on a specific hole.
  /// Uses cache if available and forceReload is false.
  Future<DispersionOverlay> getDispersionOverlay({
    required int bagId,
    required int clubId,
    required int holeId,
    required int layoutId,
    bool forceReload = false,
  }) async {
    final cacheKey = '$bagId-$clubId-$holeId-$layoutId';

    if (!forceReload && _dispersionCache.containsKey(cacheKey)) {
      return _dispersionCache[cacheKey]!;
    }

    try {
      final response = await _api.getDispersionOverlay(
        bagId: bagId,
        clubId: clubId,
        holeId: holeId,
        layoutId: layoutId,
      );
      _dispersionCache[cacheKey] = response.overlay;
      return response.overlay;
    } on VspApiException {
      // On error, return cached value if available
      if (_dispersionCache.containsKey(cacheKey)) {
        return _dispersionCache[cacheKey]!;
      }
      rethrow;
    }
  }

  // ─── Cache Invalidation ─────────────────────────────────────────────────────

  /// Invalidate club performance cache for a specific club.
  void invalidateClubPerformance(int bagId, int clubId) {
    _clubStatsCache.remove('$bagId-$clubId');
  }

  /// Invalidate all bag performance cache.
  void invalidateBagPerformance(int bagId) {
    _bagStatsCache.remove('$bagId');
  }

  /// Invalidate dispersion overlay cache.
  void invalidateDispersionOverlay(
    int bagId,
    int clubId,
    int holeId,
    int layoutId,
  ) {
    _dispersionCache.remove('$bagId-$clubId-$holeId-$layoutId');
  }

  /// Clear all caches.
  void clearCache() {
    _clubStatsCache.clear();
    _bagStatsCache.clear();
    _dispersionCache.clear();
  }
}
