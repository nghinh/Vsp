// Tests for HoleMapGeoJson — the two GeoJSON sources the vector map draws.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/domain/distance_ring_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/golfer_position_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_geojson.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/target_entity.dart';

const _lat = 10.9;
const _lng = 106.9;

MapLayerEntity _layer(MapLayerType type, Map<String, dynamic> geoJson) =>
    MapLayerEntity(
      type: type,
      format: LayerGeometryFormat.geoJson,
      geoJson: geoJson,
      style: const LayerStyle(),
    );

HoleMapEntity _holeMap(Map<MapLayerType, MapLayerEntity> layers) =>
    HoleMapEntity(
      courseId: 'c1',
      courseName: 'Long Thành',
      holeNumber: 1,
      par: 4,
      layers: layers,
    );

List<Map<String, dynamic>> _features(Map<String, dynamic> collection) =>
    (collection['features'] as List).cast<Map<String, dynamic>>();

String _kind(Map<String, dynamic> feature) =>
    (feature['properties'] as Map)['layerType'] as String;

/// Rough metres-per-degree check, good enough to tell 100 m from 150 m.
double _radiusMeters(List<dynamic> ring, double centerLat, double centerLng) {
  final first = (ring.first as List).cast<num>();
  final dLng = (first[0] - centerLng) * math.cos(centerLat * math.pi / 180);
  final dLat = first[1] - centerLat;
  return math.sqrt(dLng * dLng + dLat * dLat) * 111320.0;
}

void main() {
  group('courseGeometry', () {
    test('flattens every layer and tags features with their layer type', () {
      final collection = HoleMapGeoJson.courseGeometry(
        _holeMap({
          MapLayerType.green: _layer(MapLayerType.green, {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'Polygon',
                  'coordinates': [
                    [
                      [_lng, _lat],
                      [_lng + 0.001, _lat],
                      [_lng, _lat + 0.001],
                      [_lng, _lat],
                    ],
                  ],
                },
                'properties': {'name': 'Green 1'},
              },
            ],
          }),
          MapLayerType.cartPath: _layer(MapLayerType.cartPath, {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [_lng, _lat],
                [_lng + 0.002, _lat],
              ],
            },
          }),
        }),
      );

      final features = _features(collection);
      expect(features, hasLength(2));
      expect(
        features.map(_kind),
        containsAll([MapLayerType.green.name, MapLayerType.cartPath.name]),
      );
      // Existing properties survive the tagging.
      final green = features.firstWhere(
        (f) => _kind(f) == MapLayerType.green.name,
      );
      expect((green['properties'] as Map)['name'], 'Green 1');
    });

    test('accepts a bare geometry and skips empty layers', () {
      final collection = HoleMapGeoJson.courseGeometry(
        _holeMap({
          MapLayerType.bunker: _layer(MapLayerType.bunker, {
            'type': 'Point',
            'coordinates': [_lng, _lat],
          }),
          MapLayerType.water: MapLayerEntity(
            type: MapLayerType.water,
            format: LayerGeometryFormat.geoJson,
            style: const LayerStyle(),
          ),
        }),
      );

      final features = _features(collection);
      expect(features, hasLength(1));
      expect(_kind(features.single), MapLayerType.bunker.name);
    });

    test('a hole with no geometry produces an empty collection', () {
      final collection = HoleMapGeoJson.courseGeometry(_holeMap(const {}));
      expect(_features(collection), isEmpty);
      expect(collection['type'], 'FeatureCollection');
    });
  });

  group('overlay', () {
    test('emits the golfer with a metric accuracy disc', () {
      final collection = HoleMapGeoJson.overlay(
        golferPosition: GolferPositionEntity(
          latitude: _lat,
          longitude: _lng,
          accuracy: 8,
          source: PositionSource.gps,
          confidence: PositionConfidence.high,
          timestamp: DateTime(2026, 8, 5),
        ),
      );

      final features = _features(collection);
      expect(features.map(_kind), [
        HoleMapFeatureKind.golferAccuracy,
        HoleMapFeatureKind.golfer,
      ]);

      final disc = features.first;
      expect((disc['geometry'] as Map)['type'], 'Polygon');
      final ring = ((disc['geometry'] as Map)['coordinates'] as List).first;
      expect(_radiusMeters(ring as List, _lat, _lng), closeTo(8, 1));
    });

    test('omits the accuracy disc when the fix carries no accuracy', () {
      final collection = HoleMapGeoJson.overlay(
        golferPosition: GolferPositionEntity(
          latitude: _lat,
          longitude: _lng,
          source: PositionSource.gps,
          confidence: PositionConfidence.low,
          timestamp: DateTime(2026, 8, 5),
        ),
      );

      expect(_features(collection).map(_kind), [HoleMapFeatureKind.golfer]);
    });

    test('draws distance rings at their real radius, in metres', () {
      final collection = HoleMapGeoJson.overlay(
        distanceRings: DistanceRingPresets.standardSet(
          centerLat: _lat,
          centerLng: _lng,
        ),
      );

      final features = _features(collection);
      expect(features.map(_kind), [
        HoleMapFeatureKind.distanceRing100,
        HoleMapFeatureKind.distanceRing150,
        HoleMapFeatureKind.distanceRing200,
      ]);
      for (final (index, expected) in [100.0, 150.0, 200.0].indexed) {
        final geometry = features[index]['geometry'] as Map;
        expect(geometry['type'], 'LineString');
        expect(
          _radiusMeters(geometry['coordinates'] as List, _lat, _lng),
          closeTo(expected, expected * 0.02),
        );
      }
    });

    test('skips hidden rings and radii the style cannot draw', () {
      final collection = HoleMapGeoJson.overlay(
        distanceRings: [
          DistanceRingPresets.ring100.copyWith(
            centerLat: _lat,
            centerLng: _lng,
            visible: false,
          ),
          const DistanceRingEntity(
            id: 'ring_250',
            centerLat: _lat,
            centerLng: _lng,
            radiusMeters: 250,
          ),
        ],
      );

      expect(_features(collection), isEmpty);
    });

    test('emits pin and target markers with their provenance', () {
      final collection = HoleMapGeoJson.overlay(
        pin: PinEntity(
          holeId: 'h1',
          holeNumber: 1,
          latitude: _lat,
          longitude: _lng,
          source: PinSource.official,
          confidence: 0.9,
          effectiveDate: DateTime(2026, 8, 5),
        ),
        target: TargetEntity(
          id: 't1',
          latitude: _lat,
          longitude: _lng,
          createdAt: DateTime(2026, 8, 5),
          label: 'Layup',
        ),
      );

      final features = _features(collection);
      expect(features.map(_kind), [
        HoleMapFeatureKind.pin,
        HoleMapFeatureKind.target,
      ]);
      expect(
        (features.first['properties'] as Map)['source'],
        PinSource.official.name,
      );
      expect((features.last['properties'] as Map)['label'], 'Layup');
    });

    test('an empty hole overlay is still a valid collection', () {
      final collection = HoleMapGeoJson.overlay();
      expect(collection['type'], 'FeatureCollection');
      expect(_features(collection), isEmpty);
    });
  });
}
