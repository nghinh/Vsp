// Location Cubit — VSP Mobile App
//
// Story 6.1: Acquire and Qualify Location
// AC2: Accuracy above 10m or stale positions trigger warning state.
// AC3: Battery-aware sampling reduces updates when stationary while preserving
//      active play responsiveness.
//
// Manages the location stream lifecycle and exposes state to UI widgets.
// Consumers subscribe to the cubit for QualifiedLocation updates with
// automatic warning propagation.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/location_quality.dart';
import '../../domain/models/qualified_location.dart';
import '../../domain/services/location_service.dart';
import 'location_state.dart';

/// Cubit for location stream management.
///
/// Usage:
/// ```dart
/// context.read<LocationCubit>().start();
/// // Subscribe to state stream for UI updates
/// ```
class LocationCubit extends Cubit<LocationState> {
  final LocationService _locationService;
  StreamSubscription<QualifiedLocation>? _subscription;

  LocationCubit({required LocationService locationService})
    : _locationService = locationService,
      super(LocationState.initial());

  /// Start the location stream (AC1: begin acquiring).
  ///
  /// Idempotent — safe to call multiple times.
  Future<void> start() async {
    if (state.status == LocationServiceStatus.active) return;

    // Check availability first.
    final available = await _locationService.isLocationAvailable();
    if (!available) {
      emit(
        state.copyWith(
          status: LocationServiceStatus.unavailable,
          currentLocation: QualifiedLocation.unavailable(),
          warning: LocationWarning.fromQualifiedLocation(
            QualifiedLocation.unavailable(),
          ),
        ),
      );
      return;
    }

    emit(state.copyWith(status: LocationServiceStatus.active));

    // Subscribe to location stream.
    _subscription?.cancel();
    _subscription = _locationService.locationStream.listen(_onLocation);

    // Also start the service.
    _locationService.start();
  }

  /// Stop the location stream and release GPS hardware.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _locationService.stop();
    emit(state.copyWith(status: LocationServiceStatus.stopped));
  }

  /// Request a one-shot location (used for course search nearby).
  Future<QualifiedLocation> getCurrentLocation() {
    return _locationService.getCurrentLocation();
  }

  @override
  Future<void> close() {
    stop();
    _locationService.dispose();
    return super.close();
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  void _onLocation(QualifiedLocation location) {
    final warning = location.hasWarning
        ? LocationWarning.fromQualifiedLocation(location)
        : null;

    // Track last good location for fallback.
    QualifiedLocation? lastGood = state.lastGoodLocation;
    if (!location.hasWarning && location.source != LocationSource.unavailable) {
      lastGood = location;
    }

    emit(
      state.copyWith(
        status: LocationServiceStatus.active,
        currentLocation: location,
        warning: warning,
        lastGoodLocation: lastGood,
      ),
    );
  }
}
