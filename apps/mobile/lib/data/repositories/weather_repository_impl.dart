// WeatherRepositoryImpl — VSP Mobile App
//
// Story 7.1 Wave 2: Repository Implementation
// Per slice plan §2.3 — offline-first with API fetch and SQLite cache.
//
// Offline-first strategy:
// 1. Try cached snapshot first (instant, works offline)
// 2. If stale or missing, fetch fresh from API (requires network)
// 3. Cache fresh result for next offline use

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/models/weather_error.dart';
import '../../domain/models/weather_snapshot.dart';
import '../../domain/repositories/weather_repository.dart';
import '../api/weather_api.dart';
import '../local/daos/weather_dao.dart';
import '../services/connectivity_service.dart';

/// Implementation of WeatherRepository with offline-first caching.
class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherApi _weatherApi;
  final WeatherDao _weatherDao;
  final ConnectivityService? _connectivityService;

  /// Stream controllers per course for watchCachedWeather.
  final Map<String, StreamController<WeatherSnapshot?>> _watchControllers = {};

  WeatherRepositoryImpl({
    required WeatherApi weatherApi,
    WeatherDao? weatherDao,
    ConnectivityService? connectivityService,
  }) : _weatherApi = weatherApi,
       _weatherDao = weatherDao ?? WeatherDao.instance,
       _connectivityService =
           connectivityService ?? _defaultConnectivityService();

  static ConnectivityService? _defaultConnectivityService() {
    // Will be injected via constructor in practice
    return null;
  }

  @override
  Future<WeatherResult> getWeather(WeatherLocation location) async {
    final isOnline = await _isOnline();

    if (!isOnline) {
      // Offline: try cached
      final cached = await _getCachedByLocation(location);
      if (cached != null) {
        return WeatherResult.ok(cached);
      }
      return WeatherResult.err(WeatherError.network());
    }

    // Online: fetch fresh from API
    try {
      final apiResponse = await _weatherApi.getWeather(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      final snapshot = apiResponse.snapshot;
      final staleFlag = apiResponse.staleFlag;

      // Update freshness based on API stale header
      final updatedSnapshot = staleFlag
          ? snapshot.copyWith(freshness: DataFreshness.stale)
          : snapshot;

      // Cache the result if we have a courseId
      if (location.courseId != null) {
        await cacheWeather(location.courseId!, updatedSnapshot);
      }

      return WeatherResult.ok(updatedSnapshot);
    } on WeatherError catch (e) {
      // Try cached as fallback
      final cached = location.courseId != null
          ? await getCachedWeather(location.courseId!)
          : null;
      if (cached != null) {
        return WeatherResult.ok(cached);
      }
      return WeatherResult.err(e);
    } catch (e) {
      // Try cached as fallback
      final cached = location.courseId != null
          ? await getCachedWeather(location.courseId!)
          : null;
      if (cached != null) {
        return WeatherResult.ok(cached);
      }
      return WeatherResult.err(WeatherError.unknown(e.toString()));
    }
  }

  @override
  Future<WeatherSnapshot?> getCachedWeather(String courseId) async {
    return _weatherDao.getByCourseId(courseId);
  }

  @override
  Future<void> cacheWeather(String courseId, WeatherSnapshot snapshot) async {
    await _weatherDao.upsert(courseId, snapshot);
    _notifyWatchers(courseId, snapshot);
  }

  @override
  Stream<WeatherSnapshot?> watchCachedWeather(String courseId) {
    _watchControllers[courseId] ??=
        StreamController<WeatherSnapshot?>.broadcast();

    // Emit current cached value immediately
    () async {
      final cached = await getCachedWeather(courseId);
      _watchControllers[courseId]?.add(cached);
    }();

    return _watchControllers[courseId]!.stream;
  }

  @override
  Future<void> clearCache(String courseId) async {
    await _weatherDao.delete(courseId);
    _notifyWatchers(courseId, null);
  }

  @override
  Future<WeatherResult> refreshIfStale(
    String courseId,
    WeatherLocation location, {
    Duration maxAge = const Duration(minutes: 30),
  }) async {
    final cached = await getCachedWeather(courseId);
    if (cached == null) {
      return getWeather(location);
    }

    final age = DateTime.now().difference(cached.timestamp);
    if (age < maxAge) {
      return WeatherResult.ok(cached);
    }

    // Stale: try to refresh
    return getWeather(location);
  }

  /// Check if device is online.
  Future<bool> _isOnline() async {
    if (_connectivityService == null) return true;
    final results = await _connectivityService.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Get cached snapshot by location (uses course_id as key).
  Future<WeatherSnapshot?> _getCachedByLocation(
    WeatherLocation location,
  ) async {
    if (location.courseId == null) return null;
    return _weatherDao.getByCourseId(location.courseId!);
  }

  /// Notify all watchers of a course that the snapshot changed.
  void _notifyWatchers(String courseId, WeatherSnapshot? snapshot) {
    _watchControllers[courseId]?.add(snapshot);
  }
}
