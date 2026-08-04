// Telemetry Repository — VSP Mobile App
//
// SQLite-backed implementation of TelemetryService.
// Uses TelemetryDao for local persistence before sync to backend.
//
// Story 6.6 — Slice B: Telemetry Service Interface + Local Persistence

import '../../domain/models/telemetry/gps_quality_telemetry.dart';
import '../../domain/models/telemetry/battery_telemetry.dart';
import '../../domain/models/telemetry/map_latency_telemetry.dart';
import '../services/telemetry_service.dart';
import '../local/daos/telemetry_dao.dart';

/// SQLite-backed implementation of [TelemetryService].
class TelemetryRepositoryImpl implements TelemetryService {
  final TelemetryDao _dao;

  TelemetryRepositoryImpl({TelemetryDao? dao}) : _dao = dao ?? TelemetryDao();

  @override
  Future<void> recordGps(GpsQualityTelemetry gps) async {
    await _dao.insertGps(gps);
  }

  @override
  Future<void> recordBattery(BatteryTelemetry battery) async {
    await _dao.insertBattery(battery);
  }

  @override
  Future<void> recordMapLatency(MapLatencyTelemetry mapLatency) async {
    await _dao.insertMapLatency(mapLatency);
  }

  @override
  Future<List<GpsQualityTelemetry>> getGpsTelemetry(String roundId) async {
    return _dao.getGpsByRoundId(roundId);
  }

  @override
  Future<List<GpsQualityTelemetry>> getGpsTelemetryForHole({
    required String roundId,
    required String holeId,
  }) async {
    return _dao.getGpsByRoundAndHole(roundId: roundId, holeId: holeId);
  }

  @override
  Future<List<BatteryTelemetry>> getBatteryTelemetry(String roundId) async {
    return _dao.getBatteryByRoundId(roundId);
  }

  @override
  Future<List<MapLatencyTelemetry>> getMapLatencyTelemetry(
    String roundId,
  ) async {
    return _dao.getMapLatencyByRoundId(roundId);
  }

  @override
  Future<List<dynamic>> getAllTelemetry(String roundId) async {
    return _dao.getByRoundId(roundId);
  }

  @override
  Future<void> markSynced(String eventId) async {
    await _dao.markSynced(eventId);
  }

  @override
  Future<void> clearRoundTelemetry(String roundId) async {
    await _dao.deleteByRoundId(roundId);
  }
}
