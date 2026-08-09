// MeasurePanel Widget Tests — VSP Mobile App
//
// The panel's job is to be honest. These tests pin the honesty:
// a bad fix must say it is bad, an estimated green must say it is estimated,
// and every distance must carry its tolerance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/measure_calculator.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_state.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/measure_panel.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  const calculator = MeasureCalculator();
  const base = LatLng(latitude: 10.8, longitude: 106.7);

  QualifiedLocation fix({double? accuracy = 4, bool stale = false}) {
    return QualifiedLocation(
      latitude: base.latitude,
      longitude: base.longitude,
      accuracyMeters: accuracy,
      timestamp: DateTime(2026, 8, 5, 9),
      source: LocationSource.gps,
      isStale: stale,
    );
  }

  final points = [
    const MeasurePoint(
      id: 'a',
      position: LatLng(latitude: 10.801, longitude: 106.7),
    ),
  ];

  MeasureState stateWith({
    QualifiedLocation? origin,
    MeasureAnchor? green,
    DistanceUnit unit = DistanceUnit.meters,
    List<MeasurePoint> withPoints = const [],
  }) {
    return MeasureState(
      points: withPoints,
      origin: origin,
      green: green,
      unit: unit,
      result: calculator.compute(
        points: withPoints,
        origin: origin,
        green: green,
      ),
    );
  }

  Future<void> pumpPanel(
    WidgetTester tester,
    MeasureState state, {
    bool imageryAvailable = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: MeasurePanel(
            state: state,
            imageryAvailable: imageryAvailable,
            onUndo: () {},
            onClear: () {},
            onToggleUnit: () {},
          ),
        ),
      ),
    );
  }

  const estimatedGreen = MeasureAnchor(
    position: LatLng(latitude: 10.803, longitude: 106.7),
    isSurveyed: false,
  );

  testWidgets('says so plainly when there is no GPS fix', (tester) async {
    await pumpPanel(tester, stateWith(withPoints: points));

    expect(
      find.textContaining('No GPS fix'),
      findsWidgets,
      reason: 'a measurement with no origin must not look complete',
    );
  });

  testWidgets('warns on a weak fix rather than quoting it plainly',
      (tester) async {
    await pumpPanel(
      tester,
      stateWith(origin: fix(accuracy: 30), withPoints: points),
    );

    expect(find.textContaining('Weak GPS fix'), findsOneWidget);
    expect(find.textContaining('GPS Poor'), findsOneWidget);
    expect(find.text('±30m'), findsOneWidget);
  });

  testWidgets('warns when the fix is stale', (tester) async {
    await pumpPanel(
      tester,
      stateWith(origin: fix(stale: true), withPoints: points),
    );

    expect(find.textContaining('out of date'), findsOneWidget);
  });

  testWidgets('renders the distance with its tolerance in metres',
      (tester) async {
    await pumpPanel(tester, stateWith(origin: fix(), withPoints: points));

    expect(find.text('From you'), findsOneWidget);
    expect(find.text('111 m'), findsOneWidget);
    // sqrt(4² + 5²) ≈ 6.4, rounded up.
    expect(find.text('±7 m'), findsOneWidget);
  });

  testWidgets('respects a yards preference', (tester) async {
    await pumpPanel(
      tester,
      stateWith(
        origin: fix(),
        withPoints: points,
        unit: DistanceUnit.yards,
      ),
    );

    expect(find.text('122 yd'), findsOneWidget);
    expect(find.text('yd'), findsOneWidget);
  });

  testWidgets('flags an estimated green', (tester) async {
    await pumpPanel(
      tester,
      stateWith(
        origin: fix(),
        withPoints: points,
        green: const MeasureAnchor(
          position: LatLng(latitude: 10.803, longitude: 106.7),
          isSurveyed: false,
        ),
      ),
    );

    expect(find.textContaining('estimated'), findsOneWidget);
    expect(find.text('On to green'), findsOneWidget);
  });

  testWidgets('says when the hole has no green position at all',
      (tester) async {
    await pumpPanel(tester, stateWith(origin: fix(), withPoints: points));

    expect(find.textContaining('No green position'), findsOneWidget);
  });

  testWidgets('shows the empty state before anything is tapped',
      (tester) async {
    await pumpPanel(tester, stateWith(origin: fix()));

    expect(find.text('Measure any distance'), findsOneWidget);
    expect(find.text('No points'), findsOneWidget);
  });

  testWidgets('shows a total once there is more than one leg', (tester) async {
    final multi = [
      ...points,
      const MeasurePoint(
        id: 'b',
        position: LatLng(latitude: 10.802, longitude: 106.7),
      ),
    ];
    await pumpPanel(tester, stateWith(origin: fix(), withPoints: multi));

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('2 points'), findsOneWidget);
  });

  // ─── The green reading before the first tap ────────────────────────────────

  testWidgets('answers "how far to the green" before anything is dropped',
      (tester) async {
    await pumpPanel(tester, stateWith(origin: fix(), green: estimatedGreen));

    // The question a golfer walking to their ball actually has. It needs no
    // taps, so it is not withheld until they make one — and the empty-state
    // hint still invites them to measure something else.
    expect(find.text('From you to the green'), findsOneWidget);
    expect(find.text('334 m'), findsOneWidget);
    expect(find.text('Measure any distance'), findsOneWidget);
    // Measured to an unverified green, so it must not look confident:
    // the 25 m the green is worth, quadrature-combined with the 4 m fix.
    expect(find.text('±26 m'), findsOneWidget);
    expect(find.textContaining('estimated'), findsOneWidget);
  });

  testWidgets('hands the run-on over to a dropped point once there is one',
      (tester) async {
    await pumpPanel(
      tester,
      stateWith(origin: fix(), green: estimatedGreen, withPoints: points),
    );

    expect(find.text('On to green'), findsOneWidget);
    expect(find.text('From you to the green'), findsNothing);
  });

  testWidgets('has nothing to measure to the green from with no fix',
      (tester) async {
    await pumpPanel(tester, stateWith(green: estimatedGreen));

    expect(find.text('From you to the green'), findsNothing);
    expect(find.textContaining('No GPS fix'), findsWidgets);
  });

  testWidgets('still flags the estimated green when the fix is missing',
      (tester) async {
    // The run-on from a dropped point does not need GPS, so a missing fix
    // must not take the green's provenance off screen with it.
    await pumpPanel(
      tester,
      stateWith(green: estimatedGreen, withPoints: points),
    );

    expect(find.text('On to green'), findsOneWidget);
    expect(find.textContaining('estimated'), findsOneWidget);
    expect(find.textContaining('No GPS fix'), findsWidgets);
  });

  // ─── A build with no imagery ───────────────────────────────────────────────

  testWidgets('does not tell the golfer to tap an image that is not there',
      (tester) async {
    await pumpPanel(
      tester,
      stateWith(origin: fix()),
      imageryAvailable: false,
    );

    expect(find.textContaining('satellite image'), findsNothing);
    expect(find.textContaining('no imagery to aim at'), findsOneWidget);
    // The tool itself is unchanged — it never needed pictures.
    expect(find.text('Measure any distance'), findsOneWidget);
  });

  testWidgets('measures exactly the same without imagery', (tester) async {
    await pumpPanel(
      tester,
      stateWith(origin: fix(), green: estimatedGreen, withPoints: points),
      imageryAvailable: false,
    );

    expect(find.text('From you'), findsOneWidget);
    expect(find.text('111 m'), findsOneWidget);
    expect(find.text('On to green'), findsOneWidget);
  });
}
