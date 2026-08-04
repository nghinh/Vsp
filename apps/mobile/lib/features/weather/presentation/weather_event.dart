// Weather Events — VSP Mobile App
//
// Story 7.1 Wave 2: BLoC Events
// Per slice plan §2.5 — LoadWeather, RefreshWeather, StartWatchingCache.

import 'package:equatable/equatable.dart';

import '../../../domain/models/weather_snapshot.dart';

/// Base event for weather BLoC.
abstract class WeatherEvent extends Equatable {
  const WeatherEvent();

  @override
  List<Object?> get props => [];
}

/// Load weather for a course.
class LoadWeather extends WeatherEvent {
  /// Course ID for caching.
  final String courseId;

  /// Latitude for API call.
  final double latitude;

  /// Longitude for API call.
  final double longitude;

  const LoadWeather({
    required this.courseId,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [courseId, latitude, longitude];
}

/// Refresh weather (force fetch from API).
class RefreshWeather extends WeatherEvent {
  final String courseId;
  final double latitude;
  final double longitude;

  const RefreshWeather({
    required this.courseId,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [courseId, latitude, longitude];
}

/// Start watching cached weather for a course.
class StartWatchingCache extends WeatherEvent {
  final String courseId;

  const StartWatchingCache({required this.courseId});

  @override
  List<Object?> get props => [courseId];
}

/// Stop watching cached weather.
class CachedWeatherUpdated extends WeatherEvent {
  final WeatherSnapshot snapshot;

  const CachedWeatherUpdated({required this.snapshot});

  @override
  List<Object?> get props => [snapshot];
}

class StopWatchingCache extends WeatherEvent {
  final String courseId;

  const StopWatchingCache({required this.courseId});

  @override
  List<Object?> get props => [courseId];
}
