// One fix, one grade — and a distance that is not a golf distance.
//
// Two things this panel did, both visible in one screenshot from a phone on
// Long Biên's 1st:
//
//   GPS yếu ±23 yd          <- the chip
//   ⚠ Tín hiệu GPS yếu…     <- the sentence under it, saying it again
//   Từ bạn tới green  6.0 mi ±36 yd
//
// The chip grades accuracy on 10 / 20 m; the sentence fired over 10 m flat. So
// between 11 and 19 m the screen printed "GPS khá" and "GPS yếu" about the
// same number, and over 20 m it printed the same verdict twice. And the last
// line quoted a six-mile walk as the shot in front of the golfer, to the yard.

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
  const golfer = LatLng(latitude: 10.8, longitude: 106.7);

  QualifiedLocation fixWith(double accuracyMeters) => QualifiedLocation(
    latitude: golfer.latitude,
    longitude: golfer.longitude,
    accuracyMeters: accuracyMeters,
    timestamp: DateTime(2026, 8, 17, 6),
    source: LocationSource.gps,
    isStale: false,
  );

  /// A green [metres] north of the golfer, so the panel computes the
  /// golfer-to-green leg itself rather than measuring between dropped points.
  MeasureAnchor greenAway(double metres) => MeasureAnchor(
    position: LatLng(
      latitude: golfer.latitude + metres / 111320.0,
      longitude: golfer.longitude,
    ),
    isSurveyed: false,
  );

  MeasureState stateWith({
    required QualifiedLocation origin,
    MeasureAnchor? green,
    List<MeasurePoint> withPoints = const [],
  }) => MeasureState(
    points: withPoints,
    origin: origin,
    green: green,
    unit: DistanceUnit.meters,
    result: calculator.compute(
      points: withPoints,
      origin: origin,
      green: green,
    ),
  );

  Future<AppLocalizations> pumpPanel(
    WidgetTester tester,
    MeasureState state,
  ) async {
    await tester.pumpWidget(
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
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  group('one fix gets one grade', () {
    testWidgets('a fix the chip calls fair is not called weak underneath', (
      tester,
    ) async {
      // 15 m: over the old sentence's 10 m threshold, under the chip's 20 m.
      // This is the band where the two graders contradicted each other.
      final l10n = await pumpPanel(
        tester,
        stateWith(origin: fixWith(15), green: greenAway(140)),
      );

      expect(find.text(l10n.measureWeakFix), findsNothing);
    });

    testWidgets('a fix the chip calls weak says once what to do about it', (
      tester,
    ) async {
      final l10n = await pumpPanel(
        tester,
        stateWith(origin: fixWith(25), green: greenAway(140)),
      );

      // Once. The chip carries the verdict, this carries the consequence.
      expect(find.text(l10n.measureWeakFix), findsOneWidget);
    });

    testWidgets('a good fix says nothing at all', (tester) async {
      final l10n = await pumpPanel(
        tester,
        stateWith(origin: fixWith(4), green: greenAway(140)),
      );

      expect(find.text(l10n.measureWeakFix), findsNothing);
      expect(find.text(l10n.measureStaleFix), findsNothing);
    });
  });

  group('a green further away than any hole is long', () {
    testWidgets('is not quoted as the shot in front of the golfer', (
      tester,
    ) async {
      final l10n = await pumpPanel(
        tester,
        // ~9.7 km — the golfer at home, looking at tomorrow's course.
        stateWith(origin: fixWith(6), green: greenAway(9700)),
      );

      expect(find.text(l10n.measureYouToGreen), findsNothing);
    });

    testWidgets('says where the golfer is instead', (tester) async {
      await pumpPanel(
        tester,
        stateWith(origin: fixWith(6), green: greenAway(9700)),
      );

      expect(find.textContaining('from this hole'), findsOneWidget);
    });

    testWidgets('and a green on the hole is still a yardage', (tester) async {
      // 140 m: an approach. Nothing here should change for the golfer who is
      // actually standing on the hole, which is the whole point.
      final l10n = await pumpPanel(
        tester,
        stateWith(origin: fixWith(6), green: greenAway(140)),
      );

      expect(find.text(l10n.measureYouToGreen), findsOneWidget);
      expect(find.textContaining('from this hole'), findsNothing);
    });

    testWidgets('the boundary is a hole length, not a walking distance', (
      tester,
    ) async {
      // 900 m: longer than all but a handful of holes ever built, and still a
      // hole. The rule exists to catch "this cannot be on this hole", not to
      // decide how far is too far to care about.
      final l10n = await pumpPanel(
        tester,
        stateWith(origin: fixWith(6), green: greenAway(900)),
      );

      expect(find.text(l10n.measureYouToGreen), findsOneWidget);
    });
  });
}
