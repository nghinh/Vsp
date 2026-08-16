// Which shape is the 142-metre one.
//
// The panel in the corner ranks what is ahead. It cannot say which of two
// sand-coloured blobs on screen it is talking about, and that is the whole
// reason a label sits on the shape itself.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/feature_labels.dart';
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
  const tee = LatLng(latitude: 21.0300, longitude: 105.8900);

  test('a label sits on the middle of its shape', () {
    final labels = FeatureLabels.forLayers(
      layers: {
        MapLayerType.bunker:
            square(MapLayerType.bunker, 21.0320, 105.8905, 0.0002),
      },
      from: tee,
    );

    expect(labels, hasLength(1));
    expect(labels.first.at.latitude, closeTo(21.0320, 0.00001));
    expect(labels.first.at.longitude, closeTo(105.8905, 0.00001));
  });

  /// A green is a target and a bunker is a thing to miss, so they are not
  /// measured the same way. To the middle of one, to the edge of the other.
  test('a green is measured to its centre and a bunker to its near edge', () {
    final labels = FeatureLabels.forLayers(
      layers: {
        MapLayerType.green: square(MapLayerType.green, 21.0345, 105.8900, 0.0002),
        MapLayerType.bunker:
            square(MapLayerType.bunker, 21.0320, 105.8900, 0.0002),
      },
      from: tee,
    );

    final green = labels.firstWhere((l) => l.layer == MapLayerType.green);
    final bunker = labels.firstWhere((l) => l.layer == MapLayerType.bunker);

    // The green's number is the distance to its centre.
    expect(green.meters, closeTo(tee.distanceTo(green.at), 0.5));
    // The bunker's is shorter than the distance to its centre, because its
    // near edge is about twenty metres closer.
    expect(bunker.meters, lessThan(tee.distanceTo(bunker.at) - 15));
  });

  test('the nearest shapes come first', () {
    final labels = FeatureLabels.forLayers(
      layers: {
        MapLayerType.green: square(MapLayerType.green, 21.0345, 105.8900, 0.0002),
        MapLayerType.water: square(MapLayerType.water, 21.0310, 105.8900, 0.0002),
      },
      from: tee,
    );

    expect(labels.first.layer, MapLayerType.water);
    expect(labels.last.layer, MapLayerType.green);
  });

  /// Naming the fairway "fairway" over ground the golfer can see is fairway
  /// costs a chip and buys nothing.
  test('fairway and rough are drawn but not named', () {
    final labels = FeatureLabels.forLayers(
      layers: {
        MapLayerType.fairway:
            square(MapLayerType.fairway, 21.0320, 105.8900, 0.0010),
        MapLayerType.rough: square(MapLayerType.rough, 21.0320, 105.8900, 0.0015),
      },
      from: tee,
    );

    expect(labels, isEmpty);
  });

  /// Past a handful they overlap each other and the shapes underneath.
  test('the number of chips is capped', () {
    final layers = <MapLayerType, MapLayerEntity>{};
    for (var i = 0; i < 3; i++) {
      layers[MapLayerType.values[i]] = MapLayerEntity(
        type: MapLayerType.bunker,
        format: LayerGeometryFormat.geoJson,
        geoJson: {
          'type': 'FeatureCollection',
          'features': [
            for (var j = 0; j < 4; j++)
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'Polygon',
                  'coordinates': [
                    [
                      [105.8900, 21.0310 + j * 0.0003],
                      [105.8902, 21.0310 + j * 0.0003],
                      [105.8902, 21.0312 + j * 0.0003],
                      [105.8900, 21.0312 + j * 0.0003],
                      [105.8900, 21.0310 + j * 0.0003],
                    ]
                  ],
                },
                'properties': const {},
              }
          ],
        },
        style: const LayerStyle(),
      );
    }

    expect(FeatureLabels.forLayers(layers: layers, from: tee, limit: 6),
        hasLength(lessThanOrEqualTo(6)));
  });

  test('a layer with no geometry produces no labels', () {
    final labels = FeatureLabels.forLayers(
      layers: {
        MapLayerType.bunker: const MapLayerEntity(
          type: MapLayerType.bunker,
          format: LayerGeometryFormat.geoJson,
          style: LayerStyle(),
        ),
      },
      from: tee,
    );

    expect(labels, isEmpty);
  });
}
