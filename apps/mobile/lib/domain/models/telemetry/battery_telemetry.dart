// BatteryTelemetry — VSP Mobile App
//
// Domain model for battery consumption telemetry recorded during a live round.
// Supports 18-hole battery target validation per NFR4.
//
// Story 6.6 — Slice A: Telemetry Domain Models

import 'package:equatable/equatable.dart';

import 'battery_telemetry_dto.dart';

/// A battery telemetry record captured during a live round.
class BatteryTelemetry extends Equatable {
  /// Unique identifier (UUID string).
  final String id;

  /// Parent round identifier.
  final String roundId;

  /// UTC timestamp of this battery sample.
  final DateTime recordedAt;

  /// Battery level (0.0–1.0).
  final double batteryLevel;

  /// Current battery state.
  final BatteryStateDto batteryState;

  /// Battery temperature in Celsius.
  final double? temperatureCelsius;

  /// Estimated remaining playing time in seconds.
  final int? estimatedRemainingSeconds;

  /// Number of holes completed at recording time.
  final int holesCompleted;

  /// Number of holes remaining.
  final int holesRemaining;

  /// GPS polling frequency in Hz.
  final double? gpsPollingFrequencyHz;

  /// Whether battery saver mode was active.
  final bool batterySaverActive;

  /// Screen state string (e.g., "on", "off", "dimmed").
  final String? screenState;

  /// Whether app was in foreground at recording time.
  final bool appInForeground;

  const BatteryTelemetry({
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

  /// Total holes in a standard round.
  static const int standardRoundHoles = 18;

  /// Progress through the round as a fraction (0.0–1.0).
  double get roundProgress {
    final total = holesCompleted + holesRemaining;
    if (total == 0) return 0.0;
    return holesCompleted / total;
  }

  /// Battery consumption rate as fraction per hole (0.0–1.0 per hole).
  /// Null if no meaningful consumption has occurred yet.
  double? consumptionRatePerHole() {
    if (holesCompleted == 0) return null;
    return (1.0 - batteryLevel) / holesCompleted;
  }

  /// Estimated battery level at end of round based on current consumption rate.
  /// Null if consumption rate cannot be determined.
  double? estimatedEndOfRoundBattery() {
    final rate = consumptionRatePerHole();
    if (rate == null) return null;
    final remaining = standardRoundHoles - holesCompleted;
    return batteryLevel - (rate * remaining);
  }

  /// Validates fields and returns a list of errors (empty = valid).
  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('id must not be empty');
    if (roundId.isEmpty) errors.add('roundId must not be empty');
    if (batteryLevel < 0 || batteryLevel > 1) {
      errors.add('batteryLevel must be in range [0, 1]');
    }
    if (holesCompleted < 0) errors.add('holesCompleted must be non-negative');
    if (holesRemaining < 0) errors.add('holesRemaining must be non-negative');
    return errors;
  }

  bool get isValid => validate().isEmpty;

  /// Convert to DTO for API serialization.
  BatteryTelemetryDto toDto() => BatteryTelemetryDto(
    id: id,
    roundId: roundId,
    recordedAt: recordedAt,
    batteryLevel: batteryLevel,
    batteryState: batteryState,
    temperatureCelsius: temperatureCelsius,
    estimatedRemainingSeconds: estimatedRemainingSeconds,
    holesCompleted: holesCompleted,
    holesRemaining: holesRemaining,
    gpsPollingFrequencyHz: gpsPollingFrequencyHz,
    batterySaverActive: batterySaverActive,
    screenState: screenState,
    appInForeground: appInForeground,
  );

  /// Reconstruct from DTO.
  factory BatteryTelemetry.fromDto(BatteryTelemetryDto dto) {
    return BatteryTelemetry(
      id: dto.id,
      roundId: dto.roundId,
      recordedAt: dto.recordedAt,
      batteryLevel: dto.batteryLevel,
      batteryState: dto.batteryState,
      temperatureCelsius: dto.temperatureCelsius,
      estimatedRemainingSeconds: dto.estimatedRemainingSeconds,
      holesCompleted: dto.holesCompleted,
      holesRemaining: dto.holesRemaining,
      gpsPollingFrequencyHz: dto.gpsPollingFrequencyHz,
      batterySaverActive: dto.batterySaverActive,
      screenState: dto.screenState,
      appInForeground: dto.appInForeground,
    );
  }

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() => {
    'id': id,
    'round_id': roundId,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'battery_level': batteryLevel,
    'battery_state': batteryState.name,
    'temperature_celsius': temperatureCelsius,
    'estimated_remaining_seconds': estimatedRemainingSeconds,
    'holes_completed': holesCompleted,
    'holes_remaining': holesRemaining,
    'gps_polling_frequency_hz': gpsPollingFrequencyHz,
    'battery_saver_active': batterySaverActive ? 1 : 0,
    'screen_state': screenState,
    'app_in_foreground': appInForeground ? 1 : 0,
  };

  /// Reconstruct from a SQLite row.
  factory BatteryTelemetry.fromMap(Map<String, dynamic> map) {
    return BatteryTelemetry(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      batteryLevel: (map['battery_level'] as num).toDouble(),
      batteryState: BatteryStateDto.fromString(
        map['battery_state'] as String? ?? 'unknown',
      ),
      temperatureCelsius: (map['temperature_celsius'] as num?)?.toDouble(),
      estimatedRemainingSeconds: (map['estimated_remaining_seconds'] as num?)?.toInt(),
      holesCompleted: (map['holes_completed'] as num?)?.toInt() ?? 0,
      holesRemaining: (map['holes_remaining'] as num?)?.toInt() ?? 18,
      gpsPollingFrequencyHz: (map['gps_polling_frequency_hz'] as num?)?.toDouble(),
      batterySaverActive: ((map['battery_saver_active'] as num).toInt()) == 1,
      screenState: map['screen_state'] as String?,
      appInForeground: ((map['app_in_foreground'] as num).toInt()) == 1,
    );
  }

  /// Copy with updated fields.
  BatteryTelemetry copyWith({
    String? id,
    String? roundId,
    DateTime? recordedAt,
    double? batteryLevel,
    BatteryStateDto? batteryState,
    double? temperatureCelsius,
    int? estimatedRemainingSeconds,
    int? holesCompleted,
    int? holesRemaining,
    double? gpsPollingFrequencyHz,
    bool? batterySaverActive,
    String? screenState,
    bool? appInForeground,
  }) {
    return BatteryTelemetry(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      recordedAt: recordedAt ?? this.recordedAt,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryState: batteryState ?? this.batteryState,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      estimatedRemainingSeconds:
          estimatedRemainingSeconds ?? this.estimatedRemainingSeconds,
      holesCompleted: holesCompleted ?? this.holesCompleted,
      holesRemaining: holesRemaining ?? this.holesRemaining,
      gpsPollingFrequencyHz:
          gpsPollingFrequencyHz ?? this.gpsPollingFrequencyHz,
      batterySaverActive: batterySaverActive ?? this.batterySaverActive,
      screenState: screenState ?? this.screenState,
      appInForeground: appInForeground ?? this.appInForeground,
    );
  }

  @override
  List<Object?> get props => [
    id,
    roundId,
    recordedAt,
    batteryLevel,
    batteryState,
    temperatureCelsius,
    estimatedRemainingSeconds,
    holesCompleted,
    holesRemaining,
    gpsPollingFrequencyHz,
    batterySaverActive,
    screenState,
    appInForeground,
  ];
}
