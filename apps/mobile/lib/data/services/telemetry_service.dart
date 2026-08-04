// Telemetry Service — VSP Mobile App
//
// Abstract service for recording GPS quality, battery, and map latency
// telemetry events during a live round. Events are persisted locally
// via TelemetryDao before sync to backend.
//
// Implementations: TelemetryRepository (local SQLite-backed).
// Callers: GPS service (6.1), map rendering (6.3), battery infrastructure.
//
// Story 6.6 — Slice B: Telemetry Service Interface + Local Persistence

import '../../domain/models/telemetry/gps_quality_telemetry.dart';
import '../../domain/models/telemetry/battery_telemetry.dart';
import '../../domain/models/telemetry/map_latency_telemetry.dart';

/// Abstract interface for telemetry recording.
///
/// Implementations are responsible for local persistence before sync.
abstract class TelemetryService {
  /// Records a single GPS quality telemetry event.
  Future<void> recordGps(GpsQualityTelemetry gps);

  /// Records a single battery telemetry event.
  Future<void> recordBattery(BatteryTelemetry battery);

  /// Records a single map latency telemetry event.
  Future<void> recordMapLatency(MapLatencyTelemetry mapLatency);

  /// Retrieves all GPS telemetry records for a round.
  Future<List<GpsQualityTelemetry>> getGpsTelemetry(String roundId);

  /// Retrieves GPS telemetry for a specific hole within a round.
  Future<List<GpsQualityTelemetry>> getGpsTelemetryForHole({
    required String roundId,
    required String holeId,
  });

  /// Retrieves all battery telemetry records for a round.
  Future<List<BatteryTelemetry>> getBatteryTelemetry(String roundId);

  /// Retrieves all map latency telemetry records for a round.
  Future<List<MapLatencyTelemetry>> getMapLatencyTelemetry(String roundId);

  /// Retrieves all telemetry events (any type) for a round.
  Future<List<dynamic>> getAllTelemetry(String roundId);

  /// Marks a telemetry event as synced.
  Future<void> markSynced(String eventId);

  /// Deletes all telemetry data for a round.
  Future<void> clearRoundTelemetry(String roundId);
}
