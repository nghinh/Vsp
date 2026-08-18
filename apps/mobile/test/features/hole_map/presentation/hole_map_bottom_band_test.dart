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
import 'package:vsp_mobile/features/basemap/presentation/widgets/map_data_attribution.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';
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

      // The caveat is what occupies the left column now. The list of what is
      // ahead moved onto the shapes themselves, where a golfer can tell which
      // blob the number belongs to.
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      final ahead = find.text(l10n.mapTracedShapes);
      expect(
        ahead,
        findsOneWidget,
        reason: 'without something in the left column nothing can be covered',
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

      // The switch lives in the right column, icons only, so it fits beside
      // the distances instead of taking a line of its own. It had one for a
      // while, and a line above the columns floats upward as they grow — with
      // the ahead panel, the caveat and the attribution stacked it ended up in
      // the middle of the map.
      final toggle = find.byType(BasemapToggle);
      expect(toggle, findsOneWidget);
      expect(
        aheadRect.right,
        lessThanOrEqualTo(tester.getRect(toggle).left),
        reason: 'the switch is beside the distances, never over them',
      );
    });
  }

  testWidgets('the switch still says what it is, to a screen reader', (
    tester,
  ) async {
    // Icons only is a decision about width, not about meaning. Made to share
    // a row with the distances it once came back reading "B…" and "Th…", which
    // is not a control; dropping the glyphs and keeping the sentence is the
    // trade that works. A screen reader must still hear it.
    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(
      find.bySemanticsLabel(l10n.basemapSwitchToCourseMap),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(l10n.basemapSwitchToMeasure), findsWidgets);

    // And nothing it does draw is clipped.
    final labels = find.descendant(
      of: find.byType(BasemapToggle),
      matching: find.byType(Text),
    );
    for (var i = 0; i < labels.evaluate().length; i++) {
      final paragraph = tester.renderObject<RenderParagraph>(labels.at(i));
      expect(paragraph.didExceedMaxLines, isFalse);
    }
  });

  testWidgets('the legal notice gets the width it was written for', (
    tester,
  ) async {
    // "Kept to one compact line so it can sit on a map without covering a
    // hazard" — its own words. Capped at three fifths inside the left column
    // it wrapped to three lines, and the column grew tall enough to push the
    // basemap switch into the middle of the map.
    await _pump(tester);

    final attribution = find.byType(MapDataAttribution);
    expect(attribution, findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    final rect = tester.getRect(attribution);
    final ahead = tester.getRect(find.text(l10n.mapTracedShapes));
    expect(
      rect.top,
      greaterThanOrEqualTo(ahead.bottom),
      reason: 'the notice is below both columns, not inside one',
    );
    expect(
      rect.width,
      greaterThan(tester.view.physicalSize.width / tester.view.devicePixelRatio * 0.6),
      reason: 'it has the full foot of the map, not a fifth of it',
    );
  });
}
