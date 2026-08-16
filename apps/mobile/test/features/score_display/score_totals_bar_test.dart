// The totals strip on the scorecard.
//
// It is silent before anything is scored, and it refuses Net rather than
// inventing an allocation — the same rule the games sheet follows, for the
// same reason: a wrong net score is invisible to the person reading it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/score_display/score_totals_bar.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  Widget host({
    Map<String, Map<int, int>> gross = const {
      'p1': {1: 5, 2: 3},
    },
    Map<String, int> handicaps = const {},
    Map<int, int>? strokeIndexes = const {1: 1, 2: 18},
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Scaffold(
          body: ScoreTotalsBar(
            playerIds: const ['p1'],
            playerNames: const {'p1': 'nghi'},
            grossByPlayer: gross,
            parByHole: const {1: 4, 2: 3},
            playerHandicaps: handicaps,
            strokeIndexes: strokeIndexes,
          ),
        ),
      );

  testWidgets('shows the gross total once something is scored',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('switches to to-par, signed', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('So với par'));
    await tester.pumpAndSettle();

    // 5−4 and 3−3 = +1.
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('net is offered when handicap and index are both known',
      (tester) async {
    await tester.pumpWidget(host(handicaps: const {'p1': 2}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Net'));
    await tester.pumpAndSettle();

    // One shot on index 1 → 8 − 1.
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('without a stroke index it says why net is missing',
      (tester) async {
    await tester.pumpWidget(
      host(handicaps: const {'p1': 2}, strokeIndexes: const {}),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Chưa tính được net'), findsOneWidget);
  });

  testWidgets('says nothing at all before the first score', (tester) async {
    await tester.pumpWidget(host(gross: const {'p1': {}}));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('score_display_mode')), findsNothing);
  });
}
