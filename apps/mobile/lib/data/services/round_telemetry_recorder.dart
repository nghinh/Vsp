// Round Telemetry Recorder — VSP Mobile App
//
// Turns what a round already knows into the telemetry Story 6.6 asks for.
//
// The telemetry stack underneath — models, DAO, repository — was written for
// Story 6.6 and then connected to nothing: `TelemetryRepositoryImpl` was
// constructed nowhere in the app, so a round recorded no GPS quality, no map
// latency and no battery. The acceptance criterion says "GPS/map latency
// telemetry is recorded", and it was not.
//
// Two things this deliberately does not do:
//
//  • It does not turn GPS on. It records fixes the round is already receiving,
//    from whatever already asked for them. Waking the receiver to measure
//    battery drain would change the number being measured.
//  • It never lets a telemetry failure reach the golfer. Every write is
//    swallowed. A round that cannot record how well it went is still a round;
//    one that crashes mid-hole because a DAO insert failed is not.
//
// Sampling is throttled on purpose. A 4½-hour round at one fix a second is
// around sixteen thousand rows to carry, sync and store for a measurement that
// a sample every half-minute answers just as well.

import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/models/qualified_location.dart';
import '../../domain/models/telemetry/battery_telemetry.dart';
import '../../domain/models/telemetry/battery_telemetry_dto.dart';
import '../../domain/models/telemetry/gps_quality_telemetry.dart';
import '../../domain/models/telemetry/gps_telemetry_dto.dart';
import '../../domain/models/telemetry/map_latency_dto.dart';
import '../../domain/models/telemetry/map_latency_telemetry.dart';
import '../../domain/services/battery_service.dart';
import '../repositories/telemetry_repository.dart';
import 'battery_service_impl.dart';
import 'telemetry_service.dart';

/// Records GPS quality, map latency and battery for one round.
class RoundTelemetryRecorder {
  /// Round these records belong to.
  final String roundId;

  /// Holes this round plays, for the battery record's remaining count.
  final int totalHoles;

  final TelemetryService _telemetry;
  final BatteryService _battery;
  final Uuid _uuid;

  /// Shortest gap between two recorded fixes.
  final Duration gpsSampleInterval;

  /// Shortest gap between two battery readings.
  final Duration batterySampleInterval;

  /// Hole the golfer is on, as the scorecard sees it.
  int? _holeNumber;

  /// Holes finished, for the battery record.
  int _holesCompleted = 0;

  /// Timestamp of the last fix written, so the next one can be throttled.
  DateTime? _lastGpsAt;

  /// Last battery reading, reused by the GPS and map records.
  ///
  /// Both carry a battery level, and neither is worth a platform round-trip on
  /// every fix. Refreshed by the battery sampler.
  BatterySample _lastBattery = BatterySample.unknown;

  Timer? _batteryTimer;
  bool _disposed = false;

  RoundTelemetryRecorder({
    required this.roundId,
    required this.totalHoles,
    TelemetryService? telemetry,
    BatteryService? battery,
    Uuid uuid = const Uuid(),
    this.gpsSampleInterval = const Duration(seconds: 30),
    this.batterySampleInterval = const Duration(minutes: 5),
  }) : _telemetry = telemetry ?? TelemetryRepositoryImpl(),
       _battery = battery ?? BatteryServiceImpl(),
       _uuid = uuid;

  /// Last battery reading taken, for callers that want to label a record.
  BatterySample get lastBattery => _lastBattery;

  /// Begins battery sampling and takes the first reading immediately.
  ///
  /// The first reading matters more than the interval: without it every GPS
  /// and map record written before the first tick would carry an unknown
  /// battery level.
  Future<void> start() async {
    if (_disposed) return;
    await sampleBattery();
    _batteryTimer ??= Timer.periodic(
      batterySampleInterval,
      (_) => sampleBattery(),
    );
  }

  /// Records which hole the golfer moved to.
  ///
  /// [holesCompleted] defaults to the holes behind them in the round, which is
  /// what the battery record needs to answer "how far did one charge get us".
  void setHole(int holeNumber, {int? holesCompleted}) {
    _holeNumber = holeNumber;
    _holesCompleted = holesCompleted ?? _holesCompleted;
  }

  /// Records the hole count directly, where the round tracks it separately.
  void setHolesCompleted(int holesCompleted) {
    _holesCompleted = holesCompleted;
  }

  /// Records a GPS fix, subject to [gpsSampleInterval].
  ///
  /// Returns true when the fix was written. A fix with no position is dropped:
  /// [QualifiedLocation.unavailable] carries 0,0, and a row saying the golfer
  /// was in the Gulf of Guinea is worse than no row.
  Future<bool> recordFix(QualifiedLocation fix) async {
    if (_disposed) return false;
    if (fix.source == LocationSource.unavailable) return false;

    final last = _lastGpsAt;
    if (last != null && fix.timestamp.difference(last) < gpsSampleInterval) {
      return false;
    }
    _lastGpsAt = fix.timestamp;

    final record = GpsQualityTelemetry(
      id: _uuid.v4(),
      roundId: roundId,
      holeId: _holeNumber?.toString(),
      recordedAt: fix.timestamp,
      longitude: fix.longitude,
      latitude: fix.latitude,
      altitude: fix.altitudeMeters,
      // A fix that will not say how accurate it is gets recorded as the worst
      // thing it could be, not as perfect.
      horizontalAccuracyMeters: fix.accuracyMeters ?? _unknownAccuracyMeters,
      fixQuality: _fixQuality(fix),
      speedMetersPerSecond: fix.speedMetersPerSecond,
      headingDegrees: fix.heading,
      isStale: fix.isStale,
      batteryLevel: _lastBattery.level,
      batterySaverActive: _lastBattery.saverActive,
    );

    return _write(() => _telemetry.recordGps(record));
  }

  /// Records how long a hole's map took to become usable.
  ///
  /// [servedFromCache] is what separates the two numbers worth having: PRD
  /// §10.2 sets the under-two-seconds target for a *cached* hole screen, and a
  /// first load over a weak connection is not evidence against it.
  Future<bool> recordMapLoad({
    required int holeNumber,
    required DateTime startedAt,
    required DateTime completedAt,
    required bool servedFromCache,
    double zoomLevel = 0,
    MapEventTypeDto eventType = MapEventTypeDto.initialLoad,
  }) async {
    if (_disposed) return false;

    final duration = completedAt.difference(startedAt);
    // A clock that went backwards mid-load would write a negative duration,
    // which the model's own validator rejects. Drop it rather than store it.
    if (duration.isNegative) return false;

    final record = MapLatencyTelemetry(
      id: _uuid.v4(),
      roundId: roundId,
      holeId: holeNumber.toString(),
      eventStartedAt: startedAt,
      eventCompletedAt: completedAt,
      eventType: eventType,
      durationMilliseconds: duration.inMilliseconds,
      servedFromCache: servedFromCache,
      zoomLevel: zoomLevel,
      batteryLevel: _lastBattery.level,
    );

    return _write(() => _telemetry.recordMapLatency(record));
  }

  /// Takes a battery reading and records it.
  ///
  /// Public so the round can take one at a moment that matters — the start of
  /// a round, the end of one — rather than only on the timer.
  Future<bool> sampleBattery() async {
    if (_disposed) return false;

    final sample = await _battery.read();
    _lastBattery = sample;
    // Nothing to learn from a row that says the battery level is unknown, and
    // an unknown level is stored as zero — which reads as a flat phone.
    if (sample.isUnknown) return false;

    final holesCompleted = _holesCompleted.clamp(0, totalHoles);
    final record = BatteryTelemetry(
      id: _uuid.v4(),
      roundId: roundId,
      recordedAt: DateTime.now().toUtc(),
      batteryLevel: sample.level,
      batteryState: _batteryState(sample.status),
      holesCompleted: holesCompleted,
      holesRemaining: totalHoles - holesCompleted,
      batterySaverActive: sample.saverActive,
      appInForeground: true,
    );

    return _write(() => _telemetry.recordBattery(record));
  }

  /// Stops sampling. Safe to call more than once.
  void dispose() {
    _disposed = true;
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  /// Accuracy recorded for a fix that reports none — matches the measuring
  /// tool's own treatment of an accuracy-less fix.
  static const double _unknownAccuracyMeters = 50.0;

  /// Runs a telemetry write and reports whether it landed.
  ///
  /// Telemetry is diagnostic. Nothing it does is worth an exception reaching
  /// a golfer halfway down the 14th.
  Future<bool> _write(Future<void> Function() write) async {
    try {
      await write();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// What the device's own accuracy claim implies about the fix.
  ///
  /// The platform does not hand us a fix type, so this is inferred and
  /// deliberately conservative: nothing here ever claims RTK, because nothing
  /// in this app can produce an RTK fix. The RTK classes exist for the survey
  /// checkpoints these records are compared against.
  static GpsFixQualityDto _fixQuality(QualifiedLocation fix) {
    final accuracy = fix.accuracyMeters;
    if (accuracy == null) return GpsFixQualityDto.unknown;
    if (fix.altitudeMeters != null && accuracy <= 10.0) {
      return GpsFixQualityDto.threeDimensional;
    }
    return GpsFixQualityDto.twoDimensional;
  }

  static BatteryStateDto _batteryState(BatteryStatus status) {
    switch (status) {
      case BatteryStatus.charging:
        return BatteryStateDto.charging;
      case BatteryStatus.discharging:
        return BatteryStateDto.discharging;
      case BatteryStatus.full:
        return BatteryStateDto.full;
      case BatteryStatus.connectedNotCharging:
        return BatteryStateDto.unplugged;
      case BatteryStatus.unknown:
        return BatteryStateDto.unknown;
    }
  }
}
