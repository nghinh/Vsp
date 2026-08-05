// GpsQualityTelemetry — VSP Mobile App
//
// Domain model for GPS quality telemetry recorded during a live round.
// Supports post-round accuracy validation against RTK survey checkpoints.
//
// Constraint: per NFR7 — stale positions (>10 m accuracy) trigger warning;
// accuracy class is stored per PRD §9.4.
//
// Story 6.6 — Slice A: Telemetry Domain Models

import 'package:equatable/equatable.dart';

import 'gps_telemetry_dto.dart';

/// Accuracy class per PRD §9.4.
enum GpsAccuracyClass {
  /// RTK surveyed or course verified — highest accuracy.
  classA,

  /// Licensed professional provider.
  classB,

  /// Verified satellite digitization.
  classC,

  /// Unverified community data.
  classD;

  static GpsAccuracyClass fromFixQuality(GpsFixQualityDto fixQuality) {
    switch (fixQuality) {
      case GpsFixQualityDto.rtkFixed:
      case GpsFixQualityDto.rtkFloat:
        return GpsAccuracyClass.classA;
      case GpsFixQualityDto.threeDimensional:
      case GpsFixQualityDto.twoDimensional:
        return GpsAccuracyClass.classB;
      case GpsFixQualityDto.noFix:
      case GpsFixQualityDto.unknown:
        return GpsAccuracyClass.classD;
    }
  }
}

/// A GPS quality telemetry record captured during a live round.
class GpsQualityTelemetry extends Equatable {
  /// Unique identifier (UUID string).
  final String id;

  /// Parent round identifier.
  final String roundId;

  /// Hole being played when this sample was recorded (null if between holes).
  final String? holeId;

  /// UTC timestamp of this GPS sample.
  final DateTime recordedAt;

  /// WGS84 longitude in decimal degrees.
  final double longitude;

  /// WGS84 latitude in decimal degrees.
  final double latitude;

  /// WGS84 altitude in meters above ellipsoid.
  final double? altitude;

  /// Horizontal accuracy in meters (1-sigma).
  final double horizontalAccuracyMeters;

  /// Vertical accuracy in meters (1-sigma).
  final double? verticalAccuracyMeters;

  /// GPS fix quality classification.
  final GpsFixQualityDto fixQuality;

  /// Ground speed in meters per second.
  final double? speedMetersPerSecond;

  /// Heading in degrees 0–360.
  final double? headingDegrees;

  /// Whether this position is considered stale.
  /// Stale = accuracy > 10 m OR sample > 5 s old.
  final bool isStale;

  /// Battery level at recording time (0.0–1.0).
  final double batteryLevel;

  /// Whether battery saver mode was active.
  final bool batterySaverActive;

  const GpsQualityTelemetry({
    required this.id,
    required this.roundId,
    this.holeId,
    required this.recordedAt,
    required this.longitude,
    required this.latitude,
    this.altitude,
    required this.horizontalAccuracyMeters,
    this.verticalAccuracyMeters,
    required this.fixQuality,
    this.speedMetersPerSecond,
    this.headingDegrees,
    required this.isStale,
    required this.batteryLevel,
    required this.batterySaverActive,
  });

  /// Accuracy class derived from fix quality.
  GpsAccuracyClass get accuracyClass =>
      GpsAccuracyClass.fromFixQuality(fixQuality);

  /// True if horizontal accuracy meets the warning threshold (>10 m).
  bool get isAccuracyWarning => horizontalAccuracyMeters > 10.0;

  /// Validates fields and returns a list of errors (empty = valid).
  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('id must not be empty');
    if (roundId.isEmpty) errors.add('roundId must not be empty');
    if (longitude < -180 || longitude > 180) {
      errors.add('longitude must be in range [-180, 180]');
    }
    if (latitude < -90 || latitude > 90) {
      errors.add('latitude must be in range [-90, 90]');
    }
    if (horizontalAccuracyMeters < 0) {
      errors.add('horizontalAccuracyMeters must be non-negative');
    }
    if (batteryLevel < 0 || batteryLevel > 1) {
      errors.add('batteryLevel must be in range [0, 1]');
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;

  /// Convert to DTO for API serialization.
  GpsTelemetryDto toDto() => GpsTelemetryDto(
    id: id,
    roundId: roundId,
    holeId: holeId,
    recordedAt: recordedAt,
    longitude: longitude,
    latitude: latitude,
    altitude: altitude,
    horizontalAccuracyMeters: horizontalAccuracyMeters,
    verticalAccuracyMeters: verticalAccuracyMeters,
    fixQuality: fixQuality,
    speedMetersPerSecond: speedMetersPerSecond,
    headingDegrees: headingDegrees,
    isStale: isStale,
    batteryLevel: batteryLevel,
    batterySaverActive: batterySaverActive,
  );

  /// Reconstruct from DTO.
  factory GpsQualityTelemetry.fromDto(GpsTelemetryDto dto) {
    return GpsQualityTelemetry(
      id: dto.id,
      roundId: dto.roundId,
      holeId: dto.holeId,
      recordedAt: dto.recordedAt,
      longitude: dto.longitude,
      latitude: dto.latitude,
      altitude: dto.altitude,
      horizontalAccuracyMeters: dto.horizontalAccuracyMeters,
      verticalAccuracyMeters: dto.verticalAccuracyMeters,
      fixQuality: dto.fixQuality,
      speedMetersPerSecond: dto.speedMetersPerSecond,
      headingDegrees: dto.headingDegrees,
      isStale: dto.isStale,
      batteryLevel: dto.batteryLevel,
      batterySaverActive: dto.batterySaverActive,
    );
  }

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() => {
    'id': id,
    'round_id': roundId,
    'hole_id': holeId,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'longitude': longitude,
    'latitude': latitude,
    'altitude': altitude,
    'horizontal_accuracy_meters': horizontalAccuracyMeters,
    'vertical_accuracy_meters': verticalAccuracyMeters,
    'fix_quality': fixQuality.name,
    'speed_meters_per_second': speedMetersPerSecond,
    'heading_degrees': headingDegrees,
    'is_stale': isStale ? 1 : 0,
    'battery_level': batteryLevel,
    'battery_saver_active': batterySaverActive ? 1 : 0,
  };

  /// Reconstruct from a SQLite row.
  factory GpsQualityTelemetry.fromMap(Map<String, dynamic> map) {
    return GpsQualityTelemetry(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      holeId: map['hole_id'] as String?,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      longitude: (map['longitude'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      horizontalAccuracyMeters: (map['horizontal_accuracy_meters'] as num).toDouble(),
      verticalAccuracyMeters: (map['vertical_accuracy_meters'] as num?)?.toDouble(),
      fixQuality: GpsFixQualityDto.fromString(
        map['fix_quality'] as String? ?? 'unknown',
      ),
      speedMetersPerSecond: (map['speed_meters_per_second'] as num?)?.toDouble(),
      headingDegrees: (map['heading_degrees'] as num?)?.toDouble(),
      isStale: (map['is_stale'] as num).toInt() == 1,
      batteryLevel: (map['battery_level'] as num).toDouble(),
      batterySaverActive: (map['battery_saver_active'] as num).toInt() == 1,
    );
  }

  /// Copy with updated fields.
  GpsQualityTelemetry copyWith({
    String? id,
    String? roundId,
    String? holeId,
    DateTime? recordedAt,
    double? longitude,
    double? latitude,
    double? altitude,
    double? horizontalAccuracyMeters,
    double? verticalAccuracyMeters,
    GpsFixQualityDto? fixQuality,
    double? speedMetersPerSecond,
    double? headingDegrees,
    bool? isStale,
    double? batteryLevel,
    bool? batterySaverActive,
  }) {
    return GpsQualityTelemetry(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      holeId: holeId ?? this.holeId,
      recordedAt: recordedAt ?? this.recordedAt,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      altitude: altitude ?? this.altitude,
      horizontalAccuracyMeters:
          horizontalAccuracyMeters ?? this.horizontalAccuracyMeters,
      verticalAccuracyMeters:
          verticalAccuracyMeters ?? this.verticalAccuracyMeters,
      fixQuality: fixQuality ?? this.fixQuality,
      speedMetersPerSecond: speedMetersPerSecond ?? this.speedMetersPerSecond,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      isStale: isStale ?? this.isStale,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batterySaverActive: batterySaverActive ?? this.batterySaverActive,
    );
  }

  @override
  List<Object?> get props => [
    id,
    roundId,
    holeId,
    recordedAt,
    longitude,
    latitude,
    altitude,
    horizontalAccuracyMeters,
    verticalAccuracyMeters,
    fixQuality,
    speedMetersPerSecond,
    headingDegrees,
    isStale,
    batteryLevel,
    batterySaverActive,
  ];
}
