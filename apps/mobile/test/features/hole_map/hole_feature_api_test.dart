// Traced shapes, grouped into the layers the map already draws.
//
// The map has styles for greens, bunkers and water; what it lacked was
// anything to draw with them. These arrive as one flat GeoJSON collection
// and have to come apart into the same layer map a surveyed course fills.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/hole_map/data/hole_feature_api.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

Map<String, dynamic> feature(String layer, {bool verified = false}) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [105.891, 21.035],
            [105.892, 21.035],
            [105.892, 21.036],
            [105.891, 21.035],
          ]
        ],
      },
      'properties': {
        'layerType': layer,
        'confidence': 88,
        'verified': verified,
      },
    };

void main() {
  test('groups features into the map\'s own layers', () {
    final traced = HoleFeatureApi.parse({
      'type': 'FeatureCollection',
      'features': [
        feature('green'),
        feature('bunker'),
        feature('bunker'),
        feature('water'),
      ],
    });

    expect(traced.layers.keys, containsAll([
      MapLayerType.green,
      MapLayerType.bunker,
      MapLayerType.water,
    ]));
    // Both bunkers land in one layer, as one collection.
    final bunkers = traced.layers[MapLayerType.bunker]!.geoJson!['features'];
    expect(bunkers, hasLength(2));
  });

  test('says when nobody has checked the shapes', () {
    final unchecked = HoleFeatureApi.parse({
      'features': [feature('green')],
    });
    final checked = HoleFeatureApi.parse({
      'features': [feature('green', verified: true)],
    });

    expect(unchecked.anyUnverified, isTrue);
    expect(checked.anyUnverified, isFalse);
  });

  test('a layer the map cannot draw is dropped, not guessed at', () {
    final traced = HoleFeatureApi.parse({
      'features': [feature('clubhouse'), feature('green')],
    });

    expect(traced.layers.keys, [MapLayerType.green]);
  });

  test('a hole with nothing traced is empty, not an error', () {
    expect(HoleFeatureApi.parse({'features': []}).isEmpty, isTrue);
    expect(HoleFeatureApi.parse('not json').isEmpty, isTrue);
    expect(HoleFeatureApi.parse(null).isEmpty, isTrue);
  });
}
