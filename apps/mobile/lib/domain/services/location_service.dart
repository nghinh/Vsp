// Location Service Interface — VSP Mobile App
//
// Story 6.1: Acquire and Qualify Location
// AC2: Accuracy above 10m or stale positions trigger warning state.
// AC3: Battery-aware sampling reduces updates when stationary while preserving
//      active play responsiveness.
//
// Abstract interface for GPS location acquisition with qualification.
// Implementations handle:
// - Device GPS activation and permission
// - QualifiedLocation emission (coordinates, accuracy, age, timestamp, heading)
// - Battery-aware adaptive sampling (frequent when moving, infrequent when still)
// - Staleness detection and warning state

import 'dart:async';

import '../models/qualified_location.dart';

/// Stream of qualified location updates.
///
/// Emits:
/// - QualifiedLocation with hasWarning=false when GPS is good
/// - QualifiedLocation with hasWarning=true when accuracy>10m or stale
/// - QualifiedLocation.unavailable() when GPS is unavailable
///
/// Consumers (hole detection, distance calc) subscribe to this stream
/// and check hasWarning before trusting a fix.
abstract class LocationService {
  /// Stream of qualified location updates.
  ///
  /// The stream respects battery-aware sampling:
  /// - When stationary: updates at [stationaryInterval]
  /// - When moving: updates at [activeInterval]
  /// - When no fix: emits QualifiedLocation.unavailable() and retries
  Stream<QualifiedLocation> get locationStream;

  /// Last known qualified location, if any.
  ///
  /// Null before the first fix is received.
  QualifiedLocation? get lastLocation;

  /// Request a single location fix (not streaming).
  ///
  /// Useful for one-shot needs (e.g., course search nearby).
  /// Returns a qualified location or throws if unavailable.
  Future<QualifiedLocation> getCurrentLocation();

  /// Start the location stream.
  ///
  /// Idempotent — calling while already started is a no-op.
  /// The stream continues in the background until [stop] is called.
  void start();

  /// Stop the location stream and release GPS hardware.
  ///
  /// Call when the round ends or when location is no longer needed.
  void stop();

  /// Check if location services are enabled and permission is granted.
  ///
  /// Returns true only if location is enabled AND permitted.
  Future<bool> isLocationAvailable();

  /// Interval between location updates when the device is stationary (ms).
  /// AC3: battery-aware sampling reduces updates when stationary.
  Duration get stationaryInterval;

  /// Interval between location updates when the device is moving (ms).
  /// AC3: preserving active play responsiveness.
  Duration get activeInterval;

  /// Dispose of resources.
  void dispose();
}
