// HoleGeometryCoverage Unit Tests — VSP Mobile App
//
// The rule this encodes: a hole with no real polygons must open in satellite
// mode. Getting it wrong either hides real course data or shows a golfer an
// empty rectangle and calls it a hole.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';

void main() {
  MapLayerEntity layer(MapLayerType type, Map<String, dynamic>? geoJson) {
    return MapLayerEntity(
      type: type,
      format: LayerGeometryFormat.geoJson,
      geoJson: geoJson,
      style: const LayerStyle(),
    );
  }

  Map<String, dynamic> polygonCollection(List<List<double>> ring) => {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [ring],
        },
        'properties': const <String, dynamic>{},
      },
    ],
  };

  HoleMapEntity hole({
    Map<MapLayerType, MapLayerEntity> layers = const {},
    PinEntity? pin,
  }) {
    return HoleMapEntity(
      courseId: 'course-1',
      courseName: 'Test Golf Club',
      holeNumber: 7,
      par: 4,
      layers: layers,
      pin: pin,
    );
  }

  PinEntity pinAt(double lat, double lng, PinSource source,
      {DateTime? expiry}) {
    return PinEntity(
      holeId: 'hole-7',
      holeNumber: 7,
      latitude: lat,
      longitude: lng,
      source: source,
      expiryDate: expiry,
    );
  }

  group('hasStrategicGeometry', () {
    test('a hole with no layers has nothing worth drawing', () {
      expect(HoleGeometryCoverage.hasStrategicGeometry(hole()), isFalse);
      expect(HoleGeometryCoverage.shouldDefaultToSatellite(hole()), isTrue);
    });

    test('a layer present but empty still counts as nothing', () {
      final subject = hole(
        layers: {
          MapLayerType.green: layer(MapLayerType.green, {
            'type': 'FeatureCollection',
            'features': const [],
          }),
        },
      );

      expect(HoleGeometryCoverage.hasStrategicGeometry(subject), isFalse);
    });

    test('a layer with a null geoJson counts as nothing', () {
      final subject = hole(
        layers: {MapLayerType.fairway: layer(MapLayerType.fairway, null)},
      );

      expect(HoleGeometryCoverage.hasStrategicGeometry(subject), isFalse);
    });

    test('a real green polygon is worth drawing', () {
      final subject = hole(
        layers: {
          MapLayerType.green: layer(
            MapLayerType.green,
            polygonCollection([
              [106.700, 10.800],
              [106.701, 10.800],
              [106.701, 10.801],
              [106.700, 10.800],
            ]),
          ),
        },
      );

      expect(HoleGeometryCoverage.hasStrategicGeometry(subject), isTrue);
      expect(HoleGeometryCoverage.shouldDefaultToSatellite(subject), isFalse);
    });

    test('cart paths and landmarks alone do not make a strategic map', () {
      final subject = hole(
        layers: {
          MapLayerType.cartPath: layer(
            MapLayerType.cartPath,
            polygonCollection([
              [106.700, 10.800],
              [106.701, 10.800],
            ]),
          ),
        },
      );

      expect(HoleGeometryCoverage.hasStrategicGeometry(subject), isFalse);
    });

    test('a pin without polygons is one dot, not a map', () {
      final subject = hole(pin: pinAt(10.803, 106.7, PinSource.official));

      expect(HoleGeometryCoverage.shouldDefaultToSatellite(subject), isTrue);
    });
  });

  group('featureCount', () {
    test('counts features in a FeatureCollection', () {
      final collection = polygonCollection([
        [106.7, 10.8],
        [106.701, 10.8],
      ]);
      expect(
        HoleGeometryCoverage.featureCount(
          layer(MapLayerType.green, collection),
        ),
        1,
      );
    });

    test('accepts a bare Feature', () {
      final feature = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [106.7, 10.8],
        },
      };
      expect(
        HoleGeometryCoverage.featureCount(layer(MapLayerType.green, feature)),
        1,
      );
    });

    test('accepts a bare geometry', () {
      final geometry = {
        'type': 'Point',
        'coordinates': [106.7, 10.8],
      };
      expect(
        HoleGeometryCoverage.featureCount(layer(MapLayerType.green, geometry)),
        1,
      );
    });

    test('ignores features with no coordinates', () {
      final collection = {
        'type': 'FeatureCollection',
        'features': [
          {'type': 'Feature', 'properties': const <String, dynamic>{}},
        ],
      };
      expect(
        HoleGeometryCoverage.featureCount(
          layer(MapLayerType.green, collection),
        ),
        0,
      );
    });
  });

  group('greenAnchor', () {
    test('an active official pin is surveyed', () {
      final anchor = HoleGeometryCoverage.greenAnchor(
        hole(pin: pinAt(10.803, 106.702, PinSource.official)),
      );

      expect(anchor, isNotNull);
      expect(anchor!.isSurveyed, isTrue);
      expect(anchor.position.latitude, 10.803);
      expect(anchor.position.longitude, 106.702);
    });

    test('an estimated pin is not surveyed', () {
      final anchor = HoleGeometryCoverage.greenAnchor(
        hole(pin: pinAt(10.803, 106.702, PinSource.estimated)),
      );

      expect(anchor!.isSurveyed, isFalse);
    });

    test('an expired official pin is no longer surveyed truth', () {
      final anchor = HoleGeometryCoverage.greenAnchor(
        hole(
          pin: pinAt(
            10.803,
            106.702,
            PinSource.official,
            expiry: DateTime(2020, 1, 1),
          ),
        ),
      );

      expect(anchor!.isSurveyed, isFalse);
    });

    test('falls back to the green polygon centroid, flagged as estimated', () {
      final anchor = HoleGeometryCoverage.greenAnchor(
        hole(
          layers: {
            MapLayerType.green: layer(
              MapLayerType.green,
              polygonCollection([
                [106.700, 10.800],
                [106.702, 10.800],
                [106.702, 10.802],
                [106.700, 10.802],
              ]),
            ),
          },
        ),
      );

      expect(anchor, isNotNull);
      expect(anchor!.isSurveyed, isFalse);
      expect(anchor.position.longitude, closeTo(106.701, 1e-9));
      expect(anchor.position.latitude, closeTo(10.801, 1e-9));
    });

    test('is null when the hole has neither a pin nor a green', () {
      expect(HoleGeometryCoverage.greenAnchor(hole()), isNull);
    });

    test('is null when the green layer carries no coordinates', () {
      final anchor = HoleGeometryCoverage.greenAnchor(
        hole(
          layers: {
            MapLayerType.green: layer(MapLayerType.green, {
              'type': 'FeatureCollection',
              'features': const [],
            }),
          },
        ),
      );

      expect(anchor, isNull);
    });
  });
}
