// Tests for the panel a golfer reads before choosing a club.
//
// All three green distances used to fall back to a `_placeholderMeasurement`
// of zero metres carrying `DistanceSource.official` and confidence 0. So a hole
// whose green geometry was missing rendered "0 m" under an Official badge —
// on the one screen where being confidently wrong costs a shot.
//
// A missing distance is now shown as missing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/application/distance/distance_state.dart';
import 'package:vsp_mobile/domain/value_objects/distance_measurement.dart';
import 'package:vsp_mobile/domain/value_objects/distance_type.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/widgets/distance/primary_distance_panel.dart';

DistanceMeasurement _measurement(double meters, DistanceType type) =>
    DistanceMeasurement(
      valueMeters: meters,
      type: type,
      source: DistanceSource.official,
      timestamp: DateTime.utc(2026, 8, 6),
      gpsAccuracyMeters: 4,
      confidence: 0.9,
    );

Future<AppLocalizations> _pump(
  WidgetTester tester,
  Map<DistanceType, DistanceMeasurement> greens,
) async {
  tester.view.physicalSize = const Size(1440, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PrimaryDistancePanel(
          state: DistanceState(
            status: DistanceStatus.ready,
            golferPosition: const LatLng(latitude: 10.7, longitude: 106.7),
            gpsAccuracyMeters: 4,
            timestamp: DateTime.utc(2026, 8, 6),
            greenDistances: greens,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('shows the distances it has', (tester) async {
    await _pump(tester, {
      DistanceType.frontGreen: _measurement(138, DistanceType.frontGreen),
      DistanceType.centerGreen: _measurement(147, DistanceType.centerGreen),
      DistanceType.backGreen: _measurement(156, DistanceType.backGreen),
    });

    expect(find.textContaining('138'), findsWidgets);
    expect(find.textContaining('147'), findsWidgets);
    expect(find.textContaining('156'), findsWidgets);
  });

  testWidgets('never renders a missing distance as zero', (tester) async {
    // The centre is known, the front and back are not — the ordinary case on
    // a hole with a green point but no green outline.
    await _pump(tester, {
      DistanceType.centerGreen: _measurement(147, DistanceType.centerGreen),
    });

    expect(find.textContaining('147'), findsWidgets);
    // "0" was previously rendered three times over, badged Official.
    expect(find.text('0'), findsNothing);
    expect(find.textContaining('0 m'), findsNothing);
    expect(find.textContaining('0 yd'), findsNothing);
    // An em dash is the honest answer for a distance the app does not have.
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('says there is no hole data rather than three zeros', (
    tester,
  ) async {
    final l10n = await _pump(tester, const {});

    expect(find.text(l10n.distanceNoHoleData), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('announces a missing distance to a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final l10n = await _pump(tester, {
      DistanceType.centerGreen: _measurement(147, DistanceType.centerGreen),
    });

    // Color and a dash are not enough on their own — UX-DR5.
    expect(
      find.bySemanticsLabel(
        RegExp(
          RegExp.escape(l10n.distanceUnavailableSemantics(l10n.distanceFront)),
        ),
      ),
      findsOneWidget,
    );

    semantics.dispose();
  });
}
