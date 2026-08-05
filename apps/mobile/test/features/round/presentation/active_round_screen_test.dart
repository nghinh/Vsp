// Widget tests for ActiveRoundScreen — the non-map tabs read every string from
// the l10n bundle, in both languages the app ships.
//
// These tabs were the last place in the app with Vietnamese literals baked into
// the widget tree: a Vietnamese golfer saw the right words by accident and an
// English one saw Vietnamese. Every assertion below runs once per locale on
// purpose — asserting only that the Vietnamese text renders would still pass if
// the strings were hardcoded, so the locales are also asserted to differ.

import 'package:course_package/course_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
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

/// No downloaded package, which is the map tab's empty state. The tabs under
/// test do not depend on it.
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
const _yardage = 385;

/// Every tab is built by the IndexedStack, so one pump covers all of them.
Future<AppLocalizations> _pump(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    RepositoryProvider<HoleMapRepository>(
      create: (_) => _EmptyHoleMapRepository(),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActiveRoundScreen(
          roundId: 'round-1',
          packageId: 'package-1',
          courseId: 'course-1',
          courseName: 'Test course',
          holeNumber: _holeNumber,
          par: 4,
          yardage: _yardage,
          locationService: _FakeLocationService(),
        ),
      ),
    ),
  );
  await tester.pump();
  return AppLocalizations.delegate.load(locale);
}

void _expectRendered(String text) {
  expect(find.text(text, skipOffstage: false), findsWidgets, reason: text);
}

void main() {
  for (final locale in const [Locale('en'), Locale('vi')]) {
    group('ActiveRoundScreen in ${locale.languageCode}', () {
      testWidgets('the score tab takes its heading and body from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale);

        _expectRendered(l10n.activeRoundScoreHeading(_holeNumber));
        _expectRendered(l10n.activeRoundScoreMessage);
      });

      testWidgets('the target tab takes its heading, body and length from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale);

        _expectRendered(l10n.activeRoundTargetHeading);
        _expectRendered(l10n.activeRoundTargetMessage);
        _expectRendered(l10n.activeRoundLengthMeters(_yardage));
      });

      testWidgets('the conditions tab takes its heading and body from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale);

        _expectRendered(l10n.activeRoundConditionsHeading);
        _expectRendered(l10n.activeRoundConditionsMessage);
      });

      testWidgets('the more tab takes its title and menu labels from l10n', (
        tester,
      ) async {
        final l10n = await _pump(tester, locale);

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
                l10n.activeRoundTabSemanticsSelected(l10n.activeRoundMap))),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(
                l10n.activeRoundTabSemantics(l10n.activeRoundScore))),
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

    expect(en.activeRoundScoreHeading(1), isNot(vi.activeRoundScoreHeading(1)));
    expect(en.activeRoundScoreMessage, isNot(vi.activeRoundScoreMessage));
    expect(en.activeRoundTargetHeading, isNot(vi.activeRoundTargetHeading));
    expect(en.activeRoundTargetMessage, isNot(vi.activeRoundTargetMessage));
    expect(
      en.activeRoundConditionsHeading,
      isNot(vi.activeRoundConditionsHeading),
    );
    expect(
      en.activeRoundConditionsMessage,
      isNot(vi.activeRoundConditionsMessage),
    );
    expect(en.activeRoundOptions, isNot(vi.activeRoundOptions));
    expect(
      en.activeRoundTabSemanticsSelected('Map'),
      isNot(vi.activeRoundTabSemanticsSelected('Map')),
    );
  });
}
