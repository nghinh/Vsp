// Tests for each style layer drawing only the geometry it is for.
//
// The fill, line and circle layers shared one filter, on the reasoning that
// "MapLibre draws only the geometry a layer type can render, so a polygons-only
// layer costs two no-ops". Two of the three are no-ops. A circle layer over a
// polygon is not: it draws a circle at every vertex. So a bunker traced with
// twenty points rendered as twenty overlapping orange discs, a green as a
// cluster of green ones, and the tee boxes as a string of white beads — the
// hole drawing its own vertices instead of its shapes.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/domain/course_map_style_builder.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

/// The `match` on geometry-type inside a layer's filter, as a set of kinds.
Set<String> geometryKindsOf(Map<String, dynamic> layer) {
  final filter = layer['filter'] as List;
  for (final clause in filter.skip(1)) {
    if (clause is List &&
        clause.isNotEmpty &&
        clause.first == 'match' &&
        clause[1] is List &&
        (clause[1] as List).first == 'geometry-type') {
      return ((clause[2] as List).cast<String>()).toSet();
    }
  }
  return const {};
}

void main() {
  final style = CourseMapStyleBuilder.buildStyleMap();
  final layers = (style['layers'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> layerNamed(String id) =>
      layers.firstWhere((l) => l['id'] == id);

  group('a polygon draws as a shape, not as its vertices', () {
    test('the circle layer refuses polygons', () {
      for (final type in CourseMapStyleBuilder.courseLayerOrder) {
        final circle = layers.firstWhere(
          (l) => l['type'] == 'circle' && (l['filter'] as List).any(
            (c) => c is List && c.contains(type.name),
          ),
          orElse: () => <String, dynamic>{},
        );
        if (circle.isEmpty) continue;
        expect(
          geometryKindsOf(circle),
          {'Point', 'MultiPoint'},
          reason: '${type.name}: a circle layer over a polygon draws one '
              'circle per vertex',
        );
      }
    });

    test('every circle layer in the style is point-only', () {
      final circles = layers.where((l) => l['type'] == 'circle');
      expect(circles, isNotEmpty);
      for (final circle in circles) {
        final kinds = geometryKindsOf(circle);
        // The overlay's own circle layers (golfer, pin) have no course filter
        // and are excluded by having no geometry-type clause.
        if (kinds.isEmpty) continue;
        expect(kinds.contains('Polygon'), isFalse, reason: '${circle['id']}');
      }
    });
  });

  group('the areas a golfer needs to see', () {
    test('each course area has a fill restricted to polygons', () {
      for (final type in CourseMapStyleBuilder.courseLayerOrder) {
        final fill = layers.firstWhere(
          (l) => l['type'] == 'fill' && (l['filter'] as List).any(
            (c) => c is List && c.contains(type.name),
          ),
          orElse: () => <String, dynamic>{},
        );
        if (fill.isEmpty) continue;
        expect(geometryKindsOf(fill), {'Polygon', 'MultiPolygon'},
            reason: type.name);
      }
    });

    test('outlines are drawn for polygons as well as lines', () {
      // The edge is what separates a bunker from the fairway under it.
      final line = layers.firstWhere(
        (l) =>
            l['type'] == 'line' &&
            (l['filter'] as List).any(
              (c) => c is List && c.contains(MapLayerType.bunker.name),
            ),
      );
      expect(geometryKindsOf(line), contains('Polygon'));
      expect(geometryKindsOf(line), contains('LineString'));
    });

    test('every area a package can carry is styled', () {
      // fairway, green, bunker, water, penalty area, OB and the tee — the
      // things a golfer plans a shot around.
      for (final type in [
        MapLayerType.fairway,
        MapLayerType.green,
        MapLayerType.bunker,
        MapLayerType.water,
        MapLayerType.penaltyArea,
        MapLayerType.ob,
        MapLayerType.tee,
      ]) {
        expect(CourseMapStyleBuilder.courseLayerOrder, contains(type));
      }
    });

    test('they are stacked so nothing important is buried', () {
      final order = CourseMapStyleBuilder.courseLayerOrder;
      // A fairway fill drawn after a green would cover it.
      expect(order.indexOf(MapLayerType.fairway),
          lessThan(order.indexOf(MapLayerType.green)));
      expect(order.indexOf(MapLayerType.green),
          lessThan(order.indexOf(MapLayerType.bunker)));
    });
  });

  test('the golfer overlay still has its own circle layers', () {
    // Guarding the course layers must not silence the position marker.
    expect(layerNamed('golfer-accuracy-fill'), isNotNull);
  });

  provenanceTests();
}

// ─── Provenance is per shape ─────────────────────────────────────────────────
//
// A hole is verified as a whole, but the shapes hanging off it are not all the
// same thing. On Long Thành the greens and bunkers were confirmed by a reviewer
// looking at imagery; the "water hazards" are 10 m Sentinel-2 pixels a script
// thresholded, and the fairway is a rectangle derived from the tee–green line.
// All four were drawn identically on a map badged verified, so a golfer
// planning a lay-up could not tell the bunker that is really there from the
// pond that might not be.

void provenanceTests() {
  final style = CourseMapStyleBuilder.buildStyleMap();
  final layers = (style['layers'] as List).cast<Map<String, dynamic>>();

  test('an unconfirmed shape gets its own dashed outline', () {
    final dashed = layers.where((l) => (l['id'] as String).endsWith('-unverified'));
    expect(dashed, isNotEmpty);
    for (final layer in dashed) {
      expect((layer['paint'] as Map)['line-dasharray'], isNotNull);
    }
  });

  test('the solid outline is reserved for confirmed shapes', () {
    final solid = layers.firstWhere((l) => l['id'] == 'bunker-line');
    final filter = (solid['filter'] as List).map((c) => c.toString()).join(' ');
    expect(filter, contains('verified'));
    expect((solid['paint'] as Map)['line-dasharray'], isNull);
  });

  test('an unconfirmed fill is drawn fainter than a confirmed one', () {
    final fill = layers.firstWhere((l) => l['id'] == 'water-fill');
    final opacity = (fill['paint'] as Map)['fill-opacity'];
    // A `case` expression, not a flat number: the same layer draws both.
    expect(opacity, isA<List>());
    expect((opacity as List).first, 'case');
  });

  test('a shape with no provenance is treated as unconfirmed', () {
    final dashed = layers.firstWhere((l) => l['id'] == 'water-line-unverified');
    final filter = (dashed['filter'] as List).map((c) => c.toString()).join(' ');
    // `coalesce(get(verified), false)` — absent reads as unverified, the same
    // way the package reader treats a hole with no provenance.
    expect(filter, contains('coalesce'));
  });
}
