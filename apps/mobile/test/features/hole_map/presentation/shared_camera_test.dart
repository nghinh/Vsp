// Switching basemap keeps the hole where it was.
//
// The drawn map and the photograph are two MapLibre instances with two
// cameras. Each opened on its own default: the vector map on the hole centre
// at zoom 16, the satellite view on its own target at zoom 17, both north-up.
// So a golfer who pinched in on the green, or turned the hole to face the way
// they were standing, and then tapped across, was handed the same hole from
// somewhere else and had to find the green again — on a screen they switch
// between precisely to compare the two pictures of the same ground.
//
// Nothing was wrong with either picture. They were simply not the same
// picture.
//
// The camera is held by the view that owns both modes, and a hole change
// clears it, because a new hole should frame itself rather than inherit the
// last one's corner.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

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
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

const _imagery = SatelliteImageryConfig(
  provider: SatelliteImageryProvider.custom,
  tileUrlTemplate: 'https://example.invalid/{z}/{y}/{x}',
  attributionText: 'Test imagery',
  requiresMapboxLogo: false,
  tileSize: 256,
  maxZoom: 19,
);

const _surveyed = HoleDataProvenance(
  accuracyClass: AccuracyClass.classC,
  verificationStatus: VerificationStatus.verified,
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

HoleMapReady _hole({int number = 10}) => HoleMapReady(
  holeMap: HoleMapEntity(
    courseId: '1351',
    courseName: 'Long Biên Golf Course',
    holeNumber: number,
    par: 4,
    provenance: _surveyed,
    layers: {
      MapLayerType.tee: _square(MapLayerType.tee, 21.036720, 105.892017),
      MapLayerType.green: _square(MapLayerType.green, 21.039400, 105.892017),
      MapLayerType.fairway: _square(MapLayerType.fairway, 21.038, 105.892017),
    },
  ),
  layerVisibility: const {'tee': true, 'green': true, 'fairway': true},
);

Future<void> _pump(WidgetTester tester, {int hole = 10}) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HoleMapView(state: _hole(number: hole), imageryConfig: _imagery),
      ),
    ),
  );
  await tester.pump();
}

/// The camera the satellite half would open with.
ml.CameraPosition? _satelliteInitialCamera(WidgetTester tester) => tester
    .widget<SatelliteMeasureView>(find.byType(SatelliteMeasureView))
    .initialCamera;

void main() {
  setUp(BasemapPreference.resetForTesting);
  tearDown(BasemapPreference.resetForTesting);

  testWidgets('the photograph opens on the hole when nothing has moved yet', (
    tester,
  ) async {
    await _pump(tester);

    expect(
      _satelliteInitialCamera(tester),
      isNull,
      reason:
          'first open has nowhere to carry over from, so the hole frames '
          'itself',
    );
  });

  testWidgets('the photograph opens where the drawn map was left', (
    tester,
  ) async {
    await _pump(tester);

    // What the vector map reports when the golfer stops moving it: pinched in,
    // and turned to face the way they are standing.
    final turned = const ml.CameraPosition(
      target: ml.LatLng(21.0384, 105.8921),
      zoom: 18.5,
      bearing: 137,
      tilt: 30,
    );
    final dynamic state = tester.state(find.byType(HoleMapView));
    // ignore: avoid_dynamic_calls
    state.rememberCameraForTesting(turned);
    await tester.pump();

    final carried = _satelliteInitialCamera(tester);
    expect(carried, isNotNull);
    expect(carried!.target.latitude, closeTo(21.0384, 1e-6));
    expect(carried.zoom, 18.5);
    expect(
      carried.bearing,
      137,
      reason: 'the rotation is the point — a golfer turns the hole to face the '
          'way they are standing, and the other map opened north-up',
    );
    expect(carried.tilt, 30);
  });

  testWidgets('a different hole frames itself instead', (tester) async {
    await _pump(tester);
    final dynamic state = tester.state(find.byType(HoleMapView));
    // ignore: avoid_dynamic_calls
    state.rememberCameraForTesting(
      const ml.CameraPosition(target: ml.LatLng(21.0384, 105.8921), zoom: 18.5),
    );
    await tester.pump();
    expect(_satelliteInitialCamera(tester), isNotNull);

    // Walking to the 11th.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HoleMapView(state: _hole(number: 11), imageryConfig: _imagery),
        ),
      ),
    );
    await tester.pump();

    expect(
      _satelliteInitialCamera(tester),
      isNull,
      reason: 'the 11th is a different picture, not a corner of the 10th',
    );
  });
}
