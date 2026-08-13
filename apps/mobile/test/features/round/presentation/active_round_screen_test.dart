// Widget tests for ActiveRoundScreen.
//
// Two things are under test here, and they are the reason this screen exists.
//
// 1. Reachability. Until round start was routed through this screen, the
//    strategic hole map, the satellite basemap, the measuring tool and the
//    course-correction flow were built, tested — and constructible from
//    nowhere. Every tab is opened below from a started round, by tapping the
//    bottom nav a golfer actually has.
//
// 2. That the scorecard still is the scorecard. The Score tab hosts the very
//    same ScorecardScreen round start used to push directly, with the same
//    inputs, so nothing about score entry changed.
//
// The non-map tabs also read every string from the l10n bundle, in both
// languages the app ships. Those assertions run once per locale on purpose —
// asserting only that the Vietnamese text renders would still pass if the
// strings were hardcoded, so the locales are also asserted to differ.
//
// 3. That a hole with no data is not a dead end. Every fake below has no
//    geometry, because that is the ordinary case: 61 of ~900 holes are
//    surveyed. The Map tab is expected to open satellite imagery with the
//    measuring tool on it, and — where the build has no imagery provider — to
//    explain that instead of drawing a blank map.

import 'package:course_package/course_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/features/round/presentation/active_round_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/screens/score/scorecard_screen.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

/// No GPS, which is the Conditions tab's honest empty state.
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

/// A downloaded package that holds no geometry for the hole — the common case
/// today, since only a fraction of holes are surveyed.
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
  // No package on this fake device unless a test says otherwise.
  Future<String?> findPackageIdForCourse(String courseId) async => null;
}

// ─── Harness ────────────────────────────────────────────────────────────────

const _holeNumber = 7;
const _par = 3;
const _yardage = 385;
const _courseName = 'Test course';

/// A build that was compiled with an operator's licensed imagery endpoint.
final _imageryAvailable = SatelliteImageryConfig.resolve(
  customTileUrl: 'https://tiles.example.vn/{z}/{x}/{y}.jpg',
  customAttribution: '© Example imagery',
);

/// Builds the screen exactly as round start does: the scorecard's inputs come
/// straight from the configured round.
Future<AppLocalizations> _pump(
  WidgetTester tester,
  Locale locale, {
  String? packageId = 'package-1',
  int? par = _par,
  SatelliteImageryConfig? imageryConfig,
}) async {
  // A phone-shaped surface. The satellite view stacks a banner, a map and the
  // measuring panel, which does not fit the 800×600 test default.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ActiveRoundScreen(
        roundId: 'round-1',
        packageId: packageId,
        courseId: 'course-1',
        courseName: _courseName,
        holeNumber: _holeNumber,
        par: par,
        yardage: _yardage,
        locationService: _FakeLocationService(),
        holeIds: const ['7', '8', '9'],
        playerIds: const ['me'],
        playerNames: const {'me': 'Nghi'},
        holePars: const {'7': 3, '8': 4, '9': 5},
        holeMapRepository: _EmptyHoleMapRepository(),
        imageryConfig: imageryConfig ?? SatelliteImageryConfig.unavailable,
      ),
    ),
  );
  await tester.pump();
  return AppLocalizations.delegate.load(locale);
}

/// Opens a tab the way a golfer does — by tapping the bottom nav.
///
/// Pumped twice: the hole map bloc is built lazily on the first tab that reads
/// it, and the package lookup it starts resolves on a later microtask.
Future<void> _openTab(WidgetTester tester, ActiveRoundTab tab) async {
  await tester.tap(find.byKey(activeRoundTabKey(tab)));
  await tester.pump();
  await tester.pump();
}

void _expectRendered(String text) {
  expect(find.text(text, skipOffstage: false), findsWidgets, reason: text);
}

void main() {
  group('a started round', () {
    testWidgets(
      'opens on the scorecard, with the round it was configured for',
      (tester) async {
        await _pump(tester, const Locale('en'));

        final scorecard = tester.widget<ScorecardScreen>(
          find.byType(ScorecardScreen, skipOffstage: false),
        );
        expect(scorecard.flightId, 'round-1');
        expect(scorecard.holeIds, ['7', '8', '9']);
        expect(scorecard.playerIds, ['me']);
        expect(scorecard.playerNames, {'me': 'Nghi'});
        expect(scorecard.holePars, {'7': 3, '8': 4, '9': 5});

        // And it is the tab the golfer is actually looking at.
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, ActiveRoundTab.score.index);
      },
    );

    testWidgets('reaches the hole map — the tab that had no way in', (
      tester,
    ) async {
      await _pump(tester, const Locale('en'));

      await _openTab(tester, ActiveRoundTab.map);

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, ActiveRoundTab.map.index);
      // The map screen itself, wired to the round's package and hole — the
      // satellite basemap and the measuring tool live inside it.
      final map = tester.widget<HoleMapScreen>(
        find.byType(HoleMapScreen, skipOffstage: false),
      );
      expect(map.packageId, 'package-1');
      expect(map.courseId, 'course-1');
      expect(map.courseName, _courseName);
      expect(map.holeNumber, _holeNumber);
      expect(map.locationService, isNotNull);
    });

    testWidgets('reaches the target, conditions and more tabs', (tester) async {
      final l10n = await _pump(tester, const Locale('en'));

      await _openTab(tester, ActiveRoundTab.target);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.target.index,
      );
      // This hole is unsurveyed, so the target tab says what it can — that
      // there is no hole to drop a target on. The live readout is covered in
      // active_round_target_view_test.dart.
      _expectRendered(l10n.activeRoundTargetUnsurveyedHeading);

      await _openTab(tester, ActiveRoundTab.conditions);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.conditions.index,
      );

      await _openTab(tester, ActiveRoundTab.more);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.more.index,
      );
      // The correction flow's only entry point in the app.
      _expectRendered(l10n.activeRoundReportCorrection);
    });

    testWidgets('End Round ends the round instead of giving directions to it', (
      tester,
    ) async {
      // The tile used to switch to the Score tab and post a hint telling the
      // golfer to finish there — an app answering "end my round" by pointing
      // at a button. It now opens the same confirmation the scorecard's own
      // action does.
      final l10n = await _pump(tester, const Locale('en'));

      await _openTab(tester, ActiveRoundTab.more);
      await tester.tap(find.text(l10n.activeRoundEndRound));
      await tester.pump();

      // Still switches: tabs are lazy, and the scorecard has to exist before
      // it can be asked to do anything.
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.score.index,
      );

      // The request goes out after that frame, once the scorecard is built.
      await tester.pump();
      await tester.pump();

      expect(
        find.text(l10n.scorecardFinishTitle),
        findsOneWidget,
        reason: 'the confirmation should open, not a hint to go find it',
      );
      expect(find.text(l10n.scorecardKeepPlaying), findsOneWidget);
    });
  });

  group('honest data', () {
    testWidgets(
      'no downloaded package opens satellite and the measuring tool',
      (tester) async {
        final l10n = await _pump(
          tester,
          const Locale('en'),
          packageId: null,
          imageryConfig: _imageryAvailable,
        );

        await _openTab(tester, ActiveRoundTab.map);

        // This used to be an empty state, which is the worst answer on the
        // holes where a golfer has the least data. The imagery is real even
        // where our vector geometry is not, so the hole opens on it with the
        // measuring tool live — and says it is unsurveyed while it does.
        expect(
          find.byType(SatelliteMeasureView, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.byType(NoGeometryBanner, skipOffstage: false),
          findsOneWidget,
        );
        _expectRendered(l10n.holeNoGeometryBadge);
        _expectRendered(l10n.holeNoGeometryTitle);
        _expectRendered(l10n.holeNoGeometryBody);
      },
    );

    testWidgets(
      'no downloaded package and no imagery provider still hands over a ruler',
      (tester) async {
        final l10n = await _pump(tester, const Locale('en'), packageId: null);

        await _openTab(tester, ActiveRoundTab.map);

        // Satellite tiles are deliberately off in a build with no token — we
        // pull nothing from a provider we have no licence for. The measuring
        // tool is a separate thing that runs on GPS, so it is still there,
        // and the banner says which of the two the golfer is looking at.
        expect(
          find.byType(SatelliteMeasureView, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.byType(NoGeometryBanner, skipOffstage: false),
          findsOneWidget,
        );
        _expectRendered(l10n.holeNoGeometryBadge);
        _expectRendered(l10n.holeNoGeometryBodyNoImagery);
        // And it does not go on promising imagery it cannot fetch.
        expect(
          find.text(l10n.holeNoGeometryBody, skipOffstage: false),
          findsNothing,
        );
      },
    );

    testWidgets('the map tab is still reached with a package present', (
      tester,
    ) async {
      await _pump(tester, const Locale('en'));

      await _openTab(tester, ActiveRoundTab.map);

      expect(find.byType(HoleMapScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('no GPS fix means the conditions tab asks for one', (
      tester,
    ) async {
      final l10n = await _pump(tester, const Locale('en'));

      await _openTab(tester, ActiveRoundTab.conditions);
      await tester.pump();

      _expectRendered(l10n.activeRoundConditionsNoLocationHeading);
      _expectRendered(l10n.activeRoundConditionsNoLocationMessage);
    });

    testWidgets('an unknown par is omitted, not defaulted', (tester) async {
      final l10n = await _pump(tester, const Locale('en'), par: null);

      await _openTab(tester, ActiveRoundTab.target);

      _expectRendered(l10n.activeRoundHole);
      expect(find.text(l10n.fieldPar, skipOffstage: false), findsNothing);
    });

    testWidgets('a known par is shown as the course records it', (
      tester,
    ) async {
      final l10n = await _pump(tester, const Locale('en'));

      await _openTab(tester, ActiveRoundTab.target);

      _expectRendered(l10n.fieldPar);
      _expectRendered('$_par');
    });
  });

  for (final locale in const [Locale('en'), Locale('vi')]) {
    group('ActiveRoundScreen in ${locale.languageCode}', () {
      testWidgets(
        'the target tab takes its heading, body and length from l10n',
        (tester) async {
          final l10n = await _pump(tester, locale);

          await _openTab(tester, ActiveRoundTab.target);

          _expectRendered(l10n.activeRoundTargetUnsurveyedHeading);
          _expectRendered(l10n.activeRoundTargetUnsurveyedMessage);
          _expectRendered('$_yardage m');
        },
      );

      testWidgets('the conditions tab takes its empty state from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale);

        await _openTab(tester, ActiveRoundTab.conditions);
        await tester.pump();

        _expectRendered(l10n.activeRoundConditionsNoLocationHeading);
        _expectRendered(l10n.activeRoundConditionsNoLocationMessage);
      });

      testWidgets('the map tab takes its unsurveyed banner from l10n', (
        tester,
      ) async {
        final l10n = await _pump(
          tester,
          locale,
          packageId: null,
          imageryConfig: _imageryAvailable,
        );

        await _openTab(tester, ActiveRoundTab.map);

        _expectRendered(l10n.holeNoGeometryBadge);
        _expectRendered(l10n.holeNoGeometryTitle);
      });

      testWidgets('the map tab explains a build with no imagery from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale, packageId: null);

        await _openTab(tester, ActiveRoundTab.map);

        _expectRendered(l10n.holeNoGeometryTitle);
        _expectRendered(l10n.holeNoGeometryBodyNoImagery);
      });

      testWidgets('the more tab takes its title and menu labels from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale);

        await _openTab(tester, ActiveRoundTab.more);

        _expectRendered(l10n.activeRoundOptions);
        _expectRendered(l10n.activeRoundReportCorrection);
        _expectRendered(l10n.activeRoundEndRound);
      });

      testWidgets('the bottom nav announces its tabs in the same language', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final l10n = await _pump(tester, locale);

        // Matched as a substring: the nav item's own Text is merged into the
        // same semantics node, so the announced label is the l10n phrase plus
        // the visible label.
        expect(
          find.bySemanticsLabel(
            RegExp(
              RegExp.escape(
                l10n.activeRoundTabSemanticsSelected(l10n.activeRoundScore),
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            RegExp(
              RegExp.escape(l10n.activeRoundTabSemantics(l10n.activeRoundMap)),
            ),
          ),
          findsOneWidget,
        );

        semantics.dispose();
      });
    });
  }

  testWidgets(
    'the two locales really differ — nothing is baked into the widgets',
    (tester) async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final vi = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(en.activeRoundTargetHeading, isNot(vi.activeRoundTargetHeading));
      expect(en.activeRoundTargetMessage, isNot(vi.activeRoundTargetMessage));
      expect(
        en.activeRoundTargetUnsurveyedHeading,
        isNot(vi.activeRoundTargetUnsurveyedHeading),
      );
      expect(
        en.activeRoundTargetUnsurveyedMessage,
        isNot(vi.activeRoundTargetUnsurveyedMessage),
      );
      expect(
        en.holeNoGeometryBodyNoImagery,
        isNot(vi.holeNoGeometryBodyNoImagery),
      );
      expect(en.basemapMeasure, isNot(vi.basemapMeasure));
      expect(en.measureYouToGreen, isNot(vi.measureYouToGreen));
      expect(
        en.activeRoundConditionsNoLocationHeading,
        isNot(vi.activeRoundConditionsNoLocationHeading),
      );
      expect(
        en.activeRoundConditionsNoLocationMessage,
        isNot(vi.activeRoundConditionsNoLocationMessage),
      );
      expect(en.activeRoundEndRound, isNot(vi.activeRoundEndRound));
      expect(en.activeRoundOptions, isNot(vi.activeRoundOptions));
      expect(
        en.activeRoundTabSemanticsSelected('Map'),
        isNot(vi.activeRoundTabSemanticsSelected('Map')),
      );
    },
  );
}
