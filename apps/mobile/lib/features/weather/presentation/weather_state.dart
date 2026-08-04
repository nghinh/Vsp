// Weather State — VSP Mobile App
//
// Story 7.1 Wave 2: BLoC States
// Per slice plan §2.5:
// - WeatherInitial, WeatherLoading, WeatherLoaded, WeatherStale, WeatherError
// - Handles offline → return cached with stale flag

import 'package:equatable/equatable.dart';

import '../../../domain/models/weather_snapshot.dart';

/// Base state for weather BLoC.
abstract class WeatherState extends Equatable {
  const WeatherState();
}

/// Initial state — no weather loaded yet.
class WeatherInitial extends WeatherState {
  const WeatherInitial();

  @override
  List<Object?> get props => const [];
}

/// Loading state — fetching weather.
class WeatherLoading extends WeatherState {
  const WeatherLoading();

  @override
  List<Object?> get props => const [];
}

/// Weather loaded successfully (fresh).
class WeatherLoaded extends WeatherState {
  final WeatherSnapshot snapshot;
  final bool fromCache;

  const WeatherLoaded({required this.snapshot, this.fromCache = false});

  @override
  List<Object?> get props => [snapshot, fromCache];
}

/// Weather loaded but is stale (served from stale cache or outdated).
class WeatherStale extends WeatherState {
  final WeatherSnapshot snapshot;
  final String reason;

  const WeatherStale({required this.snapshot, required this.reason});

  @override
  List<Object?> get props => [snapshot, reason];
}

/// Weather error — could not load weather.
class WeatherError extends WeatherState {
  final String code;
  final String message;
  final WeatherSnapshot? lastCached;

  const WeatherError({
    required this.code,
    required this.message,
    this.lastCached,
  });

  @override
  List<Object?> get props => [code, message, lastCached];
}
