// SatelliteStyleBuilder Unit Tests — VSP Mobile App
//
// Tests cover:
// - Raster source/layer presence and the attribution embedded in the source
// - The measuring overlay layers and their filters
// - No symbol layers / no glyphs endpoint, so a weak signal cannot stall the map

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_style_builder.dart';
import 'package:vsp_mobile/features/measure/domain/measure_overlay_builder.dart';

void main() {
  final configured = SatelliteImageryConfig.resolve(
    mapboxAccessToken: 'pk.test-token',
  );

  List<Map<String, dynamic>> layersOf(Map<String, dynamic> style) =>
      (style['layers'] as List).cast<Map<String, dynamic>>();

  group('with imagery configured', () {
    final style = SatelliteStyleBuilder.buildStyleMap(config: configured);

    test('declares a raster source with the provider attribution', () {
      final source = (style['sources']
          as Map)[SatelliteStyleBuilder.satelliteSourceId] as Map;

      expect(source['type'], 'raster');
      expect((source['tiles'] as List).single, configured.tileUrlTemplate);
      expect(source['tileSize'], 512);
      expect(source['attribution'], configured.attributionText);
    });

    test('draws the imagery above the background and below the overlay', () {
      final ids = layersOf(style).map((l) => l['id']).toList();
      final imageryIndex = ids.indexOf(SatelliteStyleBuilder.satelliteLayerId);

      expect(imageryIndex, greaterThan(ids.indexOf('background')));
      expect(imageryIndex, lessThan(ids.indexOf('measure-leg-line')));
    });

    test('serialises to valid JSON for MapLibre', () {
      final decoded =
          jsonDecode(SatelliteStyleBuilder.build(config: configured))
              as Map<String, dynamic>;

      expect(decoded['version'], 8);
      expect(decoded['sources'], isA<Map<String, dynamic>>());
    });
  });

  group('without imagery configured', () {
    final style = SatelliteStyleBuilder.buildStyleMap(
      config: SatelliteImageryConfig.unavailable,
    );

    test('omits the raster source and layer entirely', () {
      expect(
        (style['sources'] as Map)
            .containsKey(SatelliteStyleBuilder.satelliteSourceId),
        isFalse,
      );
      expect(
        layersOf(style).map((l) => l['id']),
        isNot(contains(SatelliteStyleBuilder.satelliteLayerId)),
      );
    });

    test('still keeps the measuring overlay usable', () {
      expect(
        (style['sources'] as Map)
            .containsKey(SatelliteStyleBuilder.measureSourceId),
        isTrue,
      );
    });
  });

  group('measuring overlay layers', () {
    final style = SatelliteStyleBuilder.buildStyleMap(config: configured);
    final layers = layersOf(style);

    test('every overlay layer reads from the measure source', () {
      final overlayLayers =
          layers.where((l) => l['id'].toString().startsWith('measure-'));

      expect(overlayLayers, isNotEmpty);
      for (final layer in overlayLayers) {
        expect(layer['source'], SatelliteStyleBuilder.measureSourceId);
        expect(layer['filter'], isNotNull);
      }
    });

    test('filters cover each feature kind the builder emits', () {
      final filtered = layers
          .where((l) => l['filter'] != null)
          .map((l) => (l['filter'] as List)[2])
          .toSet();

      expect(filtered, contains(MeasureFeatureKind.accuracy));
      expect(filtered, contains(MeasureFeatureKind.leg));
      expect(filtered, contains(MeasureFeatureKind.greenLeg));
      expect(filtered, contains(MeasureFeatureKind.golfer));
      expect(filtered, contains(MeasureFeatureKind.green));
      expect(filtered, contains(MeasureFeatureKind.point));
    });

    test('the green run-on is dashed, so it reads as a different claim', () {
      final greenLine = layers.firstWhere((l) => l['id'] == 'measure-green-line');
      expect((greenLine['paint'] as Map)['line-dasharray'], isNotNull);
    });

    test('uses no symbol layers and needs no glyph endpoint', () {
      expect(layers.map((l) => l['type']), isNot(contains('symbol')));
      expect(style.containsKey('glyphs'), isFalse);
    });

    test('layer ids are unique', () {
      final ids = layers.map((l) => l['id']).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
