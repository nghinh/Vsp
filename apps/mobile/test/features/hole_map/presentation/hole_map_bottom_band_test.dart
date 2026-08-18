// Nothing at the foot of the hole map covers anything else at the foot of it.
//
// The bottom of this map holds two things a golfer needs at once: the
// distances to what is ahead of them, on the left, and the map/measure switch
// with the layer control, on the right. They were three separately positioned
// columns, and _MapCorner's own note says what that cannot promise — a wide
// panel on the left prints underneath one on the right at the same height.
//
// It had already happened once and been "fixed" by moving the switch from the
// centre of the foot to the bottom-right at a hardcoded 72 from the bottom.
// The first screenshot ever taken of this screen shows it still sitting across
// the fourth bunker row — "270 / 3" — and across the caveat saying a model
// drew the shapes underneath.
//
// Reading a distance is why the screen is open. A control printed over it is
// not a cosmetic complaint, and it is the same defect a golfer once reported
// as "các khối che nhau".

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/data_freshness.dart'
    show VerificationStatus;
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/feature_distance_panel.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/hole_map_view.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/layer_toggle_panel.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

MapLayerEntity _square(MapLayerType type, double lat, double lng) {
  const d = 0.00015;
  return MapLayerEntity(
    type: type,
    format: LayerGeometryFormat.geoJson,
    geoJson: {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [lng - d, lat - d],
                [lng + d, lat - d],
                [lng + d, lat + d],
                [lng - d, lat + d],
                [lng - d, lat - d],
              ],
            ],
          },
          'properties': <String, dynamic>{},
        },
      ],
    },
    style: const LayerStyle(),
  );
}

const _surveyed = HoleDataProvenance(
  accuracyClass: AccuracyClass.classC,
  verificationStatus: VerificationStatus.verified,
);

/// Long Biên's 1st: a tee, a fairway, bunkers to carry, and a green — enough
/// for the "ahead" panel to have rows in it and for the caveat to be shown.
HoleMapReady _hole() => HoleMapReady(
  holeMap: HoleMapEntity(
    courseId: '1351',
    courseName: 'Long Biên Golf Course',
    holeNumber: 1,
    par: 4,
    provenance: _surveyed,
    layers: {
      MapLayerType.tee: _square(MapLayerType.tee, 21.036720, 105.892017),
      MapLayerType.fairway: _square(MapLayerType.fairway, 21.038000, 105.892017),
      MapLayerType.bunker: _square(MapLayerType.bunker, 21.038600, 105.892017),
      MapLayerType.green: _square(MapLayerType.green, 21.039400, 105.892017),
    },
  ),
  layerVisibility: const {
    'tee': true,
    'fairway': true,
    'bunker': true,
    'green': true,
  },
  tracedShapesUnverified: true,
);

Future<void> _pump(WidgetTester tester, {double textScale = 1.0}) async {
  // 402 dp wide — an iPhone 17, and the width the tour photographs.
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: HoleMapView(
            state: _hole(),
            imageryConfig: SatelliteImageryConfig.unavailable,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    BasemapPreference.resetForTesting();
    BasemapPreference.choose(BasemapMode.courseMap);
  });
  tearDown(BasemapPreference.resetForTesting);

  // Edges, not rectangles.
  //
  // The first version of this test asked whether the two rectangles intersect,
  // and it passed against the broken layout at all three text sizes: whether
  // they collide depends on how many panels happen to be stacked in the left
  // column, so a fixture without a GPS fix pushed the distances clear of the
  // switch by luck. What went wrong on the phone was that the left column
  // reached 280 into a right column starting at 75 — the columns overlap as
  // columns, and which rows land on each other is the accident on top.
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('at ${scale}× text the left of the map\'s foot ends before the '
        'right begins', (tester) async {
      await _pump(tester, textScale: scale);

      final ahead = find.byType(FeatureDistancePanel);
      expect(
        ahead,
        findsOneWidget,
        reason: 'without the panel there is nothing to be covered',
      );
      final aheadRect = tester.getRect(ahead);

      final layers = find.byType(LayerTogglePanel);
      expect(layers, findsOneWidget);
      expect(
        aheadRect.right,
        lessThanOrEqualTo(tester.getRect(layers).left),
        reason:
            'a control that starts before the distances end will print over '
            'them as soon as the two are at the same height',
      );

      // The switch is not in either column — it has a line above them, because
      // it and the distances each want about half the phone and neither reads
      // as anything at half of that.
      final toggle = find.byType(BasemapToggle);
      expect(toggle, findsOneWidget);
      expect(
        tester.getRect(toggle).bottom,
        lessThanOrEqualTo(aheadRect.top),
        reason: 'the switch sits above the distances, not beside them',
      );
    });
  }

  testWidgets('and the switch keeps its words', (tester) async {
    await _pump(tester);

    // Asked of the thing that paints the words, not of the widget holding
    // them. `Text.data` is the whole string whether or not any of it fitted —
    // the "…" is drawn, never stored — so a test reading `data` passes on a
    // switch that says "B…" and "Th…". `didExceedMaxLines` is what the
    // paragraph actually did.
    final labels = find.descendant(
      of: find.byType(BasemapToggle),
      matching: find.byType(Text),
    );
    expect(labels, findsWidgets);

    for (var i = 0; i < labels.evaluate().length; i++) {
      final paragraph = tester.renderObject<RenderParagraph>(labels.at(i));
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason:
            '"${(paragraph.text as TextSpan).text}" did not fit, so the golfer '
            'reads an abbreviation of it — which is what the switch came back '
            'as when it was made to share the row with the distances',
      );
    }
  });
}
