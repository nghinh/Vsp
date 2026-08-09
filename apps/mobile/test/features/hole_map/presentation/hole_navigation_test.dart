// Widget tests for moving the map between holes.
//
// A round has 18 holes and the map used to have one. HoleMapBloc implemented
// NavigateToHole and nothing in the app dispatched it, so the map was loaded
// once — with the hole the round opened at — and never told about another.
// Everything that hangs off the map inherited that: the strategic geometry,
// the satellite basemap, and the measuring tool.
//
// That last one is why this matters more than it reads. Nearly every hole in
// the database is unverified, so nearly every hole falls back to satellite plus
// the measuring tool, and the measuring tool is then the golfer's only distance
// figure. Pinned to one hole, it was their only distance figure on one hole out
// of eighteen.
//
// Three things are asserted here: that the golfer can move the map themselves,
// that it follows them when the scorecard moves, and that arriving at a hole
// starts a measuring session for *that* hole rather than inheriting points
// dropped on the last one.
//
// The hole length is tested alongside them because it is rendered by the same
// header. The field is called `yardage` from the tee-set DTO down and holds
// metres — the OpenAPI contract and the seed that generated most of these
// numbers both say so — and the header used to print it with a `yd` suffix.

import 'package:course_package/course_package.dart' hide AccuracyClass;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/map_loading_skeleton.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/features/round/presentation/active_round_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/widgets/score/hole_navigation_bar.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _NoLocationService implements LocationService {
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

/// Answers with whatever the caller asked for, so a test can tell which hole
/// the screen actually requested rather than trusting the number it printed.
class _PerHoleRepository implements HoleMapRepository {
  final HoleMapEntity? Function(int holeNumber) build;
  final List<int> requested = [];

  _PerHoleRepository(this.build);

  @override
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  }) async {
    requested.add(holeNumber);
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

/// A hole whose coordinates somebody digitised and somebody checked — the only
/// case that draws the vector map, and the only case with a length worth
/// printing without an approximation marker.
HoleMapEntity _surveyedHole(int holeNumber, {int? lengthMeters}) =>
    HoleMapEntity(
      courseId: 'course-1',
      courseName: 'Test course',
      holeNumber: holeNumber,
      par: 4,
      yardage: lengthMeters,
      provenance: const HoleDataProvenance(
        accuracyClass: AccuracyClass.classC,
        verificationStatus: VerificationStatus.verified,
      ),
      layers: const {
        MapLayerType.green: MapLayerEntity(
          type: MapLayerType.green,
          format: LayerGeometryFormat.geoJson,
          style: LayerStyle(),
          geoJson: {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [106.7000, 10.7030],
                  [106.7002, 10.7030],
                  [106.7002, 10.7032],
                  [106.7000, 10.7030],
                ],
              ],
            },
          },
        ),
      },
    );

Future<AppLocalizations> _pumpMap(
  WidgetTester tester, {
  required int holeNumber,
  List<int> holeNumbers = const [],
  HoleMapEntity? Function(int)? holeMap,
  DistanceUnit? distanceUnit,
  _PerHoleRepository? repository,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final repo = repository ?? _PerHoleRepository(holeMap ?? (_) => null);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepositoryProvider<HoleMapRepository>.value(
        value: repo,
        child: HoleMapScreen(
          packageId: 'package-1',
          courseId: 'course-1',
          courseName: 'Test course',
          holeNumber: holeNumber,
          holeNumbers: holeNumbers,
          locationService: _NoLocationService(),
          distanceUnit: distanceUnit,
          imageryConfig: SatelliteImageryConfig.unavailable,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return AppLocalizations.delegate.load(locale);
}

/// The header's previous/next control itself — `byTooltip` matches the tooltip
/// the IconButton builds, not the button.
Finder _stepButton(String tooltip) => find.ancestor(
  of: find.byTooltip(tooltip),
  matching: find.byType(IconButton),
);

/// The measuring tool currently on screen.
MeasureCubit _measureCubit(WidgetTester tester) =>
    BlocProvider.of<MeasureCubit>(
      tester.element(find.byType(SatelliteMeasureView, skipOffstage: false)),
    );

void main() {
  group('stepping through the round on the map', () {
    testWidgets('a next tap loads the next hole', (tester) async {
      final repo = _PerHoleRepository((n) => null);
      final l10n = await _pumpMap(
        tester,
        holeNumber: 7,
        holeNumbers: const [7, 8, 9],
        repository: repo,
      );

      expect(find.text(l10n.holeNumberLabel('7')), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.holeMapNextHole));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.holeNumberLabel('8')), findsOneWidget);
      expect(find.text(l10n.holeNumberLabel('7')), findsNothing);
      // The screen asked the package for hole 8, rather than relabelling 7.
      expect(repo.requested, [7, 8]);
    });

    testWidgets('a back tap loads the previous one', (tester) async {
      final l10n = await _pumpMap(
        tester,
        holeNumber: 8,
        holeNumbers: const [7, 8, 9],
      );

      await tester.tap(find.byTooltip(l10n.holeMapPreviousHole));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.holeNumberLabel('7')), findsOneWidget);
    });

    testWidgets('follows the round\'s own holes, not 1 to 18', (tester) async {
      // A back-nine round plays 10 through 18. Stepping on from the 10th has
      // to reach the 11th; counting positions rather than reading hole numbers
      // would land on the 2nd.
      final repo = _PerHoleRepository((n) => null);
      final l10n = await _pumpMap(
        tester,
        holeNumber: 10,
        holeNumbers: const [10, 11, 12, 13, 14, 15, 16, 17, 18],
        repository: repo,
      );

      await tester.tap(find.byTooltip(l10n.holeMapNextHole));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.holeNumberLabel('11')), findsOneWidget);
      expect(repo.requested, [10, 11]);
    });

    testWidgets('stops at both ends of the round', (tester) async {
      final l10n = await _pumpMap(
        tester,
        holeNumber: 7,
        holeNumbers: const [7, 8, 9],
      );

      // Disabled rather than hidden, so the header does not change width on
      // the first hole and the last.
      expect(
        tester
            .widget<IconButton>(_stepButton(l10n.holeMapPreviousHole))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(_stepButton(l10n.holeMapNextHole)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byTooltip(l10n.holeMapNextHole));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.holeMapNextHole));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.holeNumberLabel('9')), findsOneWidget);
      expect(
        tester.widget<IconButton>(_stepButton(l10n.holeMapNextHole)).onPressed,
        isNull,
      );
    });

    testWidgets('offers no navigation when opened on a single hole', (
      tester,
    ) async {
      final l10n = await _pumpMap(tester, holeNumber: 7);

      // A caller that opened one hole on its own has nowhere to step to.
      expect(find.byTooltip(l10n.holeMapNextHole), findsNothing);
      expect(find.byTooltip(l10n.holeMapPreviousHole), findsNothing);
    });
  });

  group('arriving at a hole', () {
    testWidgets('starts a measuring session for that hole, not the last one', (
      tester,
    ) async {
      final l10n = await _pumpMap(
        tester,
        holeNumber: 7,
        holeNumbers: const [7, 8, 9],
      );

      // Two points dropped while standing on the 7th.
      final cubit = _measureCubit(tester);
      cubit.addPoint(const LatLng(latitude: 10.70, longitude: 106.70));
      cubit.addPoint(const LatLng(latitude: 10.71, longitude: 106.70));
      // Twice: the cubit's emit reaches the panel on a microtask, so the first
      // frame is still the old state.
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.measurePoints(2)), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.holeMapNextHole));
      await tester.pump();
      await tester.pump();

      // Walking to the 8th does not carry the 7th's measurements with it —
      // a leg between two points on a hole the golfer has left is not a
      // distance, it is a wrong distance.
      expect(find.text(l10n.holeNumberLabel('8')), findsOneWidget);
      expect(find.text(l10n.measurePoints(0)), findsOneWidget);
      expect(_measureCubit(tester).state.points, isEmpty);
    });
  });

  group('the hole length in the header', () {
    testWidgets('is metres, because the field holds metres', (tester) async {
      await _pumpMap(
        tester,
        holeNumber: 7,
        holeMap: (n) => _surveyedHole(n, lengthMeters: 360),
      );

      // 360 printed as `360yd` is what a golfer reads as 329 m, and clubs down
      // for. Every hole on every course was overstated by 9%.
      expect(find.text('360 m'), findsOneWidget);
      expect(find.text('360yd'), findsNothing);
    });

    testWidgets('converts when the golfer asked for yards', (tester) async {
      await _pumpMap(
        tester,
        holeNumber: 7,
        holeMap: (n) => _surveyedHole(n, lengthMeters: 360),
        distanceUnit: DistanceUnit.yards,
      );

      expect(find.text('394 yd'), findsOneWidget);
      expect(find.text('360 m'), findsNothing);
    });
  });

  group('before a hole has loaded', () {
    testWidgets('shows a skeleton rather than a blank screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepositoryProvider<HoleMapRepository>(
            create: (_) => _PerHoleRepository((_) => null),
            child: const HoleMapScreen(
              packageId: 'package-1',
              courseId: 'course-1',
              courseName: 'Test course',
              holeNumber: 7,
            ),
          ),
        ),
      );

      // The very first frame, before the bloc has emitted anything. It used to
      // render an empty box, which on the Map tab is a black screen a golfer
      // reads as a crash.
      expect(
        find.byType(MapLoadingSkeleton, skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('during a round', () {
    Future<AppLocalizations> pumpRound(
      WidgetTester tester, {
      required int holeNumber,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ActiveRoundScreen(
            roundId: 'round-1',
            packageId: 'package-1',
            courseId: 'course-1',
            courseName: 'Test course',
            holeNumber: holeNumber,
            locationService: _NoLocationService(),
            holeIds: const ['7', '8', '9'],
            playerIds: const ['me'],
            playerNames: const {'me': 'Nghi'},
            holePars: const {'7': 3, '8': 4, '9': 5},
            holeMapRepository: _PerHoleRepository((_) => null),
            imageryConfig: SatelliteImageryConfig.unavailable,
          ),
        ),
      );
      await tester.pump();
      return AppLocalizations.delegate.load(const Locale('en'));
    }

    Future<void> openMap(WidgetTester tester) async {
      await tester.tap(find.byKey(activeRoundTabKey(ActiveRoundTab.map)));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the scorecard opens on the hole the round resumed at', (
      tester,
    ) async {
      final l10n = await pumpRound(tester, holeNumber: 8);

      // Resuming works out which hole the golfer stopped on and the scorecard
      // used to ignore it, opening on the round's first hole regardless — so
      // coming back on the 8th meant tapping forward to reach the score you
      // came back to enter.
      expect(find.text(l10n.holeOfTotal('2', '3')), findsWidgets);
    });

    testWidgets('the map follows the scorecard to the next hole', (
      tester,
    ) async {
      final l10n = await pumpRound(tester, holeNumber: 7);

      await openMap(tester);
      expect(find.text(l10n.holeNumberLabel('7')), findsOneWidget);

      // Back to the scorecard, and on to the next hole the way a golfer does.
      await tester.tap(find.byKey(activeRoundTabKey(ActiveRoundTab.score)));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(HoleNavigationBar),
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      await tester.pump();
      await tester.pump();

      await openMap(tester);
      expect(find.text(l10n.holeNumberLabel('8')), findsOneWidget);
      expect(find.text(l10n.holeNumberLabel('7')), findsNothing);
    });

    testWidgets('a map opened late opens on the hole being played', (
      tester,
    ) async {
      final l10n = await pumpRound(tester, holeNumber: 7);

      // The golfer plays two holes before looking at the map at all. The
      // round's hole map bloc is built lazily, so this is the case where it is
      // constructed already behind the golfer.
      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.descendant(
            of: find.byType(HoleNavigationBar),
            matching: find.byIcon(Icons.chevron_right),
          ),
        );
        await tester.pump();
      }

      await openMap(tester);
      expect(find.text(l10n.holeNumberLabel('9')), findsOneWidget);
    });

    testWidgets('catches up a map bloc another tab built two holes ago', (
      tester,
    ) async {
      final l10n = await pumpRound(tester, holeNumber: 7);

      // The Target tab reads the same round-wide hole map bloc, so opening it
      // constructs the bloc on the 7th. Playing on from there leaves the bloc
      // behind: it exists, it is loaded, and it is loaded on the wrong hole —
      // which the Map tab's own first build cannot fix, because from its point
      // of view nothing changed.
      await tester.tap(find.byKey(activeRoundTabKey(ActiveRoundTab.target)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(activeRoundTabKey(ActiveRoundTab.score)));
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.descendant(
            of: find.byType(HoleNavigationBar),
            matching: find.byIcon(Icons.chevron_right),
          ),
        );
        await tester.pump();
      }

      await openMap(tester);
      await tester.pump();
      expect(find.text(l10n.holeNumberLabel('9')), findsOneWidget);
      expect(find.text(l10n.holeNumberLabel('7')), findsNothing);
    });
  });
}
