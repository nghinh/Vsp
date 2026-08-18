// The hole map in the golfer's own unit, including where nobody is asking.
//
// Three panels on the vector map read the unit with
// `DistanceUnitScope.watch(context)` and no fallback, which means metres
// whenever no ProfileBloc is in scope. HoleMapView takes a `distanceUnit`
// argument for exactly that case — the constructor's own words are "display
// unit to start from when no ProfileBloc is in scope" — and the panels ignored
// it. A caller that passed yards got yards in the measuring tool, which does
// honour the argument, and metres on the map beside it: the same distance,
// twice, in two units, on one screen.
//
// The unit is now taken once in didChangeDependencies and held, which is also
// what stopped `_playLine` from subscribing to it from inside MapLibre's
// style-loaded callback. That crash is not reproducible here — it needs a real
// map to load a real style, and the screens tour is what catches it — but this
// is the half of the same change a widget can be asked about.

import 'package:flutter/material.dart';
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
import 'package:vsp_mobile/features/hole_map/presentation/widgets/hole_map_view.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A square about 30 m across, centred where it is asked to be.
///
/// Polygons, not points. A hole whose only geometry is a tee dot and a green
/// dot counts as unsurveyed, and the view sends those straight to the
/// measuring tool — "an empty vector map helps nobody". Getting the vector map
/// on screen at all means giving it something to draw.
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

/// A hole somebody surveyed and somebody else checked.
///
/// Both halves are needed to get the vector map open at all:
/// `shouldDefaultToSatellite` sends anything else to the measuring tool, and
/// class alone is not enough because the fabricated seed rows claimed class C.
/// Worth knowing while reading this file: no hole in the live database passes
/// this test, which is why the vector map is a screen almost nobody opens and
/// why a crash could sit in it unnoticed.
const _surveyed = HoleDataProvenance(
  accuracyClass: AccuracyClass.classC,
  verificationStatus: VerificationStatus.verified,
);

/// Long Biên's 1st, near enough: a tee and a green about 300 m apart, which is
/// a par 4 and a play line with a number on it worth reading.
HoleMapReady _hole() => HoleMapReady(
  holeMap: HoleMapEntity(
    courseId: '1351',
    courseName: 'Long Biên Golf Course',
    holeNumber: 1,
    par: 4,
    provenance: _surveyed,
    layers: {
      MapLayerType.tee: _square(MapLayerType.tee, 21.036720, 105.892017),
      MapLayerType.fairway: _square(
        MapLayerType.fairway,
        21.038000,
        105.892017,
      ),
      MapLayerType.green: _square(MapLayerType.green, 21.039400, 105.892017),
    },
  ),
  layerVisibility: const {'tee': true, 'fairway': true, 'green': true},
);

Future<void> _pump(WidgetTester tester, DistanceUnit unit) async {
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HoleMapView(
          state: _hole(),
          distanceUnit: unit,
          imageryConfig: SatelliteImageryConfig.unavailable,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    BasemapPreference.resetForTesting();
    // The vector map, not the measuring tool. The tool already honoured the
    // argument; the map is what did not, and the two sit one tap apart.
    BasemapPreference.choose(BasemapMode.courseMap);
  });
  tearDown(BasemapPreference.resetForTesting);

  testWidgets('the map prints yards for a caller that asked for yards', (
    tester,
  ) async {
    await _pump(tester, DistanceUnit.yards);

    expect(
      find.textContaining('yd'),
      findsWidgets,
      reason:
          'HoleMapView was given yards and no ProfileBloc to override it, so '
          'every distance it draws is in yards',
    );
    expect(
      find.textContaining(RegExp(r'\d+\s*m\b')),
      findsNothing,
      reason: 'a metre on this screen is the same distance printed twice',
    );
  });

  testWidgets('and metres for a caller that asked for metres', (tester) async {
    await _pump(tester, DistanceUnit.meters);

    expect(find.textContaining('m'), findsWidgets);
    expect(find.textContaining('yd'), findsNothing);
  });
}
