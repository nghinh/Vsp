// ScoreRowWidget — what a row may claim about par.
//
// Par 0 means "this device has no card for this hole", not a par of zero.
// The row once subtracted it anyway and filed a made par as "+4" in red —
// on the summary of a paired round whose back nine had no par mapping.
// These tests pin the rule: no par, no verdict.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/round/domain/score_entry.dart';
import 'package:vsp_mobile/features/round/presentation/widgets/score_row_widget.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

Widget _host(ScoreEntry entry) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ScoreRowWidget(entry: entry)),
  );
}

void main() {
  testWidgets('a known par renders the par and the verdict', (tester) async {
    await tester.pumpWidget(_host(
      const ScoreEntry(holeNumber: 3, par: 4, strokes: 5),
    ));

    expect(find.textContaining('4'), findsWidgets);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('an unknown par says nothing about par', (tester) async {
    await tester.pumpWidget(_host(
      const ScoreEntry(holeNumber: 10, par: 0, strokes: 4),
    ));

    // Strokes still shown; no "Par 0", no "+4" verdict badge.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('+4'), findsNothing);
    expect(find.textContaining('Par 0'), findsNothing);
  });
}
