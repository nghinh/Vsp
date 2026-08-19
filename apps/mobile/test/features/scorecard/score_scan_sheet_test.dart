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
import 'package:vsp_mobile/features/scorecard/domain/score_row_matcher.dart';
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

  const solo = [RowCandidate(playerId: '66', name: 'Nguyễn Hồng Nghi')];

  /// Opens the sheet and hands back whatever the golfer confirmed.
  Future<ConfirmedStrokes?> open(
    WidgetTester tester, {
    required ScannedScores scanned,
    Map<String, int> pars = const {},
    List<RowCandidate> players = solo,
  }) async {
    ConfirmedStrokes? result;
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
                  players: players,
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

    ConfirmedStrokes? confirmed;
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
                  players: solo,
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

    expect(confirmed, {'66': {1: 5}});
  });

  testWidgets('the name written on the card picks the player', (tester) async {
    // Four rows of handwriting and four golfers in the round. The label at the
    // left of each row is how golfers have always said whose is whose, and the
    // round already knows who is playing — so the app reads it rather than
    // asking the question the card has already answered.
    final scanned = ScannedScores(
      players: [
        row(player: 'Nam', holes: {1: 5}),
        row(player: 'Nghi', holes: {1: 3}),
      ],
    );

    final confirmed = await open(
      tester,
      scanned: scanned,
      players: const [
        RowCandidate(playerId: '66', name: 'Nguyễn Hồng Nghi'),
        RowCandidate(playerId: '67', name: 'Trần Văn Nam'),
      ],
    );
    expect(confirmed, isNull);

    // The chips say who each row went to, so the match is checked rather than
    // trusted.
    expect(find.text('Nam → Trần Văn Nam'), findsOneWidget);
    expect(find.text('Nghi → Nguyễn Hồng Nghi'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  });

  testWidgets('both matched rows are saved, each to its own player', (
    tester,
  ) async {
    final scanned = ScannedScores(
      players: [
        row(player: 'Nam', holes: {1: 5}),
        row(player: 'N.H.N', holes: {1: 3}),
      ],
    );

    ConfirmedStrokes? confirmed;
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
                  players: const [
                    RowCandidate(playerId: '66', name: 'Nguyễn Hồng Nghi'),
                    RowCandidate(playerId: '67', name: 'Trần Văn Nam'),
                  ],
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
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(confirmed, {
      '67': {1: 5},
      '66': {1: 3},
    });
  });

  testWidgets('a row nobody could be matched to is not saved', (tester) async {
    // A guest who wrote "Khách" is nobody in this round. Writing their strokes
    // onto the nearest player would take one golfer's card and give it to
    // another, which is worse than the row simply not arriving.
    final scanned = ScannedScores(
      players: [
        row(player: 'Khách', holes: {1: 5}),
        row(player: 'Nghi', holes: {1: 4}),
      ],
    );

    final confirmed = await open(
      tester,
      scanned: scanned,
      players: const [RowCandidate(playerId: '66', name: 'Nguyễn Hồng Nghi')],
    );
    expect(confirmed, isNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
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

  group('a reading the app is unsure about', () {
    // Measured against a real card — Hilltop Valley, four players, folded and
    // photographed sideways in a car. Asked seven times, the reader answered
    // differently every time: one player, then two, then three, never the four
    // that are on it. Its own checks caught it each time — outAgrees false,
    // totalAgrees false — and the sheet was using half that signal: the
    // warnings render for the row the golfer has open, and Save wrote every
    // assigned row, including rows they never opened.
    //
    // A wrong score nobody knows is wrong is worse than no score.

    Future<void> tapSave(WidgetTester tester, AppLocalizations l10n) async {
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.scoreScanSave),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('stops and asks when the card disagrees with itself', (
      tester,
    ) async {
      final scanned = ScannedScores(
        players: [
          row(
            holes: {1: 5, 2: 4},
            rowChecks: checks(writtenOut: 40, outAgrees: false),
          ),
        ],
      );

      await open(tester, scanned: scanned);
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tapSave(tester, l10n);

      expect(
        find.text(l10n.scoreScanDoubtTitle),
        findsOneWidget,
        reason: 'this is the defect: Save wrote numbers the app knew '
            'disagreed with the OUT total on the card',
      );
      // And the sheet is still there, on the numbers being questioned.
      expect(find.byType(ScoreScanSheet), findsOneWidget);
    });

    testWidgets('a hole the reader could not make out also counts', (
      tester,
    ) async {
      final scanned = ScannedScores(
        players: [
          row(holes: {1: 5, 2: null}),
        ],
      );

      await open(tester, scanned: scanned);
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tapSave(tester, l10n);

      expect(find.text(l10n.scoreScanDoubtTitle), findsOneWidget);
    });

    testWidgets('but a hole the golfer cleared does not — that was a choice', (
      tester,
    ) async {
      // Warning somebody about their own edit is nagging, and a dialog that
      // fires when it should not is a dialog people learn to tap through.
      final scanned = ScannedScores(
        players: [
          row(holes: {1: 5, 2: 4}, rowChecks: checks(writtenOut: 9)),
        ],
      );

      await open(tester, scanned: scanned);
      await tester.enterText(find.byKey(const Key('score-scan-hole-2')), '');
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tapSave(tester, l10n);

      expect(find.text(l10n.scoreScanDoubtTitle), findsNothing);
    });

    testWidgets('a clean reading saves without a question', (tester) async {
      final scanned = ScannedScores(
        players: [
          row(holes: {1: 5, 2: 4}, rowChecks: checks(writtenOut: 9)),
        ],
      );

      await open(tester, scanned: scanned);
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tapSave(tester, l10n);

      expect(find.text(l10n.scoreScanDoubtTitle), findsNothing);
      expect(find.byType(ScoreScanSheet), findsNothing);
    });

    testWidgets('and saying "vẫn lưu" saves it', (tester) async {
      final scanned = ScannedScores(
        players: [
          row(
            holes: {1: 5, 2: 4},
            rowChecks: checks(writtenOut: 40, outAgrees: false),
          ),
        ],
      );

      await open(tester, scanned: scanned);
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tapSave(tester, l10n);
      await tester.tap(find.text(l10n.scoreScanDoubtSaveAnyway));
      await tester.pumpAndSettle();

      expect(find.byType(ScoreScanSheet), findsNothing);
    });
  });
}
