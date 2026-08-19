// A round played after the Rounds tab was first opened shows up in it.
//
// Found by the screen-by-screen sweep. It started a round, backed out without
// finishing, and opened the Rounds tab: eight completed rounds and no sign of
// the one in progress. The server had it — `GET /rounds` answered
// `IN_PROGRESS` for a round begun a minute earlier — so nothing was lost. The
// list simply never asked again.
//
// The home shell keeps every visited tab alive inside an IndexedStack, which
// is what preserves scroll position when a golfer moves between tabs. It also
// means `initState` runs exactly once for the life of the app, and this list
// loads there and nowhere else. So:
//
//   * finish a round, tap Vòng đấu, and the round just played is missing;
//   * back out of a round and it becomes unreachable — this list is the only
//     place offering to resume or abandon one, while the unfinished round goes
//     on blocking the start of the next.
//
// The tab is now told when it is opened again, the same way the scorecard is
// told when something outside asks it to finish.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/features/round/data/round_history_repository.dart';
import 'package:vsp_mobile/features/round/presentation/rounds_history_tab.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A repository whose answer changes between calls, like a server does.
class _GrowingHistory extends RoundHistoryRepository {
  _GrowingHistory(this._pages);

  final List<List<Round>> _pages;
  int calls = 0;

  @override
  Future<RoundHistoryPage> fetchRounds({int page = 0, int size = 20}) async {
    final rounds = _pages[calls.clamp(0, _pages.length - 1)];
    calls++;
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

Round _round(String id, RoundStatus status, DateTime at) => Round(
  id: id,
  courseId: 1351,
  courseName: 'Long Biên Golf Course — Đường A',
  status: status,
  startedAt: at,
  packageVersion: '',
  createdAt: at,
  updatedAt: at,
);

void main() {
  testWidgets('reloads when the golfer opens the tab again', (tester) async {
    final firstVisit = [
      _round('done', RoundStatus.completed, DateTime(2026, 8, 19, 1)),
    ];
    final afterPlaying = [
      _round('playing', RoundStatus.inProgress, DateTime(2026, 8, 19, 4)),
      _round('done', RoundStatus.completed, DateTime(2026, 8, 19, 1)),
    ];
    final history = _GrowingHistory([firstVisit, afterPlaying]);
    final reopened = ValueNotifier<int>(0);
    addTearDown(reopened.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoundsHistoryTab(reopened: reopened, repository: history),
      ),
    );
    await tester.pumpAndSettle();

    expect(history.calls, 1, reason: 'the first visit loads');

    // The golfer plays a round somewhere else in the app and comes back.
    reopened.value++;
    await tester.pumpAndSettle();

    expect(
      history.calls,
      2,
      reason: 'this is the defect: the tab never asked a second time, so the '
          'round in progress stayed invisible and unreachable',
    );
  });

  testWidgets('and does not reload for nothing', (tester) async {
    // A tab that reloaded on every rebuild would fetch on every frame the
    // shell paints. The signal has to be the reopening, not the rebuild.
    final history = _GrowingHistory([
      [_round('done', RoundStatus.completed, DateTime(2026, 8, 19, 1))],
    ]);
    final reopened = ValueNotifier<int>(0);
    addTearDown(reopened.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoundsHistoryTab(reopened: reopened, repository: history),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(history.calls, 1);
  });

  testWidgets('works with no signal at all', (tester) async {
    // Opened outside the home shell — a test, or a route of its own — there is
    // nothing to poke it and `initState` is enough.
    final history = _GrowingHistory([
      [_round('done', RoundStatus.completed, DateTime(2026, 8, 19, 1))],
    ]);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoundsHistoryTab(repository: history),
      ),
    );
    await tester.pumpAndSettle();

    expect(history.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
