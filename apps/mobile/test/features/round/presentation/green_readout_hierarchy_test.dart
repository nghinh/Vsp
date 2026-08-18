// Which of three distances is the one you club off.
//
// Front, centre and back were three identical rows on the Mục tiêu tab: the
// same 22pt figure, the same weight, the same colour. "Emphasised" existed and
// changed the colour of the *label*, leaving the three numbers
// indistinguishable from each other.
//
// A golfer reads this standing up, one-handed, in sun, with a club in the
// other hand, and plays the shot to the centre. Every rangefinder ever built
// leads with that number and prints the edges small — not as a house style but
// because one of the three is the decision and two are the bracket around it.
//
// The test is on sizes rather than on looks, because "the important number is
// bigger" is the whole design and it is exactly the kind of thing a later
// tidy-up flattens back to uniform rows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/hole_map/domain/green_distance_reading.dart';
import 'package:vsp_mobile/features/round/presentation/active_round_target_view.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';

double fontSizeOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  // 128 m front, 137 m centre, 146 m back — an ordinary approach, and three
  // numbers that cannot be confused for one another in the assertions.
  final reading = GreenDistanceReading(
    front: const MeasureLeg(
      kind: MeasureLegKind.fromGolfer,
      from: LatLng(latitude: 21.0, longitude: 105.0),
      to: LatLng(latitude: 21.001, longitude: 105.0),
      meters: 128,
      uncertaintyMeters: 4,
    ),
    centre: const MeasureLeg(
      kind: MeasureLegKind.fromGolfer,
      from: LatLng(latitude: 21.0, longitude: 105.0),
      to: LatLng(latitude: 21.001, longitude: 105.0),
      meters: 137,
      uncertaintyMeters: 4,
    ),
    back: const MeasureLeg(
      kind: MeasureLegKind.fromGolfer,
      from: LatLng(latitude: 21.0, longitude: 105.0),
      to: LatLng(latitude: 21.001, longitude: 105.0),
      meters: 146,
      uncertaintyMeters: 4,
    ),
  );

  Future<AppLocalizations> pumpReadout(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1290, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: VspTheme.dark(),
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GreenReadout(
            reading: reading,
            unit: DistanceUnit.meters,
            onToggleUnit: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.delegate.load(const Locale('vi'));
  }

  group('the green readout', () {
    testWidgets('shows all three distances', (tester) async {
      await pumpReadout(tester);

      expect(find.text('128 m'), findsOneWidget);
      expect(find.text('137 m'), findsOneWidget);
      expect(find.text('146 m'), findsOneWidget);
    });

    testWidgets('and the centre is the largest thing on it', (tester) async {
      await pumpReadout(tester);

      final centre = fontSizeOf(tester, '137 m');
      expect(centre, greaterThan(fontSizeOf(tester, '128 m')));
      expect(centre, greaterThan(fontSizeOf(tester, '146 m')));
    });

    testWidgets('by a margin a glance can act on', (tester) async {
      // Not "one point bigger". Three rows differing by a hair is what this
      // replaced — the distinction has to survive being looked at for half a
      // second in bright light.
      await pumpReadout(tester);

      expect(
        fontSizeOf(tester, '137 m'),
        greaterThanOrEqualTo(fontSizeOf(tester, '128 m') * 2),
      );
    });

    testWidgets('front and back stay the same size as each other', (
      tester,
    ) async {
      // They bracket the centre. One of them looking more important than the
      // other would be a claim about pin position this screen cannot make.
      await pumpReadout(tester);

      expect(fontSizeOf(tester, '128 m'), fontSizeOf(tester, '146 m'));
    });

    testWidgets('the figures are tabular, so they do not shuffle while '
        'walking', (tester) async {
      await pumpReadout(tester);

      final centre = tester.widget<Text>(find.text('137 m'));
      expect(
        centre.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });
}
