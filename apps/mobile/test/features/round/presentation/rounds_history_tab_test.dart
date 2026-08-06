// Widget tests for RoundsHistoryTab — resume / abandon an in-progress round.
//
// Resuming is the second way into a round that is already under way, and it
// used to push the scorecard on its own. A golfer who put the phone in a
// pocket on the 7th and came back through history got score entry and nothing
// else — no hole map, no measuring tool, no way to report a course correction
// — while a golfer who never left had all five tabs. The tests below open a
// resumed round and walk every tab of it, and check that the round it opens is
// built from the real data the resume plan recovered rather than placeholders.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:course_package/course_package.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
import 'package:vsp_mobile/features/round/data/round_abandon_service.dart';
import 'package:vsp_mobile/features/round/data/round_history_repository.dart';
import 'package:vsp_mobile/features/round/data/round_resume_service.dart';
import 'package:vsp_mobile/features/round/presentation/active_round_screen.dart';
import 'package:vsp_mobile/features/round/presentation/rounds_history_tab.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/screens/score/scorecard_screen.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _FakeHistoryRepository extends RoundHistoryRepository {
  _FakeHistoryRepository(this.pages);

  /// One entry per fetch; the last entry is reused once exhausted.
  final List<List<Round>> pages;
  int fetchCount = 0;

  @override
  Future<RoundHistoryPage> fetchRounds({int page = 0, int size = 20}) async {
    final rounds = pages[fetchCount.clamp(0, pages.length - 1)];
    fetchCount++;
    return RoundHistoryPage(
      rounds: rounds,
      page: 0,
      size: size,
      totalElements: rounds.length,
      totalPages: 1,
      first: true,
      last: true,
    );
  }
}

class _FakeAbandonService extends RoundAbandonService {
  _FakeAbandonService(this.outcome);

  final RoundAbandonOutcome outcome;
  final List<String> abandoned = [];

  @override
  Future<RoundAbandonOutcome> abandon(Round round) async {
    abandoned.add(round.id);
    return outcome;
  }
}

/// A plan as the service builds it for a round already under way: real players,
/// real pars, the golfer part-way round, and the package the round was locked
/// to.
class _FakeResumeService extends RoundResumeService {
  _FakeResumeService({this.plan = _recoveredPlan});

  final RoundResumePlan plan;
  final List<String> plannedFor = [];

  @override
  Future<RoundResumePlan> planFor(
    Round round, {
    required String selfPlayerName,
  }) async {
    plannedFor.add(round.id);
    return plan;
  }
}

const _recoveredPlan = RoundResumePlan(
  holeIds: ['1', '2', '3'],
  playerIds: ['p1', 'p2'],
  playerNames: {'p1': 'Nghi', 'p2': 'Khách'},
  holePars: {'1': 4, '2': 3, '3': 5},
  currentHole: 2,
  currentPar: 3,
  currentYardage: 168,
  packageId: 'package-1',
  parsAreDefaults: false,
  playersAreDefaults: false,
);

/// Nothing recoverable: no local round row, no course detail, no scores.
const _degradedPlan = RoundResumePlan(
  holeIds: ['1'],
  playerIds: ['me'],
  playerNames: {'me': 'Me'},
  holePars: {'1': 4},
  currentHole: 1,
  parsAreDefaults: true,
  playersAreDefaults: true,
);

/// No GPS — the honest state on a test device, and the one the Conditions tab
/// has an answer for.
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

/// A downloaded package with no geometry for the hole — the ordinary case.
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

// ─── Fixtures ───────────────────────────────────────────────────────────────

Round _round({
  String id = 'round-1',
  RoundStatus status = RoundStatus.inProgress,
  bool isTournament = false,
}) {
  final now = DateTime(2026, 8, 5, 7);
  return Round(
    id: id,
    courseId: 42,
    courseName: 'Sân Golf Long Thành',
    status: status,
    startedAt: now,
    packageVersion: '',
    tournamentPolicyId: isTournament ? 'policy-1' : null,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _subject({
  required _FakeHistoryRepository repository,
  RoundAbandonService? abandonService,
  RoundResumeService? resumeService,
}) {
  // The resumed round builds its own hole-map repository from the on-device
  // package store unless one is already in scope; provided above the app so
  // the route the resume pushes finds it.
  return RepositoryProvider<HoleMapRepository>(
    create: (_) => _EmptyHoleMapRepository(),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: RoundsHistoryTab(
        repository: repository,
        resumeService: resumeService ?? _FakeResumeService(),
        abandonService: abandonService ?? _FakeAbandonService(
          RoundAbandonOutcome.abandoned,
        ),
        locationService: _FakeLocationService(),
      ),
    ),
  );
}

/// Taps Resume on the round's details sheet.
Future<void> _resume(WidgetTester tester) async {
  await tester.tap(find.text('Sân Golf Long Thành'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Resume round'));
  await tester.pumpAndSettle();
}

/// Opens a tab of the resumed round the way a golfer does.
Future<void> _openTab(WidgetTester tester, ActiveRoundTab tab) async {
  await tester.tap(find.byKey(activeRoundTabKey(tab)));
  await tester.pump();
  await tester.pump();
}

ActiveRoundScreen _resumedRound(WidgetTester tester) =>
    tester.widget<ActiveRoundScreen>(find.byType(ActiveRoundScreen));

void main() {
  testWidgets('an in-progress round offers resume and abandon', (tester) async {
    await tester.pumpWidget(
      _subject(repository: _FakeHistoryRepository([
        [_round()],
      ])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sân Golf Long Thành'));
    await tester.pumpAndSettle();

    expect(find.text('Resume round'), findsOneWidget);
    expect(find.text('Abandon round'), findsOneWidget);
    // Review is for finished rounds — there is nothing to review mid-round.
    expect(find.text('Review round'), findsNothing);
  });

  testWidgets('a completed round offers review only', (tester) async {
    await tester.pumpWidget(
      _subject(repository: _FakeHistoryRepository([
        [_round(status: RoundStatus.completed)],
      ])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sân Golf Long Thành'));
    await tester.pumpAndSettle();

    expect(find.text('Review round'), findsOneWidget);
    expect(find.text('Resume round'), findsNothing);
    expect(find.text('Abandon round'), findsNothing);
  });

  testWidgets('abandoned rounds are kept out of the history list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(repository: _FakeHistoryRepository([
        [_round(status: RoundStatus.abandoned)],
      ])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sân Golf Long Thành'), findsNothing);
    expect(find.text('No rounds yet'), findsOneWidget);
  });

  testWidgets('abandoning confirms, calls the service and reloads the list', (
    tester,
  ) async {
    final abandonService = _FakeAbandonService(RoundAbandonOutcome.abandoned);
    final repository = _FakeHistoryRepository([
      [_round()],
      const <Round>[], // the server no longer reports the round
    ]);
    await tester.pumpWidget(
      _subject(repository: repository, abandonService: abandonService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sân Golf Long Thành'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandon round'));
    await tester.pumpAndSettle();

    // Discarding a round asks first.
    expect(find.text('Abandon this round?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Abandon round'));
    await tester.pumpAndSettle();

    expect(abandonService.abandoned, ['round-1']);
    expect(find.text('Round abandoned'), findsOneWidget);
    expect(repository.fetchCount, 2);
    expect(find.text('No rounds yet'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation abandons nothing', (tester) async {
    final abandonService = _FakeAbandonService(RoundAbandonOutcome.abandoned);
    final repository = _FakeHistoryRepository([
      [_round()],
    ]);
    await tester.pumpWidget(
      _subject(repository: repository, abandonService: abandonService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sân Golf Long Thành'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandon round'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(abandonService.abandoned, isEmpty);
    expect(repository.fetchCount, 1);
  });

  testWidgets('a failed abandon says so and keeps the round', (tester) async {
    final abandonService = _FakeAbandonService(RoundAbandonOutcome.failed);
    final repository = _FakeHistoryRepository([
      [_round()],
    ]);
    await tester.pumpWidget(
      _subject(repository: repository, abandonService: abandonService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sân Golf Long Thành'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandon round'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Abandon round'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not abandon the round. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    // No reload: the round is still in progress as far as the server knows.
    expect(repository.fetchCount, 1);
  });

  group('resuming an in-progress round', () {
    testWidgets('opens the round, not the scorecard on its own', (
      tester,
    ) async {
      final resumeService = _FakeResumeService();
      await tester.pumpWidget(
        _subject(
          repository: _FakeHistoryRepository([
            [_round()],
          ]),
          resumeService: resumeService,
        ),
      );
      await tester.pumpAndSettle();

      await _resume(tester);

      expect(resumeService.plannedFor, ['round-1']);
      expect(find.byType(ActiveRoundScreen), findsOneWidget);
      // The scorecard is still there — it is the Score tab, and the round
      // opens on it, so nothing about score entry moved.
      final scorecard = tester.widget<ScorecardScreen>(
        find.byType(ScorecardScreen, skipOffstage: false),
      );
      expect(scorecard.flightId, 'round-1');
      expect(scorecard.holeIds, ['1', '2', '3']);
      expect(scorecard.playerIds, ['p1', 'p2']);
      expect(scorecard.holePars, {'1': 4, '2': 3, '3': 5});
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.score.index,
      );
    });

    testWidgets('carries the round\'s real data into the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(
          repository: _FakeHistoryRepository([
            [_round(isTournament: true)],
          ]),
        ),
      );
      await tester.pumpAndSettle();

      await _resume(tester);

      final screen = _resumedRound(tester);
      expect(screen.roundId, 'round-1');
      expect(screen.courseId, '42');
      expect(screen.courseName, 'Sân Golf Long Thành');
      // Where the golfer actually was, not the 1st tee.
      expect(screen.holeNumber, 2);
      expect(screen.par, 3);
      expect(screen.yardage, 168);
      // The package the round was locked to, recovered from the local round
      // row — the history API does not return it.
      expect(screen.packageId, 'package-1');
      expect(screen.holePars, {'1': 4, '2': 3, '3': 5});
      expect(screen.playerNames, {'p1': 'Nghi', 'p2': 'Khách'});
      expect(screen.isTournamentMode, isTrue);
    });

    testWidgets('reaches every tab of the round it resumed', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        _subject(
          repository: _FakeHistoryRepository([
            [_round()],
          ]),
        ),
      );
      await tester.pumpAndSettle();

      await _resume(tester);

      // The map: the tab a resumed round had no way of reaching at all.
      await _openTab(tester, ActiveRoundTab.map);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.map.index,
      );
      final map = tester.widget<HoleMapScreen>(
        find.byType(HoleMapScreen, skipOffstage: false),
      );
      expect(map.packageId, 'package-1');
      expect(map.courseId, '42');
      expect(map.holeNumber, 2);

      await _openTab(tester, ActiveRoundTab.target);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.target.index,
      );

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
      // The correction flow — reachable from a resumed round for the first
      // time, and the round is exactly when a golfer notices a wrong green.
      expect(
        find.text(l10n.activeRoundReportCorrection, skipOffstage: false),
        findsWidgets,
      );

      await _openTab(tester, ActiveRoundTab.score);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        ActiveRoundTab.score.index,
      );
    });

    testWidgets('says nothing it does not know', (tester) async {
      await tester.pumpWidget(
        _subject(
          repository: _FakeHistoryRepository([
            [_round()],
          ]),
          resumeService: _FakeResumeService(plan: _degradedPlan),
        ),
      );
      await tester.pumpAndSettle();

      await _resume(tester);

      final screen = _resumedRound(tester);
      // No course detail means no real par and no real length: they are
      // omitted rather than defaulted, so the hole header shows neither.
      expect(screen.par, isNull);
      expect(screen.yardage, isNull);
      // No local round row means no package id — the map tab says the hole is
      // unsurveyed instead of being handed an id that resolves to nothing.
      expect(screen.packageId, isNull);
      // The scorecard still gets a par for every hole; scoring cannot wait for
      // the network.
      expect(screen.holePars, {'1': 4});
    });
  });
}
