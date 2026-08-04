// Qualified Location — VSP Mobile App
//
// Story 6.1: Acquire and Qualify Location
// AC1: Location includes coordinates, accuracy, age, timestamp, and movement direction.
//
// Represents a GPS fix that has been qualified: it carries accuracy, age,
// heading, source, and staleness so consumers (hole detection, distance calc)
// can trust or reject the fix.
//
// Contract shared with Story 6.2 Wave A interface.

import 'package:equatable/equatable.dart';

/// Source of the location fix.
enum LocationSource {
  /// GPS (satellite) — most accurate when available.
  gps,

  /// Network-based location (cell towers, Wi-Fi) — faster but less accurate.
  network,

  /// Fused location (GPS + network + sensors).
  fused,

  /// Cached last-known location.
  cached,

  /// No location available.
  unavailable,
}

/// A GPS fix with quality metadata attached.
///
/// Immutable once constructed.
///
/// AC1 fields: latitude, longitude (coordinates), accuracyMeters (accuracy),
/// timestamp (age), headingDegrees (movement direction).
///
/// AC2: isLowAccuracy (accuracy > 10m) and isStale (age > threshold) trigger warning.
class QualifiedLocation extends Equatable {
  /// Latitude in decimal degrees (WGS84).
  final double latitude;

  /// Longitude in decimal degrees (WGS84).
  final double longitude;

  /// Horizontal accuracy in meters (1-sigma). Null if unavailable.
  final double? accuracyMeters;

  /// Altitude in meters above WGS84 ellipsoid. Null if unavailable.
  final double? altitudeMeters;

  /// Speed in meters per second. Null if unavailable.
  final double? speedMetersPerSecond;

  /// Heading in degrees clockwise from true North (0–360).
  /// Null if unavailable or speed is too low.
  final double? heading;

  /// Timestamp when this fix was acquired.
  final DateTime timestamp;

  /// Source of this location fix.
  final LocationSource source;

  /// Whether the fix is considered stale (age > threshold).
  /// AC1: age is part of location qualification.
  /// AC2: stale positions trigger warning state.
  final bool isStale;

  const QualifiedLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMetersPerSecond,
    this.heading,
    required this.timestamp,
    required this.source,
    required this.isStale,
  });

  /// Constructs an unavailable location (all fields null/default).
  factory QualifiedLocation.unavailable() {
    return QualifiedLocation(
      latitude: 0,
      longitude: 0,
      accuracyMeters: null,
      timestamp: DateTime.now(),
      source: LocationSource.unavailable,
      isStale: true,
    );
  }

  /// AC2: True when accuracy is above 10m (low accuracy warning trigger).
  bool get isLowAccuracy => (accuracyMeters ?? double.infinity) > 10.0;

  /// True if this location should trigger a warning:
  /// either low accuracy (>10m) or stale.
  bool get hasWarning => isLowAccuracy || isStale;

  /// Human-readable accuracy label.
  String get accuracyLabel {
    final acc = accuracyMeters;
    if (acc == null) return 'Unknown';
    if (acc <= 5) return 'High';
    if (acc <= 10) return 'Good';
    if (acc <= 20) return 'Moderate';
    if (acc <= 50) return 'Low';
    return 'Poor';
  }

  /// Age of this fix in seconds.
  int get ageSeconds {
    return DateTime.now().difference(timestamp).inSeconds;
  }

  /// AC2: Whether this location is accurate enough for auto-hole detection.
  /// True when accuracy <= 10m.
  bool get isAccurateForDetection => !isLowAccuracy;

  /// AC2: Whether this location is usable for auto-hole detection.
  /// True when not stale AND accurate enough.
  bool get isUsableForDetection => !isStale && !isLowAccuracy;

  /// Copy with updated fields.
  QualifiedLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    double? altitudeMeters,
    double? speedMetersPerSecond,
    double? heading,
    DateTime? timestamp,
    LocationSource? source,
    bool? isStale,
  }) {
    return QualifiedLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      speedMetersPerSecond: speedMetersPerSecond ?? this.speedMetersPerSecond,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      isStale: isStale ?? this.isStale,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'altitudeMeters': altitudeMeters,
      'speedMetersPerSecond': speedMetersPerSecond,
      'heading': heading,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'source': source.name,
      'isStale': isStale,
    };
  }

  /// Deserialize from JSON.
  factory QualifiedLocation.fromJson(Map<String, dynamic> json) {
    return QualifiedLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
      speedMetersPerSecond: (json['speedMetersPerSecond'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: LocationSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => LocationSource.gps,
      ),
      isStale: json['isStale'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    accuracyMeters,
    altitudeMeters,
    speedMetersPerSecond,
    heading,
    timestamp,
    source,
    isStale,
  ];
}
