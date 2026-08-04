// GpsTelemetryDto — VSP Contracts Package
//
// API serialization model for GPS quality telemetry events.
// Mirrors GpsQualityTelemetry domain model in
// apps/mobile/lib/domain/models/telemetry/gps_quality_telemetry.dart.
//
// Story 6.6 — Slice A: Telemetry Domain Models & Contracts

/// GPS fix quality classification enum.
enum GpsFixQualityDto {
  /// Unable to determine GPS quality.
  unknown,

  /// GPS fix is not available.
  noFix,

  /// 2D GPS fix — horizontal only.
  twoDimensional,

  /// 3D GPS fix — horizontal + altitude.
  threeDimensional,

  /// RTK (Real-Time Kinematic) fix — centimeter-level accuracy.
  rtkFixed,

  /// RTK float — less precise than RTK fixed.
  rtkFloat;

  static GpsFixQualityDto fromString(String value) {
    return GpsFixQualityDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => GpsFixQualityDto.unknown,
    );
  }
}

/// GPS telemetry DTO for API request/response serialization.
///
/// Records per-sample GPS quality data captured during a live round
/// to support post-round accuracy validation against RTK checkpoints.
class GpsTelemetryDto {
  /// Unique identifier for this telemetry event (UUID string).
  final String id;

  /// Identifier of the round this telemetry event belongs to.
  final String roundId;

  /// Identifier of the hole the golfer was on when this sample was recorded.
  final String? holeId;

  /// Timestamp when this GPS sample was recorded (UTC).
  final DateTime recordedAt;

  /// WGS84 longitude in decimal degrees.
  final double longitude;

  /// WGS84 latitude in decimal degrees.
  final double latitude;

  /// WGS84 altitude in meters above ellipsoid (null if not available).
  final double? altitude;

  /// Horizontal accuracy estimate in meters (1-sigma).
  final double horizontalAccuracyMeters;

  /// Vertical accuracy estimate in meters (1-sigma, null if altitude unavailable).
  final double? verticalAccuracyMeters;

  /// GPS fix quality classification.
  final GpsFixQualityDto fixQuality;

  /// Speed over ground in meters per second (null if unavailable).
  final double? speedMetersPerSecond;

  /// Course heading in degrees 0–360 (null if unavailable).
  final double? headingDegrees;

  /// Whether the GPS position is considered stale (>10 m accuracy or >5 s old).
  final bool isStale;

  /// Battery level at time of recording (0.0–1.0).
  final double batteryLevel;

  /// Whether battery saver / low-power GPS mode was active.
  final bool batterySaverActive;

  const GpsTelemetryDto({
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

  /// Parse from API response JSON.
  factory GpsTelemetryDto.fromJson(Map<String, dynamic> json) {
    return GpsTelemetryDto(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      holeId: json['holeId'] as String?,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      horizontalAccuracyMeters:
          (json['horizontalAccuracyMeters'] as num).toDouble(),
      verticalAccuracyMeters:
          (json['verticalAccuracyMeters'] as num?)?.toDouble(),
      fixQuality: GpsFixQualityDto.fromString(
        json['fixQuality'] as String? ?? 'unknown',
      ),
      speedMetersPerSecond: (json['speedMetersPerSecond'] as num?)?.toDouble(),
      headingDegrees: (json['headingDegrees'] as num?)?.toDouble(),
      isStale: json['isStale'] as bool? ?? false,
      batteryLevel: (json['batteryLevel'] as num?)?.toDouble() ?? 1.0,
      batterySaverActive: json['batterySaverActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roundId': roundId,
        'holeId': holeId,
        'recordedAt': recordedAt.toIso8601String(),
        'longitude': longitude,
        'latitude': latitude,
        'altitude': altitude,
        'horizontalAccuracyMeters': horizontalAccuracyMeters,
        'verticalAccuracyMeters': verticalAccuracyMeters,
        'fixQuality': fixQuality.name,
        'speedMetersPerSecond': speedMetersPerSecond,
        'headingDegrees': headingDegrees,
        'isStale': isStale,
        'batteryLevel': batteryLevel,
        'batterySaverActive': batterySaverActive,
      };
}
