// Unit tests for the round telemetry recorder.
//
// Story 6.6's third acceptance criterion is that GPS and map latency telemetry
// is recorded during a round. The models, the DAO and the repository for it
// were all written; nothing constructed them, so a round recorded nothing. The
// tests below are about what now gets written, and — as much — about what
// deliberately does not.
//
// Two properties matter more than the rest, because getting them wrong is
// worse than recording nothing at all:
//
//  • Every record written passes the model's own validator. A row that fails
//    it is a row the analysis will either reject or, worse, believe.
//  • A telemetry failure never leaves this class. A golfer on the 14th does
//    not lose their round because a battery plugin or a SQLite insert threw.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/services/round_telemetry_recorder.dart';
import 'package:vsp_mobile/data/services/telemetry_service.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/models/telemetry/battery_telemetry.dart';
import 'package:vsp_mobile/domain/models/telemetry/battery_telemetry_dto.dart';
import 'package:vsp_mobile/domain/models/telemetry/gps_quality_telemetry.dart';
import 'package:vsp_mobile/domain/models/telemetry/gps_telemetry_dto.dart';
import 'package:vsp_mobile/domain/models/telemetry/map_latency_telemetry.dart';
import 'package:vsp_mobile/domain/services/battery_service.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _RecordingTelemetry implements TelemetryService {
  final gps = <GpsQualityTelemetry>[];
  final battery = <BatteryTelemetry>[];
  final mapLatency = <MapLatencyTelemetry>[];

  @override
  Future<void> recordGps(GpsQualityTelemetry g) async => gps.add(g);

  @override
  Future<void> recordBattery(BatteryTelemetry b) async => battery.add(b);

  @override
  Future<void> recordMapLatency(MapLatencyTelemetry m) async =>
      mapLatency.add(m);

  @override
  Future<List<GpsQualityTelemetry>> getGpsTelemetry(String roundId) async =>
      gps;

  @override
  Future<List<GpsQualityTelemetry>> getGpsTelemetryForHole({
    required String roundId,
    required String holeId,
  }) async => gps.where((g) => g.holeId == holeId).toList();

  @override
  Future<List<BatteryTelemetry>> getBatteryTelemetry(String roundId) async =>
      battery;

  @override
  Future<List<MapLatencyTelemetry>> getMapLatencyTelemetry(
    String roundId,
  ) async => mapLatency;

  @override
  Future<List<dynamic>> getAllTelemetry(String roundId) async => [
    ...gps,
    ...battery,
    ...mapLatency,
  ];

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<void> clearRoundTelemetry(String roundId) async {}
}

/// A store that is broken in exactly the way a device's can be.
class _FailingTelemetry extends _RecordingTelemetry {
  @override
  Future<void> recordGps(GpsQualityTelemetry g) async =>
      throw StateError('database is locked');

  @override
  Future<void> recordBattery(BatteryTelemetry b) async =>
      throw StateError('database is locked');

  @override
  Future<void> recordMapLatency(MapLatencyTelemetry m) async =>
      throw StateError('database is locked');
}

class _FakeBattery implements BatteryService {
  BatterySample sample;
  int reads = 0;

  _FakeBattery([
    this.sample = const BatterySample(
      level: 0.8,
      status: BatteryStatus.discharging,
      saverActive: false,
    ),
  ]);

  @override
  Future<BatterySample> read() async {
    reads += 1;
    return sample;
  }
}

// ─── Builders ───────────────────────────────────────────────────────────────

final _t0 = DateTime.utc(2026, 8, 6, 7, 0);

QualifiedLocation _fix({
  DateTime? at,
  double? accuracy = 4.5,
  double? altitude = 12.0,
  bool isStale = false,
  LocationSource source = LocationSource.gps,
}) => QualifiedLocation(
  latitude: 10.7031,
  longitude: 106.7012,
  accuracyMeters: accuracy,
  altitudeMeters: altitude,
  timestamp: at ?? _t0,
  source: source,
  isStale: isStale,
);

RoundTelemetryRecorder _recorder({
  TelemetryService? telemetry,
  BatteryService? battery,
  Duration gpsInterval = const Duration(seconds: 30),
}) => RoundTelemetryRecorder(
  roundId: 'round-1',
  totalHoles: 18,
  telemetry: telemetry,
  battery: battery ?? _FakeBattery(),
  gpsSampleInterval: gpsInterval,
);

void main() {
  group('GPS fixes', () {
    test('records a fix against the hole being played', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store);
      await recorder.sampleBattery();
      recorder.setHole(7);

      expect(await recorder.recordFix(_fix()), isTrue);

      final record = store.gps.single;
      expect(record.roundId, 'round-1');
      expect(record.holeId, '7');
      expect(record.horizontalAccuracyMeters, 4.5);
      expect(record.recordedAt, _t0);
      // The battery level a fix was taken at is the point of recording it
      // alongside: a weak fix on a nearly flat phone is different evidence.
      expect(record.batteryLevel, 0.8);
      expect(record.validate(), isEmpty);
    });

    test(
      'throttles: a second fix inside the interval is not written',
      () async {
        final store = _RecordingTelemetry();
        final recorder = _recorder(telemetry: store);

        expect(await recorder.recordFix(_fix(at: _t0)), isTrue);
        expect(
          await recorder.recordFix(
            _fix(at: _t0.add(const Duration(seconds: 5))),
          ),
          isFalse,
        );
        expect(
          await recorder.recordFix(
            _fix(at: _t0.add(const Duration(seconds: 31))),
          ),
          isTrue,
        );

        // A four-and-a-half-hour round at a fix a second is sixteen thousand
        // rows to store and sync for a measurement a sample every half-minute
        // answers just as well.
        expect(store.gps, hasLength(2));
      },
    );

    test('drops a fix that is not a position', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store);

      // QualifiedLocation.unavailable carries 0,0 — the Gulf of Guinea. A row
      // putting the golfer 10,000 km off the hole is worse than no row.
      expect(
        await recorder.recordFix(QualifiedLocation.unavailable()),
        isFalse,
      );
      expect(store.gps, isEmpty);
    });

    test(
      'a fix that will not state its accuracy is recorded as a bad one',
      () async {
        final store = _RecordingTelemetry();
        final recorder = _recorder(telemetry: store);

        await recorder.recordFix(_fix(accuracy: null, altitude: null));

        final record = store.gps.single;
        expect(record.horizontalAccuracyMeters, 50.0);
        expect(record.fixQuality, GpsFixQualityDto.unknown);
        expect(record.isAccuracyWarning, isTrue);
        expect(record.validate(), isEmpty);
      },
    );

    test('never claims an RTK fix', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store);

      // The RTK classes exist for the survey checkpoints these records get
      // compared against. Nothing in this app can produce one, so nothing here
      // may label itself as one — that would make the comparison meaningless.
      await recorder.recordFix(_fix(accuracy: 0.02));
      expect(store.gps.single.accuracyClass, isNot(GpsAccuracyClass.classA));
    });
  });

  group('map latency', () {
    test('records how long the hole took to become drawable', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store);

      expect(
        await recorder.recordMapLoad(
          holeNumber: 7,
          startedAt: _t0,
          completedAt: _t0.add(const Duration(milliseconds: 1400)),
          servedFromCache: true,
        ),
        isTrue,
      );

      final record = store.mapLatency.single;
      expect(record.holeId, '7');
      expect(record.durationMilliseconds, 1400);
      // PRD §10.2: a cached hole screen loads in under 2 s.
      expect(record.meetsLoadTarget, isTrue);
      expect(record.validate(), isEmpty);
    });

    test('a load slower than the target is recorded as missing it', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store);

      await recorder.recordMapLoad(
        holeNumber: 7,
        startedAt: _t0,
        completedAt: _t0.add(const Duration(milliseconds: 2600)),
        servedFromCache: true,
      );

      expect(store.mapLatency.single.meetsLoadTarget, isFalse);
    });

    test('drops a load that finished before it started', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store);

      // A device clock that stepped backwards mid-load. The model's own
      // validator rejects the row, so it must not be written.
      expect(
        await recorder.recordMapLoad(
          holeNumber: 7,
          startedAt: _t0,
          completedAt: _t0.subtract(const Duration(seconds: 1)),
          servedFromCache: true,
        ),
        isFalse,
      );
      expect(store.mapLatency, isEmpty);
    });
  });

  group('battery', () {
    test('records the charge against holes played and holes left', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store);
      recorder.setHole(8, holesCompleted: 7);

      expect(await recorder.sampleBattery(), isTrue);

      final record = store.battery.single;
      expect(record.batteryLevel, 0.8);
      expect(record.batteryState, BatteryStateDto.discharging);
      // "Does a phone finish 18 holes on one charge" is a question about
      // holes, not minutes.
      expect(record.holesCompleted, 7);
      expect(record.holesRemaining, 11);
      expect(record.validate(), isEmpty);
    });

    test('writes nothing when the device will not say', () async {
      final store = _RecordingTelemetry();
      final battery = _FakeBattery(BatterySample.unknown);
      final recorder = _recorder(telemetry: store, battery: battery);

      // An unknown level is carried as zero, which reads as a flat phone —
      // the one wrong answer worse than no answer for a battery study.
      expect(await recorder.sampleBattery(), isFalse);
      expect(store.battery, isEmpty);
    });

    test('a fix taken before any battery reading still validates', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store);

      await recorder.recordFix(_fix());

      expect(store.gps.single.batteryLevel, 0.0);
      expect(store.gps.single.validate(), isEmpty);
    });

    test('start takes a reading immediately, not on the first tick', () async {
      final store = _RecordingTelemetry();
      final battery = _FakeBattery();
      final recorder = _recorder(telemetry: store, battery: battery);
      addTearDown(recorder.dispose);

      await recorder.start();

      // Without this, every GPS and map record written in the first five
      // minutes of a round would carry an unknown battery level.
      expect(battery.reads, 1);
      expect(store.battery, hasLength(1));
    });
  });

  group('when the telemetry store is broken', () {
    test('nothing thrown reaches the round', () async {
      final recorder = _recorder(telemetry: _FailingTelemetry());

      // Every one of these is a diagnostic. None is worth an exception
      // reaching a golfer halfway down the 14th.
      expect(await recorder.recordFix(_fix()), isFalse);
      expect(
        await recorder.recordMapLoad(
          holeNumber: 7,
          startedAt: _t0,
          completedAt: _t0.add(const Duration(seconds: 1)),
          servedFromCache: true,
        ),
        isFalse,
      );
      expect(await recorder.sampleBattery(), isFalse);
    });
  });

  group('after dispose', () {
    test('records nothing more', () async {
      final store = _RecordingTelemetry();
      final recorder = _recorder(telemetry: store)..dispose();

      expect(await recorder.recordFix(_fix()), isFalse);
      expect(await recorder.sampleBattery(), isFalse);
      expect(store.gps, isEmpty);
      expect(store.battery, isEmpty);
    });
  });
}
