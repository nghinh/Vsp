// Telemetry Export — VSP Mobile App
//
// Gets Story 6.6's telemetry off the device and into the hands of whoever is
// analysing the pilot.
//
// The field-test protocol already instructs the tester to "export battery
// telemetry via the debug/export panel" and says the export "schema matches
// GpsTelemetryDto, BatteryTelemetryDto and MapLatencyDto"
// (docs/implementation-artifacts/epic-06/field-test-protocol.md §4.3). No such
// panel existed, there is no telemetry endpoint on the API and no upload path
// on the client — so the protocol described a step nobody could take, and a
// tester would have walked eighteen holes to leave the evidence sitting in a
// SQLite file on a phone.
//
// Deliberately a file rather than an upload. A pilot round happens on a golf
// course, which is where the network is worst, and the whole point of the
// exercise is measuring what the device does out there. Writing a file the
// tester can hand over afterwards has no dependency on the thing being tested.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/telemetry/battery_telemetry.dart';
import '../../domain/models/telemetry/gps_quality_telemetry.dart';
import '../../domain/models/telemetry/map_latency_telemetry.dart';
import '../repositories/telemetry_repository.dart';
import 'telemetry_service.dart';

/// What one round's telemetry export contains.
class TelemetryExport {
  /// The round the records belong to.
  final String roundId;

  /// The file written, ready to be shared.
  final File file;

  final int gpsSamples;
  final int batterySamples;
  final int mapLatencySamples;

  const TelemetryExport({
    required this.roundId,
    required this.file,
    required this.gpsSamples,
    required this.batterySamples,
    required this.mapLatencySamples,
  });

  /// True when the round recorded nothing at all.
  ///
  /// Worth surfacing rather than shipping an empty file: an export with no GPS
  /// samples means the round never had a tab open that used the receiver, and
  /// the tester needs to know that before they leave the course, not after.
  bool get isEmpty =>
      gpsSamples == 0 && batterySamples == 0 && mapLatencySamples == 0;

  int get totalSamples => gpsSamples + batterySamples + mapLatencySamples;
}

/// Reads a round's telemetry out of the local store and writes it as JSON.
class TelemetryExportService {
  final TelemetryService _telemetry;

  /// Directory the file is written to. Injectable so tests do not need a
  /// platform channel.
  final Future<Directory> Function() _directory;

  TelemetryExportService({
    TelemetryService? telemetry,
    Future<Directory> Function()? directory,
  }) : _telemetry = telemetry ?? TelemetryRepositoryImpl(),
       _directory = directory ?? getApplicationDocumentsDirectory;

  /// Builds the export for [roundId].
  ///
  /// The JSON shape is the DTOs' own `toJson`, so what lands in the analysis
  /// workspace is the same shape the API would have received had there been an
  /// endpoint — nothing to re-map later when there is one.
  Future<TelemetryExport> export(String roundId) async {
    final gps = await _telemetry.getGpsTelemetry(roundId);
    final battery = await _telemetry.getBatteryTelemetry(roundId);
    final mapLatency = await _telemetry.getMapLatencyTelemetry(roundId);

    final payload = <String, dynamic>{
      'roundId': roundId,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      // Names the shape so an analysis script can fail loudly on a format it
      // does not know, rather than quietly reading the wrong columns.
      'schema': 'vsp.telemetry.round.v1',
      'gps': gps.map((g) => g.toDto().toJson()).toList(),
      'battery': battery.map((b) => b.toDto().toJson()).toList(),
      'mapLatency': mapLatency.map((m) => m.toDto().toJson()).toList(),
    };

    final directory = await _directory();
    final file = File('${directory.path}/vsp-telemetry-$roundId.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    return TelemetryExport(
      roundId: roundId,
      file: file,
      gpsSamples: gps.length,
      batterySamples: battery.length,
      mapLatencySamples: mapLatency.length,
    );
  }

  /// A quick count without writing anything, for showing the tester what a
  /// round holds before they export it.
  Future<TelemetryCounts> counts(String roundId) async {
    final gps = await _telemetry.getGpsTelemetry(roundId);
    final battery = await _telemetry.getBatteryTelemetry(roundId);
    final mapLatency = await _telemetry.getMapLatencyTelemetry(roundId);
    return TelemetryCounts(
      gpsSamples: gps.length,
      batterySamples: battery.length,
      mapLatencySamples: mapLatency.length,
      batteryRange: _batteryRange(battery),
      slowestMapLoadMs: _slowestMapLoad(mapLatency),
      worstAccuracyMeters: _worstAccuracy(gps),
    );
  }

  /// Battery at the start and end of what was recorded, as fractions.
  static (double, double)? _batteryRange(List<BatteryTelemetry> battery) {
    if (battery.isEmpty) return null;
    final sorted = [...battery]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return (sorted.first.batteryLevel, sorted.last.batteryLevel);
  }

  static int? _slowestMapLoad(List<MapLatencyTelemetry> events) {
    if (events.isEmpty) return null;
    return events
        .map((e) => e.durationMilliseconds)
        .reduce((a, b) => a > b ? a : b);
  }

  static double? _worstAccuracy(List<GpsQualityTelemetry> gps) {
    if (gps.isEmpty) return null;
    return gps
        .map((g) => g.horizontalAccuracyMeters)
        .reduce((a, b) => a > b ? a : b);
  }
}

/// A round's telemetry at a glance, for the export panel.
class TelemetryCounts {
  final int gpsSamples;
  final int batterySamples;
  final int mapLatencySamples;

  /// Battery at the first and last reading, 0.0–1.0. Null when none recorded.
  final (double, double)? batteryRange;

  /// The worst map load recorded. PRD §10.2 targets under 2000 ms cached.
  final int? slowestMapLoadMs;

  /// The worst horizontal accuracy recorded. NFR7 warns above 10 m.
  final double? worstAccuracyMeters;

  const TelemetryCounts({
    required this.gpsSamples,
    required this.batterySamples,
    required this.mapLatencySamples,
    this.batteryRange,
    this.slowestMapLoadMs,
    this.worstAccuracyMeters,
  });

  bool get isEmpty =>
      gpsSamples == 0 && batterySamples == 0 && mapLatencySamples == 0;

  /// Battery consumed over what was recorded, as a fraction. Null when there
  /// is nothing to subtract, or when the phone was charging and gained.
  double? get batteryUsed {
    final range = batteryRange;
    if (range == null) return null;
    final used = range.$1 - range.$2;
    return used > 0 ? used : null;
  }
}
