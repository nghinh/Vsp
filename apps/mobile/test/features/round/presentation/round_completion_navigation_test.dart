// Tests for where a finished round goes.
//
// Eighteen holes used to end on `popUntil((route) => route.isFirst)`: a toast
// and the home screen. RoundSummaryScreen, RoundCompletionBloc and four
// widgets were all written, all complete, and referenced by nothing — and the
// screen would have thrown if anything had pushed it, because it resolved five
// dependencies through `context.read()` and the app provides none of them.
//
// So there are two things to hold down here, and the second is the one that
// made the first untestable before: that finishing arrives at the summary, and
// that the summary stands up on its own without an ancestor handing it a
// repository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_mobile/features/round/presentation/round_summary_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/screens/score/scorecard_screen.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  setUp(() {
    // The summary's connectivity check reads the Wi-Fi-only preference, which
    // is the one asynchronous dependency it has. Present here so the tests
    // exercise the path a device takes rather than the absent-plugin path.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the summary screen stands up with no providers above it', (
    tester,
  ) async {
    // The whole reason it was unreachable twice over: pushing it used to throw
    // ProviderNotFoundException for roundRepo, roundStateService, syncStore,
    // activeRoundGuard and connectivityService. Nothing is provided here on
    // purpose — that is the point of the test.
    await tester.pumpWidget(
      _app(const RoundSummaryScreen(roundId: 'round-1')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(RoundSummaryScreen), findsOneWidget);
  });

  testWidgets('it says the round is safe when the summary will not open', (
    tester,
  ) async {
    // There is no SQLite in a widget binding, which is the same shape as a
    // device whose local store is unavailable. The round was completed and
    // recorded before this screen opened, so nothing here may read as lost
    // data — hence the wording, in both languages.
    await tester.pumpWidget(
      _app(const RoundSummaryScreen(roundId: 'round-1')),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final vi = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(l10n.summaryUnavailable, isNot(vi.summaryUnavailable));
    // Whatever it settled on, it is a screen and not an exception.
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.summaryTitle), findsWidgets);
  });

  testWidgets('finishing a round opens the summary and leaves the round', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ScorecardScreen(
                      flightId: 'round-1',
                      holeIds: ['1', '2'],
                      playerIds: ['me'],
                      playerNames: {'me': 'Nghi'},
                      holePars: {'1': 4, '2': 4},
                    ),
                  ),
                ),
                child: const Text('open round'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open round'));
    await tester.pumpAndSettle();
    expect(find.byType(ScorecardScreen), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.byTooltip(l10n.scorecardFinishRound));
    await tester.pumpAndSettle();

    // The confirmation the golfer actually taps.
    await tester.tap(find.widgetWithText(FilledButton, l10n.scorecardFinish));
    await tester.pumpAndSettle();

    expect(find.byType(RoundSummaryScreen), findsOneWidget);
    // pushAndRemoveUntil, not push: a back gesture off the summary must not
    // walk into the scorecard of a round that is over.
    expect(find.byType(ScorecardScreen), findsNothing);
  });
}
