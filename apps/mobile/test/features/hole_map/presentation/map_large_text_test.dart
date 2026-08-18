// The map still fits when the golfer turns the text up.
//
// `test/theme/large_text_no_overflow_test.dart` pumps seven mid-round widgets
// at 1.0×, 1.3× and 2.0×. The map is not among them, and the map is the screen
// a golfer holds for four hours. Neither the satellite view, nor the basemap
// switch, nor the imagery attribution, nor the traced-shapes caveat had ever
// been laid out at anything but the default text size by anything.
//
// That is not a hypothetical gap. The switch overflowed by 83px the day it was
// put in a Row with the provenance notice, and the "ahead" panel was printing
// under it as recently as this morning — both found by looking rather than by
// a test, because there was no test to find them.
//
// Flutter throws on a RenderFlex overflow during layout, so reaching the end
// of a pump without an exception is the assertion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/domain/models/data_freshness.dart'
    show VerificationStatus;
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/hole_map_view.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A provider that is configured, so the satellite half is the one a golfer
/// with signal actually meets: imagery, an attribution line to credit it, and
/// a switch labelled "Vệ tinh" rather than "Thước đo".
const _imagery = SatelliteImageryConfig(
  provider: SatelliteImageryProvider.custom,
  tileUrlTemplate: 'https://example.invalid/{z}/{y}/{x}',
  attributionText:
      'Powered by Esri — Nguồn: Esri, Maxar, Earthstar Geographics',
  requiresMapboxLogo: false,
  tileSize: 256,
  maxZoom: 19,
);

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

Future<void> _pump(WidgetTester tester, double scale) async {
  // 402 dp wide — an iPhone 17, and the width the screens tour photographs.
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: VspTheme.dark(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: HoleMapView(state: _hole(), imageryConfig: _imagery),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(BasemapPreference.resetForTesting);

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('the satellite view fits at ${scale}× text', (tester) async {
      BasemapPreference.resetForTesting(); // satellite is the default
      await _pump(tester, scale);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the drawn hole map fits at ${scale}× text', (tester) async {
      BasemapPreference.resetForTesting();
      BasemapPreference.choose(BasemapMode.courseMap);
      await _pump(tester, scale);
      expect(tester.takeException(), isNull);
    });
  }
}
