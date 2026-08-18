// What the conditions panel says first.
//
// The panel opened with three pieces of provenance — the source badge, the
// timestamp, and the measured-or-forecast chip — and put the wind under them.
// Wind is the only thing on this screen a golfer changes a club for; where the
// reading came from is a caveat about it. Provenance under the reading, not in
// front of it — the same order the hole map's traced-shapes note takes, and the
// same order the round summary takes with the course name under the score.
//
// This panel had no test at all before this file, which is how an ordering
// nobody chose survived: there was nothing to contradict.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/models/weather_snapshot.dart';
import 'package:vsp_mobile/domain/models/wind_data.dart';
import 'package:vsp_mobile/features/weather/presentation/widgets/weather_conditions_panel.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Five minutes before the test runs, not a date.
///
/// The panel prints age relative to now ("Updated 5 min ago"), so a fixed
/// timestamp makes the rendered text drift by the hour. It was written on
/// 17/8 and by 18/8 the reading was "Updated 18h ago" — which collides with
/// the 18.0 km/h wind this file is here to locate. A test that starts failing
/// because a day passed was never testing the ordering.
DateTime get _justNow =>
    DateTime.now().toUtc().subtract(const Duration(minutes: 5));

WeatherSnapshot snapshotWith({DataFreshness freshness = DataFreshness.fresh}) {
  final taken = _justNow;
  return WeatherSnapshot(
    id: 'w1',
    timestamp: taken,
    location: QualifiedLocation(
      latitude: 21.0384,
      longitude: 105.8915,
      accuracyMeters: 5,
      timestamp: taken,
      source: LocationSource.gps,
      isStale: false,
    ),
    temperature: const Temperature(value: 31, unit: 'C'),
    humidity: 74,
    condition: WeatherCondition.partly_cloudy,
    wind: const WindData(
      speed: 18,
      unit: WindSpeedUnit.kmh,
      direction: WindDirection.ne,
      degrees: 45,
    ),
    source: const WeatherSource(
      name: 'OpenWeatherMap',
      provider: 'openweathermap',
      measurementType: MeasurementType.forecast,
      verificationStatus: WeatherVerificationStatus.estimated,
    ),
    freshness: freshness,
  );
}

Future<void> pumpPanel(
  WidgetTester tester, {
  DataFreshness freshness = DataFreshness.fresh,
}) async {
  tester.view.physicalSize = const Size(1290, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: VspTheme.dark(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: WeatherConditionsPanel(
            snapshot: snapshotWith(freshness: freshness),
            onRetry: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The wind reading itself, not any line that happens to contain its digits.
final _wind = find.text('18.0 km/h');

void main() {
  group('the conditions panel', () {
    testWidgets('leads with the wind, not with where it came from', (
      tester,
    ) async {
      await pumpPanel(tester);

      final wind = tester.getTopLeft(_wind);
      final provenance = tester.getTopLeft(
        find.textContaining('OpenWeatherMap'),
      );
      expect(
        wind.dy,
        lessThan(provenance.dy),
        reason: 'the club is chosen off the wind, not off the provider name',
      );
    });

    testWidgets('still says where it came from', (tester) async {
      // Demoting provenance is not deleting it. A forecast presented as a
      // measurement is the failure this badge exists to prevent.
      await pumpPanel(tester);

      expect(find.textContaining('OpenWeatherMap'), findsWidgets);
    });

    testWidgets('and a stale reading warns above everything', (tester) async {
      // The one thing that outranks the wind: a number old enough to be
      // wrong. It stays at the top, because it is not a caveat about the
      // reading — it is a reason to distrust the whole panel.
      await pumpPanel(tester, freshness: DataFreshness.stale);

      final warning = tester.getTopLeft(find.byIcon(Icons.warning_amber_outlined).first);
      final wind = tester.getTopLeft(_wind);
      expect(warning.dy, lessThan(wind.dy));
    });
  });
}
