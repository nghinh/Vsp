// The start-hole sheet fits on the phone it opens on.
//
// Found by the tour that photographs a round, which could not get past it: the
// sheet came back striped — "BOTTOM OVERFLOWED BY 50 PIXELS" — with the last
// row of hole numbers under the warning and "Xác nhận" past the edge of what
// can be pressed. So a golfer could open the sheet, choose the 1st, and have
// no way to confirm it; the round then started on whichever hole the form had
// suggested, which after midday is the 10th.
//
// Two causes. The grid was given a hard 180 logical pixels for three rows of
// six that need about 184 of them, and the column above it had no way to
// scroll when the total came to more than the sheet's share of the screen. On
// an eighteen with the front-nine/back-nine options above the grid there is no
// height at which both fit every phone, so the sheet scrolls and the grid
// sizes itself.
//
// An overflow is not a cosmetic complaint here. Flutter clips what overflows,
// and a clipped button is a button that does not take a tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/widgets/hole_picker.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

Future<void> _openTheSheet(
  WidgetTester tester, {
  required int holeCount,
  required Size phone,
}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HolePicker(
          selectedHole: 10,
          holeCount: holeCount,
          suggestedHole: 10,
          onSelected: (_, __) {},
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.textContaining('Gợi ý: Hố'));
  await tester.pumpAndSettle();
}

void main() {
  // An iPhone 17 Pro, which is what the tour photographs on, and an iPhone SE,
  // which is the shortest screen this app supports. The 17 Pro overflowed; a
  // sheet that only fits tall phones is a sheet that does not fit.
  const phones = <String, Size>{
    'iPhone 17 Pro': Size(1206, 2622),
    'iPhone SE': Size(750, 1334),
  };

  for (final phone in phones.entries) {
    testWidgets('on a ${phone.key} nothing overflows', (tester) async {
      await _openTheSheet(tester, holeCount: 18, phone: phone.value);

      expect(
        tester.takeException(),
        isNull,
        reason: 'a RenderFlex overflow clips whatever is past the edge, and '
            'what was past the edge here was the confirm button',
      );
    });

    testWidgets('and the confirm button can be pressed on a ${phone.key}', (
      tester,
    ) async {
      // The failure this file exists for was not "it looks wrong". It was that
      // the choice could not be committed.
      var confirmed = 0;
      tester.view.physicalSize = phone.value;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HolePicker(
              selectedHole: 10,
              holeCount: 18,
              suggestedHole: 10,
              onSelected: (hole, _) => confirmed = hole,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('Gợi ý: Hố'));
      await tester.pumpAndSettle();

      // Choose the 1st, the way the tour does.
      final one = find.descendant(
        of: find.byType(GridView),
        matching: find.text('1'),
      );
      await tester.ensureVisible(one.first);
      await tester.pumpAndSettle();
      await tester.tap(one.first);
      await tester.pumpAndSettle();

      final confirm = find.widgetWithText(FilledButton, 'Xác nhận');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(confirmed, 1);
    });
  }

  testWidgets('a nine still fits, and offers no front/back split', (
    tester,
  ) async {
    // Splitting a nine into a front and a back nine is not a thing a golfer
    // can do, and the rows that offer it are half of what made the eighteen
    // overflow.
    await _openTheSheet(
      tester,
      holeCount: 9,
      phone: const Size(750, 1334),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('9 hố đầu'), findsNothing);
    expect(find.descendant(
      of: find.byType(GridView),
      matching: find.text('9'),
    ), findsOneWidget);
  });

  testWidgets('the answer is reported once, with both halves of it', (
    tester,
  ) async {
    // This is the defect the tour actually hit, behind the overflow. The sheet
    // used to report through two callbacks, and the form rebuilt the second
    // one's event from `state.startHole` — the state captured before the
    // first. So confirming "the 1st" sent hole 1 and then, immediately behind
    // it, the hole the golfer had just changed away from. The chip went back
    // to "Gợi ý: Hố 10" and the round began at the turn.
    //
    // One report is what makes that impossible to reintroduce: there is no
    // second event to carry a stale value.
    final reports = <(int, String?)>[];
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HolePicker(
            selectedHole: 10,
            holeCount: 18,
            suggestedHole: 10,
            onSelected: (hole, holes) => reports.add((hole, holes)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('Gợi ý: Hố'));
    await tester.pumpAndSettle();

    final one = find.descendant(
      of: find.byType(GridView),
      matching: find.text('1'),
    );
    await tester.ensureVisible(one.first);
    await tester.pumpAndSettle();
    await tester.tap(one.first);
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(FilledButton, 'Xác nhận');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(reports, hasLength(1), reason: 'a second report can only disagree');
    expect(reports.single.$1, 1);
    expect(
      reports.single.$2,
      isNull,
      reason: 'a numbered hole is not a front or back nine',
    );
  });

  testWidgets('and choosing the back nine reports both together', (
    tester,
  ) async {
    final reports = <(int, String?)>[];
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HolePicker(
            selectedHole: 1,
            holeCount: 18,
            suggestedHole: 1,
            onSelected: (hole, holes) => reports.add((hole, holes)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('Gợi ý: Hố'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('9 hố sau'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Xác nhận');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(reports, hasLength(1));
    expect(reports.single, (10, 'back9'));
  });
}
