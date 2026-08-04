// Location State — VSP Mobile App
//
// Story 6.1: Acquire and Qualify Location
//
// BLoC/Cubit state for location stream.
// Tracks current QualifiedLocation, any active warning, and service status.

import 'package:equatable/equatable.dart';

import '../../domain/models/location_quality.dart';
import '../../domain/models/qualified_location.dart';

/// Possible location service states.
enum LocationServiceStatus {
  /// Service has not been started yet.
  idle,

  /// Service is actively acquiring location.
  active,

  /// Service is stopped (round ended or manually stopped).
  stopped,

  /// Location permission denied or service disabled.
  unavailable,
}

/// State for the location cubit.
///
/// Combines:
/// - [status]: service lifecycle
/// - [currentLocation]: latest qualified location (may be unavailable)
/// - [warning]: active warning if hasWarning is true, null otherwise
/// - [lastGoodLocation]: last location with hasWarning=false (for fallback)
class LocationState extends Equatable {
  /// Current service lifecycle status.
  final LocationServiceStatus status;

  /// Latest qualified location (may be unavailable or have a warning).
  final QualifiedLocation? currentLocation;

  /// Active warning, if any (null when hasWarning=false).
  final LocationWarning? warning;

  /// Last location known to be good (hasWarning=false).
  /// Used as fallback when current location has a warning.
  final QualifiedLocation? lastGoodLocation;

  const LocationState({
    required this.status,
    this.currentLocation,
    this.warning,
    this.lastGoodLocation,
  });

  /// Initial idle state.
  factory LocationState.initial() {
    return const LocationState(status: LocationServiceStatus.idle);
  }

  /// Convenience getters for UI.
  bool get isActive => status == LocationServiceStatus.active;
  bool get isIdle => status == LocationServiceStatus.idle;
  bool get isStopped => status == LocationServiceStatus.stopped;
  bool get isUnavailable => status == LocationServiceStatus.unavailable;

  /// True if current location has a warning (AC2: accuracy>10m or stale).
  bool get hasWarning => currentLocation?.hasWarning ?? false;

  /// Current GPS quality level.
  LocationQuality get quality {
    if (status == LocationServiceStatus.unavailable ||
        status == LocationServiceStatus.idle) {
      return LocationQuality.unavailable;
    }
    final loc = currentLocation;
    if (loc == null) return LocationQuality.unavailable;
    if (loc.isStale) return LocationQuality.stale;
    if (loc.isLowAccuracy) return LocationQuality.lowAccuracy;
    return LocationQuality.ready;
  }

  /// Copy with updated fields.
  LocationState copyWith({
    LocationServiceStatus? status,
    QualifiedLocation? currentLocation,
    LocationWarning? warning,
    QualifiedLocation? lastGoodLocation,
  }) {
    return LocationState(
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      warning: warning,
      lastGoodLocation: lastGoodLocation ?? this.lastGoodLocation,
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentLocation,
    warning,
    lastGoodLocation,
  ];
}
