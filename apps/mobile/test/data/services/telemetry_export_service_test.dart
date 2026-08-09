// Tests for getting the pilot's evidence off the device.
//
// The field-test protocol tells the tester to "export telemetry via the
// debug/export panel" as JSON matching the three DTOs. There was no panel, no
// telemetry endpoint on the API and no upload path on the client — so the
// protocol described a step nobody could take, and a round would have left its
// evidence in a SQLite file on a phone.
//
// The assertion that matters most is the empty one. A tester who walks eighteen
// holes and records nothing has to find that out while still on the course.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/services/telemetry_export_service.dart';
import 'package:vsp_mobile/data/services/telemetry_service.dart';
import 'package:vsp_mobile/domain/models/telemetry/battery_telemetry.dart';
import 'package:vsp_mobile/domain/models/telemetry/battery_telemetry_dto.dart';
import 'package:vsp_mobile/domain/models/telemetry/gps_quality_telemetry.dart';
import 'package:vsp_mobile/domain/models/telemetry/gps_telemetry_dto.dart';
import 'package:vsp_mobile/domain/models/telemetry/map_latency_dto.dart';
import 'package:vsp_mobile/domain/models/telemetry/map_latency_telemetry.dart';

class _StubTelemetry implements TelemetryService {
  final List<GpsQualityTelemetry> gps;
  final List<BatteryTelemetry> battery;
  final List<MapLatencyTelemetry> mapLatency;

  _StubTelemetry({
    this.gps = const [],
    this.battery = const [],
    this.mapLatency = const [],
  });

  @override
  Future<List<GpsQualityTelemetry>> getGpsTelemetry(String roundId) async =>
      gps;

  @override
  Future<List<BatteryTelemetry>> getBatteryTelemetry(String roundId) async =>
      battery;

  @override
  Future<List<MapLatencyTelemetry>> getMapLatencyTelemetry(
    String roundId,
  ) async => mapLatency;

  @override
  Future<List<GpsQualityTelemetry>> getGpsTelemetryForHole({
    required String roundId,
    required String holeId,
  }) async => gps;

  @override
  Future<List<dynamic>> getAllTelemetry(String roundId) async => [
    ...gps,
    ...battery,
    ...mapLatency,
  ];

  @override
  Future<void> recordGps(GpsQualityTelemetry g) async {}

  @override
  Future<void> recordBattery(BatteryTelemetry b) async {}

  @override
  Future<void> recordMapLatency(MapLatencyTelemetry m) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<void> clearRoundTelemetry(String roundId) async {}
}

// ─── Builders ───────────────────────────────────────────────────────────────

GpsQualityTelemetry _gps({double accuracy = 4.0}) => GpsQualityTelemetry(
  id: 'g-$accuracy',
  roundId: 'round-1',
  holeId: '7',
  recordedAt: DateTime.utc(2026, 8, 7, 7),
  longitude: 106.7,
  latitude: 10.7,
  horizontalAccuracyMeters: accuracy,
  fixQuality: GpsFixQualityDto.threeDimensional,
  isStale: false,
  batteryLevel: 0.8,
  batterySaverActive: false,
);

BatteryTelemetry _battery(double level, int minute) => BatteryTelemetry(
  id: 'b-$minute',
  roundId: 'round-1',
  recordedAt: DateTime.utc(2026, 8, 7, 7, minute),
  batteryLevel: level,
  batteryState: BatteryStateDto.discharging,
  holesCompleted: 0,
  holesRemaining: 18,
  batterySaverActive: false,
  appInForeground: true,
);

MapLatencyTelemetry _mapLoad(int ms) => MapLatencyTelemetry(
  id: 'm-$ms',
  roundId: 'round-1',
  holeId: '7',
  eventStartedAt: DateTime.utc(2026, 8, 7, 7),
  eventCompletedAt: DateTime.utc(2026, 8, 7, 7).add(Duration(milliseconds: ms)),
  eventType: MapEventTypeDto.initialLoad,
  durationMilliseconds: ms,
  servedFromCache: true,
  zoomLevel: 17,
  batteryLevel: 0.8,
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vsp-telemetry-export-');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  TelemetryExportService service(_StubTelemetry store) =>
      TelemetryExportService(telemetry: store, directory: () async => tempDir);

  group('the export file', () {
    test('carries the DTO shape the analysis workspace expects', () async {
      final export = await service(
        _StubTelemetry(
          gps: [_gps()],
          battery: [_battery(0.9, 0)],
          mapLatency: [_mapLoad(1400)],
        ),
      ).export('round-1');

      final json =
          jsonDecode(await export.file.readAsString()) as Map<String, dynamic>;

      // The protocol says the schema matches GpsTelemetryDto,
      // BatteryTelemetryDto and MapLatencyDto — the same shape the API would
      // have received, so nothing needs re-mapping when an endpoint exists.
      expect(json['roundId'], 'round-1');
      expect(json['schema'], 'vsp.telemetry.round.v1');
      expect((json['gps'] as List), hasLength(1));
      expect((json['battery'] as List), hasLength(1));
      expect((json['mapLatency'] as List), hasLength(1));
      expect(
        (json['gps'] as List).first,
        containsPair('horizontalAccuracyMeters', 4.0),
      );
    });

    test('names its own schema so a wrong format fails loudly', () async {
      final export = await service(_StubTelemetry(gps: [_gps()])).export('r');
      final json =
          jsonDecode(await export.file.readAsString()) as Map<String, dynamic>;

      // An analysis script reading the wrong columns quietly is how a pilot
      // produces confident conclusions from nothing.
      expect(json['schema'], isNotNull);
      expect(json['exportedAt'], isNotNull);
    });

    test('a round that recorded nothing says so', () async {
      final export = await service(_StubTelemetry()).export('round-empty');

      expect(export.isEmpty, isTrue);
      expect(export.totalSamples, 0);
    });
  });

  group('the summary a tester reads before leaving the course', () {
    test('counts what was recorded', () async {
      final counts = await service(
        _StubTelemetry(
          gps: [_gps(), _gps(accuracy: 6)],
          battery: [_battery(0.9, 0), _battery(0.62, 240)],
          mapLatency: [_mapLoad(900)],
        ),
      ).counts('round-1');

      expect(counts.gpsSamples, 2);
      expect(counts.batterySamples, 2);
      expect(counts.mapLatencySamples, 1);
    });

    test('reports battery used across the round', () async {
      final counts = await service(
        _StubTelemetry(battery: [_battery(0.95, 0), _battery(0.55, 270)]),
      ).counts('round-1');

      // The whole point of Story 6.6's battery half: does a phone finish 18
      // holes on one charge.
      expect(counts.batteryUsed, closeTo(0.40, 1e-9));
    });

    test(
      'a charging phone reports no consumption rather than a negative',
      () async {
        final counts = await service(
          _StubTelemetry(battery: [_battery(0.40, 0), _battery(0.85, 200)]),
        ).counts('round-1');

        // A tester who charged mid-round has not measured a round's drain, and
        // "-45%" in a report is worse than an absent number.
        expect(counts.batteryUsed, isNull);
      },
    );

    test('surfaces the two thresholds the pilot is measuring', () async {
      final counts = await service(
        _StubTelemetry(
          gps: [_gps(accuracy: 3), _gps(accuracy: 14)],
          mapLatency: [_mapLoad(800), _mapLoad(2600)],
        ),
      ).counts('round-1');

      // NFR7 warns above 10 m; PRD §10.2 targets under 2000 ms cached. The
      // worst of each is what decides whether a round passes.
      expect(counts.worstAccuracyMeters, 14);
      expect(counts.slowestMapLoadMs, 2600);
    });

    test('an empty round is flagged, not shown as zeros', () async {
      final counts = await service(_StubTelemetry()).counts('round-1');

      // Telemetry is written from fixes the round already receives, so a round
      // played entirely on the Score tab records no GPS. The tester has to
      // learn that on the course, not a week later.
      expect(counts.isEmpty, isTrue);
      expect(counts.batteryUsed, isNull);
      expect(counts.worstAccuracyMeters, isNull);
    });
  });
}
