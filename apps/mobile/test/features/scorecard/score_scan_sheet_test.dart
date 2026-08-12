// Checking a played card read off a photograph.
//
// The read is a draft and the golfer is the check. What these pin down is that
// nothing reaches the scorecard the golfer did not look at: the notation is
// asked rather than assumed, an unread hole stays blank rather than becoming a
// plausible number, and their own OUT/IN arithmetic is put in front of them
// when it disagrees.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/scorecard/data/scorecard_scan_api.dart';
import 'package:vsp_mobile/features/scorecard/presentation/score_scan_sheet.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  ScannedRowChecks checks({
    int? writtenOut,
    int? writtenIn,
    bool outAgrees = true,
    bool inAgrees = true,
    int cellsRead = 18,
  }) => ScannedRowChecks(
    holesRead: 18,
    cellsRead: cellsRead,
    writtenOut: writtenOut,
    writtenIn: writtenIn,
    writtenTotal: null,
    outAgrees: outAgrees,
    inAgrees: inAgrees,
    totalAgrees: false,
  );

  ScannedScoreRow row({
    String? player,
    ScannedNotation notation = ScannedNotation.strokes,
    Map<int, int?> holes = const {},
    ScannedRowChecks? rowChecks,
  }) => ScannedScoreRow(
    player: player,
    notation: notation,
    holes: [
      for (final entry in holes.entries)
        ScannedStroke(hole: entry.key, written: entry.value),
    ],
    checks: rowChecks ?? checks(),
  );

  /// Opens the sheet and hands back whatever the golfer confirmed.
  Future<Map<int, int>?> open(
    WidgetTester tester, {
    required ScannedScores scanned,
    Map<String, int> pars = const {},
  }) async {
    Map<int, int>? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showScoreScanSheet(
                  context,
                  scanned: scanned,
                  holePars: pars,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a row of strokes reaches the scorecard as written', (
    tester,
  ) async {
    final scanned = ScannedScores(
      players: [
        row(holes: {1: 5, 2: 4, 3: 3}),
      ],
    );

    await open(tester, scanned: scanned);

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('score-scan-hole-1')))
          .controller
          ?.text,
      '5',
    );
  });

  testWidgets('a row written against par is converted with the round\'s pars', (
    tester,
  ) async {
    // The card this was built against came back as to_par: the golfer had
    // written 0, +1, -1 rather than 4, 5, 3. Saving those as strokes would
    // have posted a round of nothing but ones and zeroes.
    final scanned = ScannedScores(
      players: [
        row(
          notation: ScannedNotation.toPar,
          holes: {1: 1, 2: 0, 3: -1},
        ),
      ],
    );

    await open(
      tester,
      scanned: scanned,
      pars: {'1': 4, '2': 4, '3': 5},
    );

    String textAt(int hole) => tester
        .widget<TextField>(find.byKey(Key('score-scan-hole-$hole')))
        .controller!
        .text;

    expect(textAt(1), '5');
    expect(textAt(2), '4');
    expect(textAt(3), '4');
  });

  testWidgets('switching the notation rewrites every hole', (tester) async {
    // The one answer that changes the whole card at once. A golfer who spots
    // that the numbers look like stroke counts must be able to say so without
    // retyping eighteen holes.
    final scanned = ScannedScores(
      players: [
        row(
          notation: ScannedNotation.toPar,
          holes: {1: 1, 2: 0},
        ),
      ],
    );

    await open(tester, scanned: scanned, pars: {'1': 4, '2': 4});
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('score-scan-hole-1')))
          .controller
          ?.text,
      '5',
    );

    await tester.tap(find.text('Số gậy'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('score-scan-hole-1')))
          .controller
          ?.text,
      '1',
    );
  });

  testWidgets('a hole the server could not read stays blank', (tester) async {
    // A blank is one tap to fill. A plausible wrong number has to be noticed
    // first, and on a scorecard nothing about a 5 looks wrong.
    final scanned = ScannedScores(
      players: [
        row(holes: {1: 5, 2: null, 3: 4}, rowChecks: checks(cellsRead: 2)),
      ],
    );

    await open(tester, scanned: scanned);

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('score-scan-hole-2')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.textContaining('1 hố không đọc được'), findsOneWidget);
  });

  testWidgets('a nine that disagrees with the golfer\'s own total is flagged', (
    tester,
  ) async {
    // This is not hypothetical. On the development card the front nine read
    // correctly and summed to the +2 written beside it; the back nine summed
    // to 2 against a written 1, and the misread hole was invisible in the
    // numbers themselves.
    final scanned = ScannedScores(
      players: [
        row(
          holes: {1: 4, 10: 5},
          rowChecks: checks(writtenIn: 1, inAgrees: false),
        ),
      ],
    );

    await open(tester, scanned: scanned);

    expect(find.textContaining('chín hố sau'), findsOneWidget);
  });

  testWidgets('an unknown notation cannot be saved until it is answered', (
    tester,
  ) async {
    // The same "1" is a hole in one or a bogey. Guessing on the golfer's
    // behalf would put a number on their card that nobody chose.
    final scanned = ScannedScores(
      players: [
        row(notation: ScannedNotation.unknown, holes: {1: 1, 2: 0}),
      ],
    );

    await open(tester, scanned: scanned, pars: {'1': 4, '2': 4});

    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(save.onPressed, isNull);

    await tester.tap(find.text('So với par'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('only the holes the golfer kept are returned', (tester) async {
    final scanned = ScannedScores(
      players: [
        row(holes: {1: 5, 2: 4}),
      ],
    );

    Map<int, int>? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                confirmed = await showScoreScanSheet(
                  context,
                  scanned: scanned,
                  holePars: const {},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The golfer clears hole 2 — they know they did not finish it.
    await tester.enterText(find.byKey(const Key('score-scan-hole-2')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(confirmed, {1: 5});
  });

  testWidgets('a four-ball card asks which row is the golfer\'s', (
    tester,
  ) async {
    // Four rows of handwriting, and the server cannot know which belongs to
    // the phone holding the card. Taking the first would post somebody else's
    // round under this golfer's name.
    final scanned = ScannedScores(
      players: [
        row(player: 'A', holes: {1: 5}),
        row(player: 'B', holes: {1: 3}),
      ],
    );

    await open(tester, scanned: scanned);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('score-scan-hole-1')))
          .controller
          ?.text,
      '5',
    );

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('score-scan-hole-1')))
          .controller
          ?.text,
      '3',
    );
  });

  testWidgets('a to_par hole with no par known stays blank', (tester) async {
    // A round whose pars the phone does not have cannot turn "+1" into a
    // score. Assuming a par 4 would be right about half the time and silently
    // wrong the rest.
    final scanned = ScannedScores(
      players: [
        row(notation: ScannedNotation.toPar, holes: {1: 1}),
      ],
    );

    await open(tester, scanned: scanned, pars: const {});

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('score-scan-hole-1')))
          .controller
          ?.text,
      isEmpty,
    );
  });
}
