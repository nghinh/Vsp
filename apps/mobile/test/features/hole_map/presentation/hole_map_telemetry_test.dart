// Tests that the round's telemetry recorder is actually connected.
//
// This is the failure mode Story 6.6 already had once. The telemetry models,
// the DAO and the repository were all written and all correct, and nothing in
// the app ever constructed them — so the acceptance criterion "GPS/map latency
// telemetry is recorded" read as satisfied while a round recorded nothing.
//
// A recorder that works and is wired to nothing is the same as no recorder, so
// these tests drive the bloc and the round screen rather than the recorder, and
// assert on what came out the other end.

import 'dart:async';

import 'package:course_package/course_package.dart' hide AccuracyClass;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/services/round_telemetry_recorder.dart';
import 'package:vsp_mobile/data/services/telemetry_service.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/models/telemetry/battery_telemetry.dart';
import 'package:vsp_mobile/domain/models/telemetry/gps_quality_telemetry.dart';
import 'package:vsp_mobile/domain/models/telemetry/map_latency_telemetry.dart';
import 'package:vsp_mobile/domain/services/battery_service.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_bloc.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_event.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';
import 'package:vsp_mobile/features/round/presentation/active_round_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/widgets/score/hole_navigation_bar.dart';

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
  Future<List<GpsQualityTelemetry>> getGpsTelemetry(String r) async => gps;

  @override
  Future<List<GpsQualityTelemetry>> getGpsTelemetryForHole({
    required String roundId,
    required String holeId,
  }) async => gps.where((g) => g.holeId == holeId).toList();

  @override
  Future<List<BatteryTelemetry>> getBatteryTelemetry(String r) async => battery;

  @override
  Future<List<MapLatencyTelemetry>> getMapLatencyTelemetry(String r) async =>
      mapLatency;

  @override
  Future<List<dynamic>> getAllTelemetry(String r) async => [
    ...gps,
    ...battery,
    ...mapLatency,
  ];

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<void> clearRoundTelemetry(String roundId) async {}
}

class _FakeBattery implements BatteryService {
  @override
  Future<BatterySample> read() async => const BatterySample(
    level: 0.75,
    status: BatteryStatus.discharging,
    saverActive: false,
  );
}

/// A location service the test drives by hand.
class _ControlledLocationService implements LocationService {
  final _controller = StreamController<QualifiedLocation>.broadcast();

  @override
  Stream<QualifiedLocation> get locationStream => _controller.stream;

  @override
  QualifiedLocation? get lastLocation => null;

  void emit(QualifiedLocation fix) => _controller.add(fix);

  @override
  Future<QualifiedLocation> getCurrentLocation() async =>
      QualifiedLocation.unavailable();

  @override
  void start() {}

  @override
  void stop() {}

  @override
  Future<bool> isLocationAvailable() async => false;

  @override
  Duration get stationaryInterval => const Duration(seconds: 30);

  @override
  Duration get activeInterval => const Duration(seconds: 5);

  @override
  void dispose() => _controller.close();
}

class _StubRepository implements HoleMapRepository {
  final HoleMapEntity? Function(int holeNumber) build;
  final bool throws;

  _StubRepository(this.build, {this.throws = false});

  @override
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  }) async {
    if (throws) throw StateError('package is corrupt');
    return build(holeNumber);
  }

  @override
  Future<CourseGeometryBundle?> getGeometryBundle({
    required String packageId,
    required String courseId,
  }) async => null;

  @override
  Future<List<CoursePackageManifest>> listPackages() async => const [];

  @override
  // No package on this fake device unless a test says otherwise.
  Future<String?> findPackageIdForCourse(String courseId) async => null;
}

// ─── Builders ───────────────────────────────────────────────────────────────

HoleMapEntity _hole(int holeNumber) => HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: holeNumber,
  par: 4,
  provenance: const HoleDataProvenance(
    accuracyClass: AccuracyClass.classC,
    verificationStatus: VerificationStatus.verified,
  ),
);

RoundTelemetryRecorder _recorder(_RecordingTelemetry store) =>
    RoundTelemetryRecorder(
      roundId: 'round-1',
      totalHoles: 3,
      telemetry: store,
      battery: _FakeBattery(),
    );

void main() {
  group('the hole map bloc', () {
    test('records how long a hole took to load', () async {
      final store = _RecordingTelemetry();
      final bloc = HoleMapBloc(
        repository: _StubRepository(_hole),
        telemetry: _recorder(store),
      );
      addTearDown(bloc.close);

      bloc.add(
        const LoadHoleMap(
          packageId: 'package-1',
          courseId: 'course-1',
          courseName: 'Test course',
          holeNumber: 7,
        ),
      );
      await bloc.stream.firstWhere((s) => s is HoleMapReady);

      final record = store.mapLatency.single;
      expect(record.roundId, 'round-1');
      expect(record.holeId, '7');
      expect(record.servedFromCache, isTrue);
      expect(record.durationMilliseconds, greaterThanOrEqualTo(0));
      expect(record.validate(), isEmpty);
    });

    test('records nothing for a hole with no package to load', () async {
      final store = _RecordingTelemetry();
      final bloc = HoleMapBloc(
        repository: _StubRepository(_hole),
        telemetry: _recorder(store),
      );
      addTearDown(bloc.close);

      bloc.add(
        const LoadHoleMap(
          courseId: 'course-1',
          courseName: 'Test course',
          holeNumber: 7,
        ),
      );
      await bloc.stream.firstWhere((s) => s is HoleMapUnsurveyed);

      // Nothing was loaded. Timing a branch that reads one null would fill the
      // dataset with sub-millisecond rows and flatter the average that the 2 s
      // target is measured against.
      expect(store.mapLatency, isEmpty);
    });

    test('does not record a load that failed as a load time', () async {
      final store = _RecordingTelemetry();
      final bloc = HoleMapBloc(
        repository: _StubRepository(_hole, throws: true),
        telemetry: _recorder(store),
      );
      addTearDown(bloc.close);

      bloc.add(
        const LoadHoleMap(
          packageId: 'package-1',
          courseId: 'course-1',
          courseName: 'Test course',
          holeNumber: 7,
        ),
      );
      await bloc.stream.firstWhere((s) => s is HoleMapError);

      // The duration of an error sitting next to the durations of successes
      // moves the evidence for the target around for reasons that have nothing
      // to do with rendering.
      expect(store.mapLatency, isEmpty);
    });

    test('records the GPS fixes the round is already receiving', () async {
      final store = _RecordingTelemetry();
      final location = _ControlledLocationService();
      addTearDown(location.dispose);

      final bloc = HoleMapBloc(
        repository: _StubRepository(_hole),
        locationService: location,
        telemetry: _recorder(store),
      );
      addTearDown(bloc.close);

      bloc.add(
        const LoadHoleMap(
          packageId: 'package-1',
          courseId: 'course-1',
          courseName: 'Test course',
          holeNumber: 7,
        ),
      );
      await bloc.stream.firstWhere((s) => s is HoleMapReady);

      location.emit(
        QualifiedLocation(
          latitude: 10.7031,
          longitude: 106.7012,
          accuracyMeters: 6.2,
          timestamp: DateTime.utc(2026, 8, 6, 7),
          source: LocationSource.gps,
          isStale: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final record = store.gps.single;
      expect(record.horizontalAccuracyMeters, 6.2);
      // Attributed to the hole the map is on, which is what makes a record
      // comparable against that hole's survey checkpoints.
      expect(record.holeId, '7');
      expect(record.validate(), isEmpty);
    });

    test('a fix with no position is not recorded', () async {
      final store = _RecordingTelemetry();
      final location = _ControlledLocationService();
      addTearDown(location.dispose);

      final bloc = HoleMapBloc(
        repository: _StubRepository(_hole),
        locationService: location,
        telemetry: _recorder(store),
      );
      addTearDown(bloc.close);

      location.emit(QualifiedLocation.unavailable());
      await Future<void>.delayed(Duration.zero);

      expect(store.gps, isEmpty);
    });
  });

  group('a round', () {
    testWidgets('counts battery against holes played, not minutes elapsed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final store = _RecordingTelemetry();
      final recorder = _recorder(store);
      addTearDown(recorder.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ActiveRoundScreen(
            roundId: 'round-1',
            packageId: 'package-1',
            courseId: 'course-1',
            courseName: 'Test course',
            holeNumber: 7,
            locationService: _ControlledLocationService(),
            holeIds: const ['7', '8', '9'],
            playerIds: const ['me'],
            playerNames: const {'me': 'Nghi'},
            holePars: const {'7': 3, '8': 4, '9': 5},
            holeMapRepository: _StubRepository(_hole),
            imageryConfig: SatelliteImageryConfig.unavailable,
            telemetryRecorder: recorder,
          ),
        ),
      );
      await tester.pump();

      // Two holes played.
      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.descendant(
            of: find.byType(HoleNavigationBar),
            matching: find.byIcon(Icons.chevron_right),
          ),
        );
        await tester.pump();
      }
      await recorder.sampleBattery();

      // "Did one charge get us round" is a question about holes. A battery
      // record that does not know how far the golfer has got cannot answer it.
      final record = store.battery.last;
      expect(record.holesCompleted, 2);
      expect(record.holesRemaining, 1);
      expect(record.validate(), isEmpty);
    });
  });
}
