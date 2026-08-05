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

import 'package:course_package/course_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
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
}

// ─── Harness ────────────────────────────────────────────────────────────────

const _holeNumber = 7;
const _par = 3;
const _yardage = 385;
const _courseName = 'Test course';

/// Builds the screen exactly as round start does: the scorecard's inputs come
/// straight from the configured round.
Future<AppLocalizations> _pump(
  WidgetTester tester,
  Locale locale, {
  String? packageId = 'package-1',
  int? par = _par,
}) async {
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
      ),
    ),
  );
  await tester.pump();
  return AppLocalizations.delegate.load(locale);
}

/// Opens a tab the way a golfer does — by tapping the bottom nav.
Future<void> _openTab(WidgetTester tester, ActiveRoundTab tab) async {
  await tester.tap(find.byKey(activeRoundTabKey(tab)));
  await tester.pump();
}

void _expectRendered(String text) {
  expect(find.text(text, skipOffstage: false), findsWidgets, reason: text);
}

void main() {
  group('a started round', () {
    testWidgets('opens on the scorecard, with the round it was configured for',
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
    });

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
      _expectRendered(l10n.activeRoundTargetHeading);

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

    testWidgets('sends End Round to the scorecard, which owns finishing', (
      tester,
    ) async {
      final l10n = await _pump(tester, const Locale('en'));

      await _openTab(tester, ActiveRoundTab.more);
      await tester.tap(find.text(l10n.activeRoundEndRound));
      await tester.pump();

      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.score.index,
      );
      _expectRendered(l10n.activeRoundEndRoundHint);
    });
  });

  group('honest data', () {
    testWidgets('no downloaded package means the map tab says so', (
      tester,
    ) async {
      final l10n = await _pump(tester, const Locale('en'), packageId: null);

      await _openTab(tester, ActiveRoundTab.map);

      // No map is loaded at all — there is nothing for it to read.
      expect(find.byType(HoleMapScreen, skipOffstage: false), findsNothing);
      _expectRendered(l10n.activeRoundMapUnavailableHeading);
      _expectRendered(l10n.activeRoundMapUnavailableMessage(_courseName));
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
      testWidgets('the target tab takes its heading, body and length from l10n',
          (tester) async {
        final l10n = await _pump(tester, locale);

        await _openTab(tester, ActiveRoundTab.target);

        _expectRendered(l10n.activeRoundTargetHeading);
        _expectRendered(l10n.activeRoundTargetMessage);
        _expectRendered(l10n.activeRoundLengthMeters(_yardage));
      });

      testWidgets('the conditions tab takes its empty state from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale);

        await _openTab(tester, ActiveRoundTab.conditions);
        await tester.pump();

        _expectRendered(l10n.activeRoundConditionsNoLocationHeading);
        _expectRendered(l10n.activeRoundConditionsNoLocationMessage);
      });

      testWidgets('the map tab takes its unavailable state from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale, packageId: null);

        await _openTab(tester, ActiveRoundTab.map);

        _expectRendered(l10n.activeRoundMapUnavailableHeading);
        _expectRendered(l10n.activeRoundMapUnavailableMessage(_courseName));
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
            RegExp(RegExp.escape(
                l10n.activeRoundTabSemanticsSelected(l10n.activeRoundScore))),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(
                l10n.activeRoundTabSemantics(l10n.activeRoundMap))),
          ),
          findsOneWidget,
        );

        semantics.dispose();
      });
    });
  }

  testWidgets('the two locales really differ — nothing is baked into the widgets', (
    tester,
  ) async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final vi = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(en.activeRoundTargetHeading, isNot(vi.activeRoundTargetHeading));
    expect(en.activeRoundTargetMessage, isNot(vi.activeRoundTargetMessage));
    expect(
      en.activeRoundMapUnavailableHeading,
      isNot(vi.activeRoundMapUnavailableHeading),
    );
    expect(
      en.activeRoundMapUnavailableMessage('X'),
      isNot(vi.activeRoundMapUnavailableMessage('X')),
    );
    expect(
      en.activeRoundConditionsNoLocationHeading,
      isNot(vi.activeRoundConditionsNoLocationHeading),
    );
    expect(
      en.activeRoundConditionsNoLocationMessage,
      isNot(vi.activeRoundConditionsNoLocationMessage),
    );
    expect(en.activeRoundEndRoundHint, isNot(vi.activeRoundEndRoundHint));
    expect(en.activeRoundOptions, isNot(vi.activeRoundOptions));
    expect(
      en.activeRoundTabSemanticsSelected('Map'),
      isNot(vi.activeRoundTabSemanticsSelected('Map')),
    );
  });
}
