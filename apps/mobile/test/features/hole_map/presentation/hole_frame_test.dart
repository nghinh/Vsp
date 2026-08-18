// The drawing and the photograph frame the same hole the same way.
//
// Reported from the course with two screenshots of hole 10 taken a minute
// apart: "Ảnh vệ tinh và bản đồ không khớp vị trí, tỷ lệ với nhau".
//
// The shared camera was working by then — the feature chips land on the same
// pixels in both screenshots, which they only can if both maps are looking at
// the same thing. What had never matched was where each one *starts*. The
// drawn map opened at a hardcoded zoom 16 and the photograph at a hardcoded
// 17: a factor of two in scale, on two tabs of one hole, before the golfer
// touched anything. The photograph then re-centred on the golfer's fix and
// moved again.
//
// No constant could be right. Measured against Long Biên's package: this hole
// is a 470m par 5 whose corridor wants about zoom 17.1, and the par 3 beside
// it wants a different number. So the hole's geometry says, and both views
// ask it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:vsp_mobile/domain/models/data_freshness.dart'
    show VerificationStatus;
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_frame.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/hole_map_view.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A square of side ~33m centred on the point.
MapLayerEntity _blob(MapLayerType type, double lat, double lng) {
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

/// Long Biên's 10th as the package actually holds it.
///
/// The corridor runs from the tee at 21.03805 down to the green at 21.03414.
/// The bunker sits at 21.03324 — south of the green and 500m from the tee,
/// because a hole file carries everything within reach of the hole, including
/// the next fairway's sand. That is right for playing and wrong for framing.
HoleMapEntity _tenth() => HoleMapEntity(
  courseId: '1352',
  courseName: 'Long Biên Golf Course',
  holeNumber: 1,
  par: 5,
  provenance: _surveyed,
  layers: {
    MapLayerType.tee: _blob(MapLayerType.tee, 21.03805, 105.89639),
    MapLayerType.fairway: _blob(MapLayerType.fairway, 21.03601, 105.89460),
    MapLayerType.green: _blob(MapLayerType.green, 21.03414, 105.89288),
    MapLayerType.bunker: _blob(MapLayerType.bunker, 21.03324, 105.89722),
  },
);

void main() {
  group('the box the hole is framed in', () {
    test('is the corridor, not everything the file carries', () {
      final bounds = HoleGeometryCoverage.holeBounds(_tenth())!;

      // The bunker at 21.03324 is 100m south of the green and belongs to the
      // hole beside this one. Framing to include it aims the camera between
      // holes and zooms out until neither is readable.
      expect(
        bounds.southwest.latitude,
        greaterThan(21.0334),
        reason: 'the neighbouring bunker is outside the frame',
      );
      expect(bounds.southwest.latitude, lessThan(21.03414));
      expect(bounds.northeast.latitude, greaterThan(21.03805 - 0.0002));
      expect(
        bounds.northeast.longitude,
        lessThan(105.89722),
        reason: "and so is that bunker's easting",
      );
    });

    test('holds the whole corridor, tee to green', () {
      final bounds = HoleGeometryCoverage.holeBounds(_tenth())!;

      expect(bounds.southwest.latitude, lessThanOrEqualTo(21.03414));
      expect(bounds.northeast.latitude, greaterThanOrEqualTo(21.03805));
      expect(bounds.southwest.longitude, lessThanOrEqualTo(105.89288));
      expect(bounds.northeast.longitude, greaterThanOrEqualTo(105.89639));
    });

    test('falls back to what there is when there is no corridor', () {
      // Some packages carry a green and nothing else. A frame around the green
      // is still better than a constant.
      final greenOnly = HoleMapEntity(
        courseId: '1352',
        courseName: 'Long Biên Golf Course',
        holeNumber: 4,
        par: 3,
        provenance: _surveyed,
        layers: {
          MapLayerType.water: _blob(MapLayerType.water, 21.0340, 105.8930),
        },
      );

      final bounds = HoleGeometryCoverage.holeBounds(greenOnly);
      expect(bounds, isNotNull);
      expect(bounds!.southwest.latitude, closeTo(21.0340, 0.001));
    });

    test('is null for a hole nobody has traced', () {
      final bare = HoleMapEntity(
        courseId: '1352',
        courseName: 'Long Biên Golf Course',
        holeNumber: 5,
        par: 4,
        provenance: _surveyed,
        layers: const {},
      );

      expect(HoleGeometryCoverage.holeBounds(bare), isNull);
      expect(holeFrameFor(bare), isNull);
    });

    test('a different hole gets a different box', () {
      // The whole point: one constant cannot frame a 470m par 5 and a 130m par
      // 3, and 16 and 17 were both constants.
      final parThree = HoleMapEntity(
        courseId: '1352',
        courseName: 'Long Biên Golf Course',
        holeNumber: 8,
        par: 3,
        provenance: _surveyed,
        layers: {
          MapLayerType.tee: _blob(MapLayerType.tee, 21.03500, 105.89400),
          MapLayerType.green: _blob(MapLayerType.green, 21.03610, 105.89400),
        },
      );

      final long = HoleGeometryCoverage.holeBounds(_tenth())!;
      final short = HoleGeometryCoverage.holeBounds(parThree)!;
      final longSpan = long.northeast.latitude - long.southwest.latitude;
      final shortSpan = short.northeast.latitude - short.southwest.latitude;

      expect(shortSpan, lessThan(longSpan / 2));
    });
  });

  group('and both views are given it', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HoleMapView(
              state: HoleMapReady(
                holeMap: _tenth(),
                layerVisibility: const {
                  'tee': true,
                  'fairway': true,
                  'green': true,
                  'bunker': true,
                },
              ),
              imageryConfig: const SatelliteImageryConfig(
                provider: SatelliteImageryProvider.custom,
                tileUrlTemplate: 'https://example.invalid/{z}/{y}/{x}',
                attributionText: 'Test imagery',
                requiresMapboxLogo: false,
                tileSize: 256,
                maxZoom: 19,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    setUp(BasemapPreference.resetForTesting);
    tearDown(BasemapPreference.resetForTesting);

    testWidgets('the photograph frames the same box as the drawing', (
      tester,
    ) async {
      await pump(tester);

      final satellite = tester.widget<SatelliteMeasureView>(
        find.byType(SatelliteMeasureView),
      );
      final mine = holeFrameFor(_tenth())!;

      expect(
        satellite.holeBounds,
        isNotNull,
        reason: 'without it the photograph falls back to its constant 17',
      );
      expect(
        satellite.holeBounds!.southwest.latitude,
        closeTo(mine.southwest.latitude, 1e-9),
      );
      expect(
        satellite.holeBounds!.northeast.longitude,
        closeTo(mine.northeast.longitude, 1e-9),
      );
    });

    testWidgets('and the carried camera still outranks it', (tester) async {
      // Fitting the box on arrival would throw away the zoom and rotation the
      // golfer chose on the other tab — which is the defect the shared camera
      // was written to fix.
      await pump(tester);
      final dynamic state = tester.state(find.byType(HoleMapView));
      // ignore: avoid_dynamic_calls
      state.rememberCameraForTesting(
        const ml.CameraPosition(
          target: ml.LatLng(21.0360, 105.8946),
          zoom: 18.5,
          bearing: 137,
        ),
      );
      await tester.pump();

      final satellite = tester.widget<SatelliteMeasureView>(
        find.byType(SatelliteMeasureView),
      );
      expect(satellite.initialCamera, isNotNull);
      expect(satellite.initialCamera!.zoom, 18.5);
      expect(satellite.initialCamera!.bearing, 137);
    });
  });
}
