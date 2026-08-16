// Tests for CourseMapStyleBuilder — the vector hole-map style built in Dart.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/domain/course_map_style_builder.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_geojson.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

void main() {
  final style = CourseMapStyleBuilder.buildStyleMap();
  final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
  final layerIds = [for (final l in layers) l['id'] as String];

  group('CourseMapStyleBuilder', () {
    test('is a self-contained MapLibre v8 style', () {
      expect(style['version'], 8);
      // No glyphs, no sprite, no remote tiles: the map has to draw on a course
      // with no signal, and every symbol layer would need a font server.
      expect(style.containsKey('glyphs'), isFalse);
      expect(style.containsKey('sprite'), isFalse);
      expect(
        layers.where((l) => l['type'] == 'symbol'),
        isEmpty,
        reason: 'symbol layers need a glyph endpoint',
      );
      expect(jsonEncode(style), isNot(contains('http')));
    });

    test('reads geometry from local GeoJSON sources only', () {
      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources.keys, [
        CourseMapStyleBuilder.courseSourceId,
        CourseMapStyleBuilder.overlaySourceId,
      ]);
      for (final source in sources.values) {
        expect((source as Map)['type'], 'geojson');
      }
    });

    test('draws every course layer and every overlay marker', () {
      for (final type in CourseMapStyleBuilder.courseLayerOrder) {
        expect(
          CourseMapStyleBuilder.styleLayerIds(type.name),
          isNotEmpty,
          reason: '${type.name} has no style layer',
        );
        for (final id in CourseMapStyleBuilder.styleLayerIds(type.name)) {
          expect(layerIds, contains(id));
        }
      }
      expect(
        layerIds,
        containsAll([
          'golfer-accuracy-fill',
          'golfer-circle',
          'pin-circle',
          'target-marker',
          'distance-ring-100',
          'distance-ring-150',
          'distance-ring-200',
        ]),
      );
    });

    test('every toggleable layer id resolves to real style layers', () {
      // These are the ids LayerTogglePanel emits.
      const toggleable = [
        'fairway',
        'green',
        'rough',
        'bunker',
        'water',
        'penaltyArea',
        'ob',
        'cartPath',
        'landmark',
        'distanceRing100',
        'distanceRing150',
        'distanceRing200',
      ];
      for (final id in toggleable) {
        final styleIds = CourseMapStyleBuilder.styleLayerIds(id);
        expect(styleIds, isNotEmpty, reason: '$id toggles nothing');
        expect(layerIds, containsAll(styleIds));
      }
    });

    test('a course layer filters on its own features only', () {
      final greenFill = layers.firstWhere((l) => l['id'] == 'green-fill');
      expect(greenFill['source'], CourseMapStyleBuilder.courseSourceId);
      // One clause, and the same shape as the overlay's filters. The compound
      // form this replaces — `all` over `==` over `match` over `geometry-type`
      // over `coalesce` — drew nothing at all on device while reading
      // correctly on paper. Which layer draws a feature is decided in
      // HoleMapGeoJson now, and the feature arrives carrying the answer.
      expect(greenFill['filter'], [
        '==',
        ['get', HoleMapGeoJson.fillKey],
        MapLayerType.green.name,
      ]);
    });

    test('the accuracy disc is a fill, because the geometry is a polygon', () {
      final accuracy = layers.firstWhere(
        (l) => l['id'] == 'golfer-accuracy-fill',
      );
      expect(accuracy['type'], 'fill');
      expect(accuracy['filter'], [
        '==',
        ['get', 'layerType'],
        HoleMapFeatureKind.golferAccuracy,
      ]);
    });

    test('layer ids are unique and the style serialises', () {
      expect(layerIds.toSet(), hasLength(layerIds.length));
      expect(CourseMapStyleBuilder.build(), jsonEncode(style));
    });

    test('the golfer draws above the course geometry', () {
      expect(
        layerIds.indexOf('golfer-circle'),
        greaterThan(layerIds.indexOf('fairway-fill')),
      );
      expect(layerIds.first, 'background');
    });
  });
}
