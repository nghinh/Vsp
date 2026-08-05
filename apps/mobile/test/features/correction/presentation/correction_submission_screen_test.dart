// CorrectionSubmissionScreen widget tests — VSP Mobile App
//
// The screen is how a golfer reports that a hole's geometry is wrong, so these
// tests pin the two things that make the report usable: a layer must be chosen,
// and the position it is filed at must be good enough to act on.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/repositories/course_correction_repository.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';
import 'package:vsp_mobile/features/correction/domain/geometry_layer.dart';
import 'package:vsp_mobile/features/correction/presentation/correction_submission_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService(this.fakeLocation);

  QualifiedLocation? fakeLocation;

  @override
  Stream<QualifiedLocation> get locationStream => const Stream.empty();

  @override
  QualifiedLocation? get lastLocation => fakeLocation;

  @override
  Future<QualifiedLocation> getCurrentLocation() async =>
      fakeLocation ?? QualifiedLocation.unavailable();

  @override
  void start() {}

  @override
  void stop() {}

  @override
  Future<bool> isLocationAvailable() async => fakeLocation != null;

  @override
  Duration get stationaryInterval => const Duration(seconds: 30);

  @override
  Duration get activeInterval => const Duration(seconds: 5);

  @override
  void dispose() {}
}

class _RecordingRepository implements CourseCorrectionRepository {
  CourseCorrection? submitted;

  @override
  Future<({CourseCorrection correction, SyncEvent syncEvent})> submitCorrection(
    CourseCorrection correction,
  ) async {
    submitted = correction;
    return (
      correction: correction,
      syncEvent: SyncEvent.forCorrection(
        correctionId: correction.id,
        correctionPayload: correction.toJson(),
      ),
    );
  }

  @override
  Future<List<CourseCorrection>> getCorrectionsByState(
    CorrectionSyncState state,
  ) async => const [];

  @override
  Future<List<CourseCorrection>> getCorrectionsForCourse(String courseId) async =>
      const [];

  @override
  Future<CourseCorrection?> getCorrectionById(String id) async => null;

  @override
  Future<void> updateCorrectionSyncState(
    String id,
    CorrectionSyncState state,
  ) async {}

  @override
  Future<void> onSyncComplete(String idempotencyKey) async {}

  @override
  Future<void> onServerStatusUpdate(
    String correctionId,
    CorrectionSyncState state,
  ) async {}
}

void main() {
  QualifiedLocation fix(double accuracy) => QualifiedLocation(
    latitude: 10.8506,
    longitude: 106.7205,
    accuracyMeters: accuracy,
    timestamp: DateTime.now(),
    source: LocationSource.gps,
    isStale: false,
  );

  Widget wrap({
    required _RecordingRepository repository,
    required LocationService locationService,
  }) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CourseCorrectionRepository>.value(value: repository),
        RepositoryProvider<LocationService>.value(value: locationService),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CorrectionSubmissionScreen(courseId: '42', holeId: '4201'),
      ),
    );
  }

  ElevatedButton submitButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('offers every geometry layer a golfer can report', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      wrap(
        repository: repository,
        locationService: _FakeLocationService(fix(4)),
      ),
    );
    await tester.pumpAndSettle();

    for (final layer in GeometryLayer.values) {
      expect(
        find.byKey(ValueKey('correction-layer-${layer.wireValue}')),
        findsOneWidget,
        reason: 'missing chip for ${layer.wireValue}',
      );
    }
  });

  testWidgets('submit stays disabled until a layer is chosen', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      wrap(
        repository: repository,
        locationService: _FakeLocationService(fix(4)),
      ),
    );
    await tester.pumpAndSettle();

    expect(submitButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('correction-layer-green')));
    await tester.pumpAndSettle();

    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('submits the chosen layer with the current GPS position', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      wrap(
        repository: repository,
        locationService: _FakeLocationService(fix(4.5)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('correction-layer-bunker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    final submitted = repository.submitted;
    expect(submitted, isNotNull);
    expect(submitted!.layer, GeometryLayer.bunker);
    expect(submitted.courseId, '42');
    expect(submitted.holeId, '4201');
    expect(submitted.reporterLat, 10.8506);
    expect(submitted.reporterLng, 106.7205);
    expect(submitted.gpsAccuracy, 4.5);
  });

  testWidgets('a fix too coarse to place a feature blocks submission', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      wrap(
        repository: repository,
        // Coarser than the 100 m the API accepts.
        locationService: _FakeLocationService(fix(150)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('correction-layer-green')));
    await tester.pumpAndSettle();

    expect(submitButton(tester).onPressed, isNull);
    expect(repository.submitted, isNull);
  });

  testWidgets('with no GPS fix at all, submission is blocked', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      wrap(
        repository: repository,
        locationService: _FakeLocationService(null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('correction-layer-green')));
    await tester.pumpAndSettle();

    expect(submitButton(tester).onPressed, isNull);
  });
}
