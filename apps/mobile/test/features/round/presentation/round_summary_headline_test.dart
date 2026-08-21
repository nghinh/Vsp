// What the summary screen leads with, and how it reads a card.
//
// The screen opened with the course name, the date and a sync banner — three
// things the golfer already knew — and printed the number they had just spent
// four hours producing further down, in a row the size of everything else.
//
// It also carried `frontNineStrokes` and `backNineStrokes` on the model and
// rendered neither: eighteen identical rows, and a golfer asking "what did I
// go out in" counted them by hand.
//
// The colours are here too. Under par, over par and level were `Colors.green`,
// `Colors.red` and `Colors.grey` — three constants belonging to no palette in
// this project and answering to no contrast test. Material's red measures
// 4.45:1 on this app's card surface, below the 4.5 floor, and it is the colour
// most scores are printed in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/round/domain/round_summary.dart';
import 'package:vsp_mobile/features/round/domain/score_entry.dart';
import 'package:vsp_mobile/features/round/domain/sync_state.dart';
import 'package:vsp_mobile/features/round/presentation/widgets/round_headline.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// [count] holes of par 4 scored [strokes] each, so every total below is
/// arithmetic a golfer could check against the card in their pocket.
PlayerScoreSummary player({
  required String name,
  required int strokes,
  int count = 18,
}) {
  final holes = [
    for (var i = 1; i <= count; i++)
      ScoreEntry(holeNumber: i, par: 4, strokes: strokes, putts: 2),
  ];
  return PlayerScoreSummary(
    playerId: name,
    playerName: name,
    holes: holes,
    totalStrokes: strokes * count,
    totalPar: 4 * count,
    relativeScore: (strokes - 4) * count,
    syncState: SyncState.synced,
  );
}

/// The ordinary Vietnamese round: holes the package carries no geometry for,
/// so the summary is handed par 0 for every one of them.
PlayerScoreSummary playerWithNoParKnown({
  required String name,
  required int totalStrokes,
  int count = 18,
}) {
  final holes = [
    for (var i = 1; i <= count; i++)
      ScoreEntry(
        holeNumber: i,
        par: 0,
        strokes: totalStrokes ~/ count,
        putts: 2,
      ),
  ];
  return PlayerScoreSummary(
    playerId: name,
    playerName: name,
    holes: holes,
    totalStrokes: totalStrokes,
    // What the completion bloc produces when no hole has a par: nothing summed
    // and nothing to be relative to. The zero below is the trap — it used to
    // be printed as "E".
    totalPar: 0,
    relativeScore: 0,
    syncState: SyncState.synced,
  );
}

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1290, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: VspTheme.dark(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('a solo round', () {
    testWidgets('leads with the score, not the course', (tester) async {
      await pump(
        tester,
        RoundHeadline(
          players: [player(name: 'Nghi', strokes: 5)],
          courseName: 'Long Biên Golf Course',
          date: '17/8/2026',
        ),
      );

      final score = tester.getTopLeft(find.text('90'));
      final caption = tester.getTopLeft(find.textContaining('Long Biên'));
      expect(score.dy, lessThan(caption.dy));
    });

    testWidgets('says level par as E, the way it is said out loud', (
      tester,
    ) async {
      await pump(
        tester,
        RoundHeadline(
          players: [player(name: 'Nghi', strokes: 4)],
          courseName: 'Long Biên',
          date: '17/8/2026',
        ),
      );

      expect(find.text('E'), findsOneWidget);
    });

    testWidgets('says nothing at all when no hole has a par', (tester) async {
      // 78 strokes and not one known par. The screen used to answer that with
      // "78 E" — level par, stated as fact, from a round where par was never
      // known — while the server-written recap beside it said "+6 so với par
      // 72". Both were on the same sales screenshot, disagreeing.
      await pump(
        tester,
        RoundHeadline(
          players: [playerWithNoParKnown(name: 'Nghi', totalStrokes: 78)],
          courseName: 'Long Biên Golf Course',
          date: '21/8/2026',
        ),
      );

      expect(find.text('78'), findsOneWidget, reason: 'the strokes are known');
      expect(find.text('E'), findsNothing);
      expect(find.text('+0'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('and over par with a sign', (tester) async {
      await pump(
        tester,
        RoundHeadline(
          players: [player(name: 'Nghi', strokes: 5)],
          courseName: 'Long Biên',
          date: '17/8/2026',
        ),
      );

      expect(find.text('+18'), findsOneWidget);
    });
  });

  group('a flight', () {
    testWidgets('gives every golfer a line, best first', (tester) async {
      await pump(
        tester,
        RoundHeadline(
          players: [
            player(name: 'Nghi', strokes: 5),
            player(name: 'Khách', strokes: 4),
          ],
          courseName: 'Long Biên',
          date: '17/8/2026',
        ),
      );

      // A single big headline would have to pick one golfer, and picking the
      // first in the list is how the stats card on this same screen came to
      // show a stranger's round.
      expect(find.text('Nghi'), findsOneWidget);
      expect(find.text('Khách'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Khách')).dy,
        lessThan(tester.getTopLeft(find.text('Nghi')).dy),
        reason: '72 beat 90 and should be read first',
      );
    });
  });

  group('the nine totals', () {
    testWidgets('are labelled the way a paper card labels them', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await pump(tester, NineTotals(player: player(name: 'Nghi', strokes: 5)));

      expect(find.text(l10n.summaryOut), findsOneWidget);
      expect(find.text(l10n.summaryIn), findsOneWidget);
      expect(find.text(l10n.summaryTotal), findsOneWidget);
    });

    testWidgets('and they add up', (tester) async {
      // 18 holes at 5: 45 out, 45 in, 90 total.
      await pump(tester, NineTotals(player: player(name: 'Nghi', strokes: 5)));

      expect(find.text('45'), findsNWidgets(2));
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('a nine-hole round has no back nine to invent', (
      tester,
    ) async {
      await pump(
        tester,
        NineTotals(player: player(name: 'Nghi', strokes: 5, count: 9)),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('45'), findsNWidgets(2));
    });
  });

  group('under, over and level', () {
    testWidgets('take their colours from the palette, not from Material', (
      tester,
    ) async {
      late Color under;
      late Color over;
      late Color level;
      await pump(
        tester,
        Builder(
          builder: (context) {
            under = relativeScoreColour(context, -3);
            over = relativeScoreColour(context, 3);
            level = relativeScoreColour(context, 0);
            return const SizedBox.shrink();
          },
        ),
      );

      final scheme = VspTheme.dark().colorScheme;
      expect(under, scheme.tertiary);
      expect(over, scheme.error);
      expect(level, scheme.onSurfaceVariant);
      expect(under, isNot(Colors.green));
      expect(over, isNot(Colors.red));
    });
  });
}
