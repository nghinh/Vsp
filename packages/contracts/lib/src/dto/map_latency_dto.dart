// MapLatencyDto — VSP Contracts Package
//
// API serialization model for map rendering latency telemetry events.
// Mirrors MapLatencyTelemetry domain model in
// apps/mobile/lib/domain/models/telemetry/map_latency_dto.dart.
//
// Story 6.6 — Slice A: Telemetry Domain Models & Contracts

/// Map rendering event type.
enum MapEventTypeDto {
  /// Initial map load for a hole.
  initialLoad,

  /// Pan or zoom caused a tile re-render.
  panZoomRender,

  /// Tiles fetched and rendered.
  tileRender,

  /// Symbol (marker, pin, target) rendered.
  symbolRender,

  /// Distance overlay rendered.
  overlayRender;

  static MapEventTypeDto fromString(String value) {
    return MapEventTypeDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => MapEventTypeDto.initialLoad,
    );
  }
}

/// Map latency telemetry DTO for API request/response serialization.
///
/// Records map rendering performance metrics during a live round
/// to support map latency validation (cached hole screen <2 s load target).
class MapLatencyDto {
  /// Unique identifier for this telemetry event (UUID string).
  final String id;

  /// Identifier of the round this telemetry event belongs to.
  final String roundId;

  /// Identifier of the hole being rendered.
  final String holeId;

  /// Timestamp when the render event started (UTC).
  final DateTime eventStartedAt;

  /// Timestamp when the render event completed (UTC).
  final DateTime eventCompletedAt;

  /// Type of map rendering event.
  final MapEventTypeDto eventType;

  /// Duration from event start to completion in milliseconds.
  final int durationMilliseconds;

  /// Number of tiles rendered in this event (null for non-tile events).
  final int? tilesRendered;

  /// Number of symbols rendered in this event (null for non-symbol events).
  final int? symbolsRendered;

  /// Whether this event was served from offline cache.
  final bool servedFromCache;

  /// Map zoom level at time of event.
  final double zoomLevel;

  /// Device model identifier (e.g., "iPhone14,5").
  final String? deviceModel;

  /// Battery level at time of recording (0.0–1.0).
  final double batteryLevel;

  /// App memory usage in MB at time of event (null if unavailable).
  final double? memoryUsageMb;

  const MapLatencyDto({
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

  /// Parse from API response JSON.
  factory MapLatencyDto.fromJson(Map<String, dynamic> json) {
    return MapLatencyDto(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      holeId: json['holeId'] as String,
      eventStartedAt: DateTime.parse(json['eventStartedAt'] as String),
      eventCompletedAt: DateTime.parse(json['eventCompletedAt'] as String),
      eventType: MapEventTypeDto.fromString(
        json['eventType'] as String? ?? 'initialLoad',
      ),
      durationMilliseconds: json['durationMilliseconds'] as int,
      tilesRendered: json['tilesRendered'] as int?,
      symbolsRendered: json['symbolsRendered'] as int?,
      servedFromCache: json['servedFromCache'] as bool? ?? false,
      zoomLevel: (json['zoomLevel'] as num).toDouble(),
      deviceModel: json['deviceModel'] as String?,
      batteryLevel: (json['batteryLevel'] as num?)?.toDouble() ?? 1.0,
      memoryUsageMb: (json['memoryUsageMb'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roundId': roundId,
        'holeId': holeId,
        'eventStartedAt': eventStartedAt.toIso8601String(),
        'eventCompletedAt': eventCompletedAt.toIso8601String(),
        'eventType': eventType.name,
        'durationMilliseconds': durationMilliseconds,
        'tilesRendered': tilesRendered,
        'symbolsRendered': symbolsRendered,
        'servedFromCache': servedFromCache,
        'zoomLevel': zoomLevel,
        'deviceModel': deviceModel,
        'batteryLevel': batteryLevel,
        'memoryUsageMb': memoryUsageMb,
      };
}
