// The scorecard is called the scorecard.
//
// Its AppBar title read `scorecardTitle` — "Gửi scorecard của sân" / "Submit
// the club's scorecard" — which is the name of a different screen entirely:
// the one where a golfer photographs the club's paper card at the clubhouse.
// A golfer standing on hole 3 entering their own score was on a screen
// announcing a submission flow they had not opened.
//
// It survived because the bar carries eight action icons on a phone and the
// title is squeezed out of the layout. Nothing on screen, so nobody looking
// at a screenshot could catch it — but the title is what VoiceOver reads, and
// what shows the moment the bar has room.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/screens/score/scorecard_screen.dart';

void main() {
  for (final locale in const [Locale('vi'), Locale('en')]) {
    testWidgets('in ${locale.languageCode}, the round scorecard is not the '
        'submission screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ScorecardScreen(
            flightId: 'round-1',
            holeIds: ['1', '2'],
            playerIds: ['me'],
            playerNames: {'me': 'Nghi'},
            holePars: {'1': 4, '2': 4},
          ),
        ),
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(locale);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final title = (appBar.title as Text?)?.data;

      expect(title, l10n.scorecardScreenTitle);
      expect(
        title,
        isNot(l10n.scorecardTitle),
        reason: 'that string belongs to the photo-submission screen',
      );
    });
  }
}
