// Widget tests for RoundsHistoryTab — resume / abandon an in-progress round.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/features/round/data/round_abandon_service.dart';
import 'package:vsp_mobile/features/round/data/round_history_repository.dart';
import 'package:vsp_mobile/features/round/data/round_resume_service.dart';
import 'package:vsp_mobile/features/round/presentation/rounds_history_tab.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

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

class _FakeResumeService extends RoundResumeService {
  @override
  Future<RoundResumePlan> planFor(
    Round round, {
    required String selfPlayerName,
  }) async {
    return const RoundResumePlan(
      holeIds: ['1'],
      playerIds: ['me'],
      playerNames: {'me': 'Me'},
      holePars: {'1': 4},
      parsAreDefaults: true,
      playersAreDefaults: true,
    );
  }
}

// ─── Fixtures ───────────────────────────────────────────────────────────────

Round _round({
  String id = 'round-1',
  RoundStatus status = RoundStatus.inProgress,
}) {
  final now = DateTime(2026, 8, 5, 7);
  return Round(
    id: id,
    courseId: 42,
    courseName: 'Sân Golf Long Thành',
    status: status,
    startedAt: now,
    packageVersion: '',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _subject({
  required _FakeHistoryRepository repository,
  RoundAbandonService? abandonService,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: kSupportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: RoundsHistoryTab(
      repository: repository,
      resumeService: _FakeResumeService(),
      abandonService: abandonService ?? _FakeAbandonService(
        RoundAbandonOutcome.abandoned,
      ),
    ),
  );
}

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
}
