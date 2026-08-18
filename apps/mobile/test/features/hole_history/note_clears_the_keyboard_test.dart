// The keyboard does not sit on top of the button that saves the note.
//
// Reported from the course with a screenshot of the 17th: the note sheet open,
// the keyboard up, and "Lưu ghi chú" behind it — a glow of orange showing under
// the last row of keys. A note could be typed and not saved.
//
// The sheet already had code for this, and it could not work. The padding was
// applied where the sheet is *opened*, reading `MediaQuery.of(context)` from
// the caller's context — a scorecard that is not part of the sheet's route.
// That value is read once, when the sheet is built, and the keyboard is not up
// yet: it was zero then and stayed zero, because nothing in the sheet ever
// depended on the insets and so nothing rebuilt when they changed. The comment
// beside it read "Above the keyboard, so the note field is not covered while
// typing".
//
// The insets are now read inside the sheet, with `viewInsetsOf`, which takes
// the dependency precisely enough that this widget rebuilds when the keyboard
// arrives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/hole_history/presentation/hole_history_sheet.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// The sheet on a phone, with a keyboard of [keyboard] logical pixels up.
///
/// An iPhone's Vietnamese keyboard is a little over a third of the screen; 336
/// is what the reported screenshot shows on a 17 Pro.
Future<void> _pump(WidgetTester tester, {double keyboard = 0}) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(430, 932),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        // `resizeToAvoidBottomInset: false`, and that is the whole point of
        // the harness. A Scaffold lifts its own body clear of the keyboard,
        // so with the default this test passed against the broken sheet: the
        // scaffold was doing the work and the assertion proved nothing. A
        // modal bottom sheet is a route, not a scaffold body — nothing lifts
        // it but itself.
        child: const Scaffold(
          resizeToAvoidBottomInset: false,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: HoleHistorySheet(courseId: '1351', holeNumber: 17),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the save button clears the keyboard', (tester) async {
    const keyboard = 336.0;
    await _pump(tester, keyboard: keyboard);

    final save = find.byKey(const Key('hole_note_save'));
    expect(save, findsOneWidget);

    final rect = tester.getRect(save);
    expect(
      rect.bottom,
      lessThanOrEqualTo(932 - keyboard),
      reason: 'the button is under the keyboard, which is exactly what the '
          'screenshot from the 17th shows',
    );
  });

  testWidgets('and so does the field being typed into', (tester) async {
    const keyboard = 336.0;
    await _pump(tester, keyboard: keyboard);

    final field = find.byKey(const Key('hole_note_field'));
    expect(field, findsOneWidget);
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(932 - keyboard));
  });

  testWidgets('with no keyboard the sheet does not float', (tester) async {
    // The padding is the keyboard's height and nothing else. A sheet that
    // reserved room for a keyboard that is not there would sit above the
    // bottom of the screen for no reason.
    await _pump(tester);
    final withoutKeyboard = tester.getRect(
      find.byKey(const Key('hole_note_save')),
    );

    await _pump(tester, keyboard: 336);
    final withKeyboard = tester.getRect(
      find.byKey(const Key('hole_note_save')),
    );

    expect(
      withoutKeyboard.bottom - withKeyboard.bottom,
      closeTo(336, 1),
      reason: 'the sheet rises by exactly the keyboard, no more and no less',
    );
  });
}
