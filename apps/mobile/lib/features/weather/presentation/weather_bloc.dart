// WeatherBloc — VSP Mobile App
//
// Story 7.1 Wave 2: BLoC
// Per slice plan §2.5 — LoadWeather, RefreshWeather, StartWatchingCache.
//
// Handles:
// - Online: fetch fresh from API, cache result
// - Offline: return cached with stale flag
// - Stale detection: compare expiresAt with current time

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/weather_error.dart' hide WeatherError;
import '../../../domain/models/weather_snapshot.dart';
import '../../../domain/repositories/weather_repository.dart';
import 'weather_event.dart';
import 'weather_state.dart';

/// BLoC for weather data management.
class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final WeatherRepository _repository;

  /// Stream subscription for cache watching.
  StreamSubscription<WeatherSnapshot?>? _cacheSubscription;

  WeatherBloc({required WeatherRepository repository})
    : _repository = repository,
      super(const WeatherInitial()) {
    on<LoadWeather>(_onLoadWeather);
    on<RefreshWeather>(_onRefreshWeather);
    on<StartWatchingCache>(_onStartWatchingCache);
    on<CachedWeatherUpdated>(_onCachedWeatherUpdated);
    on<StopWatchingCache>(_onStopWatchingCache);
  }

  @override
  Future<void> close() {
    _cacheSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadWeather(
    LoadWeather event,
    Emitter<WeatherState> emit,
  ) async {
    emit(const WeatherLoading());

    final location = WeatherLocation(
      latitude: event.latitude,
      longitude: event.longitude,
      courseId: event.courseId,
    );

    final result = await _repository.getWeather(location);

    if (result.isOk) {
      final snapshot = result.value;
      _emitForSnapshot(snapshot, emit);
    } else {
      final error = result.failure;
      final lastCached = await _repository.getCachedWeather(event.courseId);
      emit(
        WeatherError(
          code: error.code.name,
          message: error.message,
          lastCached: lastCached,
        ),
      );
    }
  }

  Future<void> _onRefreshWeather(
    RefreshWeather event,
    Emitter<WeatherState> emit,
  ) async {
    // Force refresh: clear cache first, then fetch
    await _repository.clearCache(event.courseId);

    final location = WeatherLocation(
      latitude: event.latitude,
      longitude: event.longitude,
      courseId: event.courseId,
    );

    final result = await _repository.getWeather(location);

    if (result.isOk) {
      final snapshot = result.value;
      _emitForSnapshot(snapshot, emit);
    } else {
      final error = result.failure;
      emit(WeatherError(code: error.code.name, message: error.message));
    }
  }

  Future<void> _onStartWatchingCache(
    StartWatchingCache event,
    Emitter<WeatherState> emit,
  ) async {
    _cacheSubscription?.cancel();
    _cacheSubscription = _repository.watchCachedWeather(event.courseId).listen((
      snapshot,
    ) {
      if (snapshot != null) {
        add(CachedWeatherUpdated(snapshot: snapshot));
      }
    });
  }

  void _onCachedWeatherUpdated(
    CachedWeatherUpdated event,
    Emitter<WeatherState> emit,
  ) {
    _emitForSnapshot(event.snapshot, emit);
  }

  Future<void> _onStopWatchingCache(
    StopWatchingCache event,
    Emitter<WeatherState> emit,
  ) async {
    _cacheSubscription?.cancel();
    _cacheSubscription = null;
  }

  void _emitForSnapshot(WeatherSnapshot snapshot, Emitter<WeatherState> emit) {
    switch (snapshot.freshness) {
      case DataFreshness.fresh:
        emit(WeatherLoaded(snapshot: snapshot));
        break;
      case DataFreshness.stale:
        emit(
          WeatherStale(
            snapshot: snapshot,
            reason:
                'Weather data may be outdated. Last updated ${snapshot.relativeTimeString}.',
          ),
        );
        break;
      case DataFreshness.expired:
        emit(
          WeatherStale(
            snapshot: snapshot,
            reason: 'Weather data has expired. Please refresh when online.',
          ),
        );
        break;
    }
  }
}
