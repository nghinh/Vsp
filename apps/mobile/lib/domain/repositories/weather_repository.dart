// WeatherRepository — VSP Mobile App
//
// Story 7.1 Wave 2: Repository Interface
// AC-1: Mobile shows wind, temperature, precipitation, safety fields.
// AC-3: Source, timestamp, forecast/measurement type, stale warning, offline snapshot visible.
//
// Repository interface for weather data operations.
// Covers: fresh fetch, cached access, persistence, and real-time watching.

import 'package:equatable/equatable.dart';

import '../models/weather_error.dart';
import '../models/weather_snapshot.dart';

/// Result type for weather operations — Either<WeatherError, WeatherSnapshot>.
class WeatherResult extends Equatable {
  final WeatherSnapshot? snapshot;
  final WeatherError? error;

  const WeatherResult._({this.snapshot, this.error});

  /// Success result with snapshot.
  const WeatherResult.ok(WeatherSnapshot snapshot) : this._(snapshot: snapshot);

  /// Failure result with error.
  const WeatherResult.err(WeatherError error) : this._(error: error);

  bool get isOk => snapshot != null;
  bool get isErr => error != null;

  WeatherSnapshot get value => snapshot!;
  WeatherError get failure => error!;

  /// Map over the snapshot.
  WeatherResult map(WeatherSnapshot? Function(WeatherSnapshot) f) {
    if (snapshot != null) return WeatherResult.ok(f(snapshot!)!);
    return this;
  }

  /// Map over the error.
  WeatherResult mapError(WeatherError? Function(WeatherError) f) {
    if (error != null) return WeatherResult.err(f(error!)!);
    return this;
  }

  @override
  List<Object?> get props => [snapshot, error];
}

/// Qualified location for weather queries (course center or GPS position).
class WeatherLocation extends Equatable {
  final double latitude;
  final double longitude;
  final String? courseId;

  const WeatherLocation({
    required this.latitude,
    required this.longitude,
    this.courseId,
  });

  @override
  List<Object?> get props => [latitude, longitude, courseId];
}

/// Repository interface for weather data.
///
/// Provides:
/// - Fresh weather from API (online)
/// - Cached weather from SQLite (offline)
/// - Stream of cached weather updates
abstract class WeatherRepository {
  /// Fetch fresh weather for a location from the API.
  ///
  /// Returns a [WeatherResult] with either a fresh [WeatherSnapshot] or a [WeatherError].
  /// On success, caches the snapshot for offline use.
  Future<WeatherResult> getWeather(WeatherLocation location);

  /// Get cached weather for a course (offline fallback).
  ///
  /// Returns null if no cached snapshot exists for the course.
  Future<WeatherSnapshot?> getCachedWeather(String courseId);

  /// Cache a weather snapshot for a course.
  Future<void> cacheWeather(String courseId, WeatherSnapshot snapshot);

  /// Watch cached weather for a course as a stream.
  ///
  /// Emits the current cached snapshot immediately (if any), then on each change.
  /// Completes when the subscription is cancelled.
  Stream<WeatherSnapshot?> watchCachedWeather(String courseId);

  /// Delete cached weather for a course.
  Future<void> clearCache(String courseId);

  /// Refresh cached weather if stale (older than [maxAge]).
  ///
  /// Returns the refreshed snapshot, or the cached one if refresh fails.
  /// Does not update cache if refresh fails.
  Future<WeatherResult> refreshIfStale(
    String courseId,
    WeatherLocation location, {
    Duration maxAge = const Duration(minutes: 30),
  });
}
