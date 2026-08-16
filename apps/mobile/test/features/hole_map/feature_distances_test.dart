// The two numbers that decide a club.
//
// A polygon's centroid is not a distance anybody plays to. What a golfer
// needs is the near edge — what they must not reach — and the far edge,
// what they must carry. And only for what is still in front of them.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/feature_distances.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

/// A square, given its centre and a half-width in degrees.
MapLayerEntity square(MapLayerType type, double lat, double lng, double half) =>
    MapLayerEntity(
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
                  [lng - half, lat - half],
                  [lng + half, lat - half],
                  [lng + half, lat + half],
                  [lng - half, lat + half],
                  [lng - half, lat - half],
                ]
              ],
            },
            'properties': const {},
          }
        ],
      },
      style: const LayerStyle(),
    );

void main() {
  // The golfer on a tee, playing due north.
  const tee = LatLng(latitude: 21.0300, longitude: 105.8900);
  const green = LatLng(latitude: 21.0345, longitude: 105.8900);

  test('reports the near edge and the far edge, not the middle', () {
    final measured = FeatureDistances.ahead(
      layers: {
        MapLayerType.bunker: square(MapLayerType.bunker, 21.0320, 105.8900, 0.0002),
      },
      from: tee,
      target: green,
    );

    expect(measured, hasLength(1));
    final bunker = measured.first;
    // The square spans about 44 m; near and far differ by roughly that.
    expect(bunker.farMeters, greaterThan(bunker.nearMeters + 30));
    // And the near edge is closer than the centre would be.
    expect(bunker.nearMeters, lessThan(222));
  });

  test('sorts by what comes first', () {
    final measured = FeatureDistances.ahead(
      layers: {
        MapLayerType.water: square(MapLayerType.water, 21.0335, 105.8900, 0.0002),
        MapLayerType.bunker: square(MapLayerType.bunker, 21.0315, 105.8900, 0.0002),
      },
      from: tee,
      target: green,
    );

    expect(measured.map((m) => m.layer),
        [MapLayerType.bunker, MapLayerType.water]);
  });

  /// A golfer walking up the hole leaves hazards behind them constantly, and
  /// a panel listing those buries the one they are about to hit.
  test('drops what is behind the golfer', () {
    final measured = FeatureDistances.ahead(
      layers: {
        MapLayerType.bunker: square(MapLayerType.bunker, 21.0280, 105.8900, 0.0002),
      },
      from: tee,
      target: green,
    );

    expect(measured, isEmpty);
  });

  test('keeps what is beside the line of play', () {
    // Level with the tee but well to the side: still in play, not behind.
    final measured = FeatureDistances.ahead(
      layers: {
        MapLayerType.bunker: square(MapLayerType.bunker, 21.0305, 105.8930, 0.0002),
      },
      from: tee,
      target: green,
    );

    expect(measured, hasLength(1));
  });

  test('ignores layers that are neither target nor hazard', () {
    final measured = FeatureDistances.ahead(
      layers: {
        MapLayerType.rough: square(MapLayerType.rough, 21.0320, 105.8900, 0.0004),
        MapLayerType.cartPath:
            square(MapLayerType.cartPath, 21.0320, 105.8905, 0.0004),
      },
      from: tee,
      target: green,
    );

    expect(measured, isEmpty);
  });

  test('a hole with nothing drawn measures nothing', () {
    expect(
      FeatureDistances.ahead(layers: const {}, from: tee, target: green),
      isEmpty,
    );
  });
}
