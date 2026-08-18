// How much of the screen the picture gets.
//
// The map tab used to spend its height on chrome. Above the imagery sat a
// full-width bar that, on most holes, held nothing but the two-state basemap
// switch, and on an unsurveyed hole held a banner saying so. Below it the
// readout was intrinsic and the map was whatever was left, so every extra
// measured leg took another bite out of the imagery — a golfer laying out five
// legs read them over a strip of picture.
//
// Both are layout decisions with no natural test, which is why they drifted.
// These pin the two rules: chrome floats on the imagery instead of displacing
// it, and the readout has a ceiling it scrolls past rather than growing
// through.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/measure_panel.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// The ceiling the view promises the readout, as a share of its own height.
const double _panelMaxFraction = 0.42;

Future<MeasureCubit> _pump(
  WidgetTester tester, {
  int points = 0,
  Widget? mapOverlay,
}) async {
  // 480 × 1000 dp, so the fractions below are exact rather than nearly.
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final cubit = MeasureCubit();
  addTearDown(cubit.close);

  // Spread far enough apart that each leg is a distinct row with a distinct
  // number; a pile of identical rows would not exercise a growing panel.
  for (var i = 0; i < points; i++) {
    cubit.addPoint(LatLng(latitude: 10.70 + i * 0.001, longitude: 106.70));
  }

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<MeasureCubit>.value(
          value: cubit,
          child: SatelliteMeasureView(
            config: SatelliteImageryConfig.unavailable,
            mapOverlay: mapOverlay,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

/// Share of the view the readout actually takes.
///
/// Measured on the readout's outer box, not the panel inside it: past the cap
/// the panel keeps its intrinsic height and scrolls, so measuring the panel
/// would answer how tall the content is rather than how much screen it took.
double _panelShare(WidgetTester tester) {
  final view = tester.getSize(find.byType(SatelliteMeasureView));
  final readout = tester.getSize(find.byKey(SatelliteMeasureView.readoutKey));
  return readout.height / view.height;
}

void main() {
  group('the readout has a ceiling', () {
    testWidgets('an empty measurement leaves the map most of the screen', (
      tester,
    ) async {
      await _pump(tester);

      expect(_panelShare(tester), lessThanOrEqualTo(_panelMaxFraction));
    });

    testWidgets('a long measurement scrolls instead of squeezing the map', (
      tester,
    ) async {
      // Eight points is nine rows plus a total — comfortably more than the
      // panel can show, and exactly the case that used to leave the imagery a
      // strip.
      await _pump(tester, points: 8);

      expect(_panelShare(tester), lessThanOrEqualTo(_panelMaxFraction));
      // Capped, not clipped: the rows past the fold are reachable.
      expect(
        find.descendant(
          of: find.byType(MeasurePanel),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
        reason: 'the panel itself does not scroll — the view scrolls it',
      );
      expect(
        find.ancestor(
          of: find.byType(MeasurePanel),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the ceiling holds as the measurement grows', (tester) async {
      final cubit = await _pump(tester);
      final empty = _panelShare(tester);

      for (var i = 0; i < 8; i++) {
        cubit.addPoint(LatLng(latitude: 10.70 + i * 0.001, longitude: 106.70));
      }
      await tester.pump();

      // It may grow — an empty panel is short — but never past the ceiling.
      expect(_panelShare(tester), greaterThanOrEqualTo(empty));
      expect(_panelShare(tester), lessThanOrEqualTo(_panelMaxFraction));
    });
  });

  group('chrome floats on the imagery', () {
    testWidgets('the unsurveyed banner takes no height from the map', (
      tester,
    ) async {
      // The overlay is handed the whole map area and the caller says where in
      // it to sit — which is how a caller can put a control in a real bottom
      // corner. It used to be a strip along the top, and a caller that asked
      // for bottom-left got the bottom of the strip: the club-plan button
      // printed across the banner at the top of the screen.
      await _pump(
        tester,
        mapOverlay: const Align(
          alignment: Alignment.topLeft,
          child: NoGeometryBanner(),
        ),
      );

      // Inside the view, over the map — not a band stacked above it. A banner
      // that displaced the imagery would sit above the map's top edge.
      final banner = tester.getRect(find.byType(NoGeometryBanner));
      final view = tester.getRect(find.byType(SatelliteMeasureView));
      final panel = tester.getRect(find.byType(MeasurePanel));

      expect(banner.top, greaterThanOrEqualTo(view.top));
      expect(banner.bottom, lessThan(panel.top));

      // And it is a note, not a curtain. Four lines of text used to be laid
      // across the full width of the only thing on this screen worth looking
      // at.
      expect(banner.width, lessThan(view.width));
      expect(banner.height, lessThan(view.height / 2));
    });

    testWidgets('a view given no chrome draws none', (tester) async {
      await _pump(tester);

      expect(find.byType(NoGeometryBanner), findsNothing);
    });
  });
}
