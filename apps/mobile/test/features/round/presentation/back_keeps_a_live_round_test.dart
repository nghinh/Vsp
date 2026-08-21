// A live round survives the back gesture.
//
// The Score tab hosts the scorecard's own Scaffold, so its AppBar drew the
// route's back arrow directly above the hole number. One tap — or an iOS edge
// swipe — and the golfer was out of the round they were playing, mid-hole,
// with nothing asked and nothing said. Reported from the course on hole 3.
//
// Leaving is still allowed: the scores are saved per hole and the round is
// resumable. What is not allowed is leaving by accident.

import 'package:course_package/course_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/round/presentation/active_round_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _FakeLocationService implements LocationService {
  @override
  Stream<QualifiedLocation> get locationStream => const Stream.empty();

  @override
  QualifiedLocation? get lastLocation => null;

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
  void dispose() {}
}

class _EmptyHoleMapRepository implements HoleMapRepository {
  @override
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  }) async => null;

  @override
  Future<CourseGeometryBundle?> getGeometryBundle({
    required String packageId,
    required String courseId,
  }) async => null;

  @override
  Future<List<CoursePackageManifest>> listPackages() async => const [];

  @override
  Future<String?> findPackageIdForCourse(String courseId) async => null;
}

// ─── Harness ────────────────────────────────────────────────────────────────

const _homeMarker = 'Home';

/// Starts a round the way the app does — pushed onto the screen behind it, so
/// the back arrow the golfer taps is a real one.
Future<AppLocalizations> _startRound(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActiveRoundScreen(
                    roundId: 'round-1',
                    packageId: 'package-1',
                    courseId: 'course-1',
                    courseName: 'Test course',
                    holeNumber: 3,
                    par: 4,
                    locationService: _FakeLocationService(),
                    holeIds: const ['1', '2', '3'],
                    playerIds: const ['me'],
                    playerNames: const {'me': 'Nghi'},
                    holePars: const {'1': 4, '2': 4, '3': 4},
                    holeMapRepository: _EmptyHoleMapRepository(),
                    imageryConfig: SatelliteImageryConfig.unavailable,
                  ),
                ),
              ),
              child: const Text(_homeMarker),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text(_homeMarker));
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('vi'));
}

/// The back arrow the scorecard's own AppBar puts on the round.
Finder _backArrow() => find.byType(BackButton);

void main() {
  group('the back gesture on a live round', () {
    testWidgets('asks before it takes the golfer out', (tester) async {
      final l10n = await _startRound(tester);

      expect(_backArrow(), findsOneWidget, reason: 'the arrow golfers tap');
      await tester.tap(_backArrow());
      await tester.pumpAndSettle();

      // Still in the round, with the question on top of it.
      expect(find.text(l10n.activeRoundLeaveTitle), findsOneWidget);
      expect(find.byType(ActiveRoundScreen), findsOneWidget);
      expect(find.text(_homeMarker), findsNothing);
    });

    testWidgets('keeps playing when the golfer says so', (tester) async {
      final l10n = await _startRound(tester);

      await tester.tap(_backArrow());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('active_round_stay')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.activeRoundLeaveTitle), findsNothing);
      expect(
        find.byType(ActiveRoundScreen),
        findsOneWidget,
        reason: 'a tapped-by-accident arrow must cost nothing',
      );
    });

    testWidgets('still lets the golfer leave on purpose', (tester) async {
      await _startRound(tester);

      await tester.tap(_backArrow());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('active_round_leave')));
      await tester.pumpAndSettle();

      expect(find.byType(ActiveRoundScreen), findsNothing);
      expect(find.text(_homeMarker), findsOneWidget);
    });
  });
}
