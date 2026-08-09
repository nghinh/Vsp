// BatteryTelemetryDto — VSP Contracts Package
//
// API serialization model for battery consumption telemetry events.
// Mirrors BatteryTelemetry domain model in
// apps/mobile/lib/domain/models/telemetry/battery_telemetry.dart.
//
// Story 6.6 — Slice A: Telemetry Domain Models & Contracts

/// Battery state at time of recording.
enum BatteryStateDto {
  unknown,
  unplugged,
  charging,
  full,
  discharging;

  static BatteryStateDto fromString(String value) {
    return BatteryStateDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => BatteryStateDto.unknown,
    );
  }
}

/// Battery telemetry DTO for API request/response serialization.
///
/// Records battery state transitions and consumption rates during a live round
/// to support 18-hole battery target validation.
class BatteryTelemetryDto {
  /// Unique identifier for this telemetry event (UUID string).
  final String id;

  /// Identifier of the round this telemetry event belongs to.
  final String roundId;

  /// Timestamp when this battery sample was recorded (UTC).
  final DateTime recordedAt;

  /// Battery level (0.0–1.0).
  final double batteryLevel;

  /// Current battery state.
  final BatteryStateDto batteryState;

  /// Battery temperature in Celsius (null if unavailable).
  final double? temperatureCelsius;

  /// Estimated remaining playing time in seconds (null if unavailable).
  final int? estimatedRemainingSeconds;

  /// Number of holes completed at time of recording.
  final int holesCompleted;

  /// Number of holes remaining.
  final int holesRemaining;

  /// GPS polling frequency setting at time of recording (Hz).
  final double? gpsPollingFrequencyHz;

  /// Whether battery saver mode was active.
  final bool batterySaverActive;

  /// Screen state (on/off/brightness level).
  final String? screenState;

  /// App foreground state at time of recording.
  final bool appInForeground;

  const BatteryTelemetryDto({
    required this.id,
    required this.roundId,
    required this.recordedAt,
    required this.batteryLevel,
    required this.batteryState,
    this.temperatureCelsius,
    this.estimatedRemainingSeconds,
    required this.holesCompleted,
    required this.holesRemaining,
    this.gpsPollingFrequencyHz,
    required this.batterySaverActive,
    this.screenState,
    required this.appInForeground,
  });

  /// Parse from API response JSON.
  factory BatteryTelemetryDto.fromJson(Map<String, dynamic> json) {
    return BatteryTelemetryDto(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      batteryLevel: (json['batteryLevel'] as num).toDouble(),
      batteryState: BatteryStateDto.fromString(
        json['batteryState'] as String? ?? 'unknown',
      ),
      temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble(),
      estimatedRemainingSeconds: (json['estimatedRemainingSeconds'] as num?)
          ?.toInt(),
      holesCompleted: (json['holesCompleted'] as num?)?.toInt() ?? 0,
      holesRemaining: (json['holesRemaining'] as num?)?.toInt() ?? 18,
      gpsPollingFrequencyHz: (json['gpsPollingFrequencyHz'] as num?)
          ?.toDouble(),
      batterySaverActive: json['batterySaverActive'] as bool? ?? false,
      screenState: json['screenState'] as String?,
      appInForeground: json['appInForeground'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roundId': roundId,
    'recordedAt': recordedAt.toIso8601String(),
    'batteryLevel': batteryLevel,
    'batteryState': batteryState.name,
    'temperatureCelsius': temperatureCelsius,
    'estimatedRemainingSeconds': estimatedRemainingSeconds,
    'holesCompleted': holesCompleted,
    'holesRemaining': holesRemaining,
    'gpsPollingFrequencyHz': gpsPollingFrequencyHz,
    'batterySaverActive': batterySaverActive,
    'screenState': screenState,
    'appInForeground': appInForeground,
  };
}
