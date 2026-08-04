// MapLatencyTelemetry — VSP Mobile App
//
// Domain model for map rendering latency telemetry recorded during a live round.
// Supports map latency validation (cached hole screen <2 s load target per PRD §10.2).
//
// Story 6.6 — Slice A: Telemetry Domain Models

import 'package:equatable/equatable.dart';

import 'map_latency_dto.dart';

/// Performance target for cached hole screen load (milliseconds).
/// PRD §10.2: cached hole screen loads in under 2 seconds.
const int kMapLoadTargetMs = 2000;

/// Performance target for distance updates after location change (milliseconds).
/// PRD §10.2: distance updates within 1 second after location update.
const int kDistanceUpdateTargetMs = 1000;

/// A map latency telemetry record captured during a live round.
class MapLatencyTelemetry extends Equatable {
  /// Unique identifier (UUID string).
  final String id;

  /// Parent round identifier.
  final String roundId;

  /// Hole being rendered.
  final String holeId;

  /// UTC timestamp when render event started.
  final DateTime eventStartedAt;

  /// UTC timestamp when render event completed.
  final DateTime eventCompletedAt;

  /// Type of map rendering event.
  final MapEventTypeDto eventType;

  /// Duration in milliseconds.
  final int durationMilliseconds;

  /// Number of tiles rendered (null for non-tile events).
  final int? tilesRendered;

  /// Number of symbols rendered (null for non-symbol events).
  final int? symbolsRendered;

  /// Whether served from offline cache.
  final bool servedFromCache;

  /// Map zoom level at time of event.
  final double zoomLevel;

  /// Device model string.
  final String? deviceModel;

  /// Battery level at recording time (0.0–1.0).
  final double batteryLevel;

  /// App memory usage in MB.
  final double? memoryUsageMb;

  const MapLatencyTelemetry({
    required this.id,
    required this.roundId,
    required this.holeId,
    required this.eventStartedAt,
    required this.eventCompletedAt,
    required this.eventType,
    required this.durationMilliseconds,
    this.tilesRendered,
    this.symbolsRendered,
    required this.servedFromCache,
    required this.zoomLevel,
    this.deviceModel,
    required this.batteryLevel,
    this.memoryUsageMb,
  });

  /// Duration as a [Duration] object.
  Duration get duration => Duration(milliseconds: durationMilliseconds);

  /// True if this initial-load event meets the cached hole screen target (<2 s).
  bool get meetsLoadTarget =>
      eventType == MapEventTypeDto.initialLoad &&
      durationMilliseconds <= kMapLoadTargetMs;

  /// Validates fields and returns a list of errors (empty = valid).
  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('id must not be empty');
    if (roundId.isEmpty) errors.add('roundId must not be empty');
    if (holeId.isEmpty) errors.add('holeId must not be empty');
    if (durationMilliseconds < 0) {
      errors.add('durationMilliseconds must be non-negative');
    }
    if (zoomLevel < 0) errors.add('zoomLevel must be non-negative');
    if (batteryLevel < 0 || batteryLevel > 1) {
      errors.add('batteryLevel must be in range [0, 1]');
    }
    if (eventCompletedAt.isBefore(eventStartedAt)) {
      errors.add('eventCompletedAt must not be before eventStartedAt');
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;

  /// Convert to DTO for API serialization.
  MapLatencyDto toDto() => MapLatencyDto(
    id: id,
    roundId: roundId,
    holeId: holeId,
    eventStartedAt: eventStartedAt,
    eventCompletedAt: eventCompletedAt,
    eventType: eventType,
    durationMilliseconds: durationMilliseconds,
    tilesRendered: tilesRendered,
    symbolsRendered: symbolsRendered,
    servedFromCache: servedFromCache,
    zoomLevel: zoomLevel,
    deviceModel: deviceModel,
    batteryLevel: batteryLevel,
    memoryUsageMb: memoryUsageMb,
  );

  /// Reconstruct from DTO.
  factory MapLatencyTelemetry.fromDto(MapLatencyDto dto) {
    return MapLatencyTelemetry(
      id: dto.id,
      roundId: dto.roundId,
      holeId: dto.holeId,
      eventStartedAt: dto.eventStartedAt,
      eventCompletedAt: dto.eventCompletedAt,
      eventType: dto.eventType,
      durationMilliseconds: dto.durationMilliseconds,
      tilesRendered: dto.tilesRendered,
      symbolsRendered: dto.symbolsRendered,
      servedFromCache: dto.servedFromCache,
      zoomLevel: dto.zoomLevel,
      deviceModel: dto.deviceModel,
      batteryLevel: dto.batteryLevel,
      memoryUsageMb: dto.memoryUsageMb,
    );
  }

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() => {
    'id': id,
    'round_id': roundId,
    'hole_id': holeId,
    'event_started_at': eventStartedAt.toUtc().toIso8601String(),
    'event_completed_at': eventCompletedAt.toUtc().toIso8601String(),
    'event_type': eventType.name,
    'duration_milliseconds': durationMilliseconds,
    'tiles_rendered': tilesRendered,
    'symbols_rendered': symbolsRendered,
    'served_from_cache': servedFromCache ? 1 : 0,
    'zoom_level': zoomLevel,
    'device_model': deviceModel,
    'battery_level': batteryLevel,
    'memory_usage_mb': memoryUsageMb,
  };

  /// Reconstruct from a SQLite row.
  factory MapLatencyTelemetry.fromMap(Map<String, dynamic> map) {
    return MapLatencyTelemetry(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      holeId: map['hole_id'] as String,
      eventStartedAt: DateTime.parse(map['event_started_at'] as String),
      eventCompletedAt: DateTime.parse(map['event_completed_at'] as String),
      eventType: MapEventTypeDto.fromString(
        map['event_type'] as String? ?? 'initialLoad',
      ),
      durationMilliseconds: map['duration_milliseconds'] as int,
      tilesRendered: map['tiles_rendered'] as int?,
      symbolsRendered: map['symbols_rendered'] as int?,
      servedFromCache: (map['served_from_cache'] as int) == 1,
      zoomLevel: map['zoom_level'] as double,
      deviceModel: map['device_model'] as String?,
      batteryLevel: map['battery_level'] as double,
      memoryUsageMb: map['memory_usage_mb'] as double?,
    );
  }

  /// Copy with updated fields.
  MapLatencyTelemetry copyWith({
    String? id,
    String? roundId,
    String? holeId,
    DateTime? eventStartedAt,
    DateTime? eventCompletedAt,
    MapEventTypeDto? eventType,
    int? durationMilliseconds,
    int? tilesRendered,
    int? symbolsRendered,
    bool? servedFromCache,
    double? zoomLevel,
    String? deviceModel,
    double? batteryLevel,
    double? memoryUsageMb,
  }) {
    return MapLatencyTelemetry(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      holeId: holeId ?? this.holeId,
      eventStartedAt: eventStartedAt ?? this.eventStartedAt,
      eventCompletedAt: eventCompletedAt ?? this.eventCompletedAt,
      eventType: eventType ?? this.eventType,
      durationMilliseconds: durationMilliseconds ?? this.durationMilliseconds,
      tilesRendered: tilesRendered ?? this.tilesRendered,
      symbolsRendered: symbolsRendered ?? this.symbolsRendered,
      servedFromCache: servedFromCache ?? this.servedFromCache,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      deviceModel: deviceModel ?? this.deviceModel,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      memoryUsageMb: memoryUsageMb ?? this.memoryUsageMb,
    );
  }

  @override
  List<Object?> get props => [
    id,
    roundId,
    holeId,
    eventStartedAt,
    eventCompletedAt,
    eventType,
    durationMilliseconds,
    tilesRendered,
    symbolsRendered,
    servedFromCache,
    zoomLevel,
    deviceModel,
    batteryLevel,
    memoryUsageMb,
  ];
}
