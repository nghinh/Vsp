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

  Future<void> pumpPanel(WidgetTester tester, MeasureState state) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: MeasurePanel(
            state: state,
            onUndo: () {},
            onClear: () {},
            onToggleUnit: () {},
          ),
        ),
      ),
    );
  }

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
}
