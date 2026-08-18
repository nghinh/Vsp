// The hole header, and the club name it was crushing.
//
// From a phone on Long Biên: the header read "Long Biên G…". The club name sat
// at the end of the header row behind a `Spacer`, and a Spacer and a Flexible
// in the same Row divide what is left between them — so the name got half the
// leftover width and was cut in half fighting the hole number, the par and the
// length for room they all needed.
//
// It is also the one thing in that header the golfer already knows, having
// just chosen it. So it moves to its own line: the numbers get the width, and
// the name gets enough of it to be a name.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A club whose name is longer than the width left over by a badge, a par and
/// a length — which is most Vietnamese clubs.
const _club = 'Long Biên Golf Course';

Future<void> pumpHeader(
  WidgetTester tester, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: VspTheme.dark(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: HoleHeader(
            courseName: _club,
            holeNumber: 1,
            par: 4,
            lengthMeters: 361,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('the club name', () {
    testWidgets('is shown in full rather than cut to a letter', (tester) async {
      await pumpHeader(tester);

      final text = tester.widget<Text>(find.text(_club));
      final painter = TextPainter(
        text: TextSpan(text: _club, style: text.style),
        textDirection: TextDirection.ltr,
      )..layout();

      final rendered = tester.getSize(find.text(_club));
      expect(
        rendered.width,
        greaterThanOrEqualTo(painter.width - 1),
        reason: 'the name was rendering as "Long Biên G…"',
      );
    });

    testWidgets('sits below the hole number, not beside it', (tester) async {
      await pumpHeader(tester);

      final name = tester.getTopLeft(find.text(_club));
      final hole = tester.getTopLeft(find.textContaining('1').first);
      expect(name.dy, greaterThan(hole.dy));
    });
  });

  group('the numbers a golfer reads', () {
    testWidgets('par and length are both there', (tester) async {
      await pumpHeader(tester);

      expect(find.textContaining('4'), findsWidgets);
      expect(find.textContaining('361'), findsWidgets);
    });
  });

  group('at a larger text size', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('${scale}× still fits', (tester) async {
        await pumpHeader(tester, textScale: scale);

        expect(tester.takeException(), isNull);
      });
    }
  });
}
