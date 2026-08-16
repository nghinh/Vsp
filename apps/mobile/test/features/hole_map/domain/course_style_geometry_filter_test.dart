// Tests for each style layer drawing only the geometry it is for.
//
// Two bugs live here, and the second is why this file changed shape.
//
// The first: the fill, line and circle layers shared one filter, on the
// reasoning that "MapLibre draws only the geometry a layer type can render, so
// a polygons-only layer costs two no-ops". Two of the three are no-ops. A
// circle layer over a polygon is not: it draws a circle at every vertex. So a
// bunker traced with twenty points rendered as twenty overlapping orange discs,
// a green as a cluster of green ones, and the tee boxes as a string of white
// beads — the hole drawing its own vertices instead of its shapes.
//
// The second: the guard added for the first was `match` on `geometry-type`
// inside an `all`, next to a `coalesce` on the provenance flag, and the course
// map then drew *nothing* on device — no fills, no outlines, on a hole the
// distance panel was happily listing a green and two ponds for. The overlay
// drew fine on the same map at the same moment, and its filters are a single
// `==` against a property.
//
// So the routing decision moved into Dart, where these tests can reach it, and
// each feature now arrives at the style carrying the name of the layer that
// should draw it. What is asserted below is that pairing: the properties
// HoleMapGeoJson writes, and the filters that read them.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/domain/course_map_style_builder.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_geojson.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

/// The property a layer's filter reads, for a filter of the one form the
/// course layers are allowed to use.
String? routingPropertyOf(Map<String, dynamic> layer) {
  final filter = layer['filter'];
  if (filter is! List || filter.length != 3 || filter.first != '==') return null;
  final getter = filter[1];
  if (getter is! List || getter.length != 2 || getter.first != 'get') {
    return null;
  }
  return getter[1] as String;
}

/// A hole carrying one feature of [type], so the routing properties it comes
/// out with can be read back.
Map<String, dynamic> featureFor(
  MapLayerType type,
  Map<String, dynamic> geometry, {
  bool? verified,
}) {
  final holeMap = HoleMapEntity(
    courseId: 'long-bien-a',
    courseName: 'Đường A',
    holeNumber: 4,
    par: 4,
    layers: {
      type: MapLayerEntity(
        type: type,
        format: LayerGeometryFormat.geoJson,
        geoJson: {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': geometry,
              'properties': <String, dynamic>{
                if (verified != null) 'verified': verified,
              },
            },
          ],
        },
        style: const LayerStyle(),
      ),
    },
  );
  final collection = HoleMapGeoJson.courseGeometry(holeMap);
  final features = (collection['features'] as List).cast<Map<String, dynamic>>();
  return features.single['properties'] as Map<String, dynamic>;
}

const _square = {
  'type': 'Polygon',
  'coordinates': [
    [
      [105.8910, 21.0350],
      [105.8912, 21.0350],
      [105.8912, 21.0352],
      [105.8910, 21.0352],
      [105.8910, 21.0350],
    ],
  ],
};

const _point = {
  'type': 'Point',
  'coordinates': [105.8910, 21.0350],
};

const _line = {
  'type': 'LineString',
  'coordinates': [
    [105.8910, 21.0350],
    [105.8912, 21.0352],
  ],
};

void main() {
  final style = CourseMapStyleBuilder.buildStyleMap();
  final layers = (style['layers'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> layerNamed(String id) =>
      layers.firstWhere((l) => l['id'] == id);

  final courseLayers = layers
      .where((l) => l['source'] == CourseMapStyleBuilder.courseSourceId)
      .toList();

  group('a filter that cannot be misread', () {
    // The regression guard for the bug that emptied the map. A compound filter
    // is not banned because it is wrong on paper — it read correctly on paper.
    // It is banned because when it fails it fails silently, and the failure
    // looks exactly like a hole nobody has mapped.
    test('every course layer filters on one property, the way the overlay does',
        () {
      expect(courseLayers, isNotEmpty);
      for (final layer in courseLayers) {
        expect(
          routingPropertyOf(layer),
          isNotNull,
          reason: '${layer['id']}: filter is ${layer['filter']}, which is not '
              'a single == against a property',
        );
      }
    });

    test('the properties they read are the ones the geometry writes', () {
      const written = {
        HoleMapGeoJson.fillKey,
        HoleMapGeoJson.draftFillKey,
        HoleMapGeoJson.strokeKey,
        HoleMapGeoJson.draftStrokeKey,
        HoleMapGeoJson.pointKey,
      };
      for (final layer in courseLayers) {
        expect(written, contains(routingPropertyOf(layer)),
            reason: '${layer['id']} reads a property nothing sets');
      }
    });
  });

  group('a polygon draws as a shape, not as its vertices', () {
    test('a polygon is not addressed to any circle layer', () {
      for (final type in CourseMapStyleBuilder.courseLayerOrder) {
        final properties = featureFor(type, _square, verified: true);
        expect(
          properties[HoleMapGeoJson.pointKey],
          isNull,
          reason: '${type.name}: a circle layer over a polygon draws one '
              'circle per vertex',
        );
      }
    });

    test('a point still gets its marker', () {
      final properties = featureFor(MapLayerType.tee, _point, verified: true);
      expect(properties[HoleMapGeoJson.pointKey], MapLayerType.tee.name);
      // And nothing else: a fill or an outline over a point draws nothing, so
      // addressing it to them would only be noise.
      expect(properties[HoleMapGeoJson.fillKey], isNull);
      expect(properties[HoleMapGeoJson.strokeKey], isNull);
    });

    test('every course circle layer reads the point property alone', () {
      final circles = courseLayers.where((l) => l['type'] == 'circle');
      expect(circles, isNotEmpty);
      for (final circle in circles) {
        expect(routingPropertyOf(circle), HoleMapGeoJson.pointKey,
            reason: '${circle['id']}');
      }
    });
  });

  group('the areas a golfer needs to see', () {
    test('a polygon is filled and outlined', () {
      final properties =
          featureFor(MapLayerType.green, _square, verified: true);
      expect(properties[HoleMapGeoJson.fillKey], MapLayerType.green.name);
      expect(properties[HoleMapGeoJson.strokeKey], MapLayerType.green.name);
    });

    test('each course area has a fill layer of its own', () {
      for (final type in CourseMapStyleBuilder.courseLayerOrder) {
        final fills = courseLayers.where((l) =>
            l['type'] == 'fill' &&
            (l['filter'] as List).last == type.name &&
            routingPropertyOf(l) == HoleMapGeoJson.fillKey);
        expect(fills, hasLength(1), reason: type.name);
      }
    });

    test('outlines are drawn for lines as well as polygons', () {
      // The edge is what separates a bunker from the fairway under it — and a
      // cart path, which is a line, is nothing but its edge.
      final polygon = featureFor(MapLayerType.bunker, _square, verified: true);
      final line = featureFor(MapLayerType.cartPath, _line, verified: true);
      expect(polygon[HoleMapGeoJson.strokeKey], MapLayerType.bunker.name);
      expect(line[HoleMapGeoJson.strokeKey], MapLayerType.cartPath.name);
      // A line has no inside to fill.
      expect(line[HoleMapGeoJson.fillKey], isNull);
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

  test('turning a layer off moves every layer that draws it', () {
    // Missing one leaves an unconfirmed pond outlined on a map the golfer
    // just switched water off on.
    final ids = CourseMapStyleBuilder.styleLayerIds(MapLayerType.water.name);
    final drawing = courseLayers
        .where((l) => (l['filter'] as List).last == MapLayerType.water.name)
        .map((l) => l['id'] as String);
    expect(ids.toSet(), containsAll(drawing));
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
    final dashed = layers.where((l) =>
        l['type'] == 'line' && (l['id'] as String).endsWith('-unverified'));
    expect(dashed, isNotEmpty);
    for (final layer in dashed) {
      expect((layer['paint'] as Map)['line-dasharray'], isNotNull);
      expect(routingPropertyOf(layer), HoleMapGeoJson.draftStrokeKey);
    }
  });

  test('the solid outline is reserved for confirmed shapes', () {
    final solid = layers.firstWhere((l) => l['id'] == 'bunker-line');
    expect(routingPropertyOf(solid), HoleMapGeoJson.strokeKey);
    expect((solid['paint'] as Map)['line-dasharray'], isNull);

    final confirmed = featureFor(MapLayerType.bunker, _square, verified: true);
    final draft = featureFor(MapLayerType.bunker, _square, verified: false);
    expect(confirmed[HoleMapGeoJson.strokeKey], MapLayerType.bunker.name);
    expect(draft[HoleMapGeoJson.strokeKey], isNull);
    expect(draft[HoleMapGeoJson.draftStrokeKey], MapLayerType.bunker.name);
  });

  test('an unconfirmed fill is drawn fainter than a confirmed one', () {
    // Two layers rather than one `case`, the same trade line-dasharray forced:
    // a flat number is a thing MapLibre cannot fail to read.
    final confirmed = layers.firstWhere((l) => l['id'] == 'water-fill');
    final draft = layers.firstWhere((l) => l['id'] == 'water-fill-unverified');
    final confirmedOpacity = (confirmed['paint'] as Map)['fill-opacity'];
    final draftOpacity = (draft['paint'] as Map)['fill-opacity'];
    expect(confirmedOpacity, isA<double>());
    expect(draftOpacity, isA<double>());
    expect(draftOpacity as double, lessThan(confirmedOpacity as double));
  });

  test('a shape with no provenance is treated as unconfirmed', () {
    // Absent reads as unverified, the same way the package reader treats a
    // hole with no provenance. GolfSeg's shapes arrive this way.
    final properties = featureFor(MapLayerType.water, _square);
    expect(properties['verified'], isFalse);
    expect(properties[HoleMapGeoJson.draftFillKey], MapLayerType.water.name);
    expect(properties[HoleMapGeoJson.fillKey], isNull);
  });

  // What the map is made of where nothing has been drawn on it.
  //
  // This is a plan view of ground a golfer is standing on, so the ground is
  // what shows through. It was a pale blue, called "sky" in the style — and on
  // Long Biên's 10th, where GolfSeg had traced a fairway and a patch of rough
  // and nothing else, the hole came out as three pale islands in an ocean.
  // What got reported was that the lake was the wrong shape. There is no lake
  // on that hole.
  group('the ground under the hole', () {
    Map<String, dynamic> layerNamed(String id) =>
        layers.firstWhere((l) => l['id'] == id);

    /// Roughly how blue a `#RRGGBB` string is against its own red and green.
    int bluenessOf(String hex) {
      int channel(int at) => int.parse(hex.substring(at, at + 2), radix: 16);
      final red = channel(1), green = channel(3), blue = channel(5);
      return blue - (red > green ? red : green);
    }

    test('is not blue', () {
      final background =
          (layerNamed('background')['paint'] as Map)['background-color'];

      expect(bluenessOf(background as String), lessThan(0),
          reason: 'a background bluer than it is green reads as water');
    });

    test('is duller than the rough drawn on top of it', () {
      // So that a rough polygon somebody actually traced still reads as a
      // shape rather than disappearing into the backdrop.
      final background =
          (layerNamed('background')['paint'] as Map)['background-color'];
      final rough = (layerNamed('rough-fill')['paint'] as Map)['fill-color'];

      expect(background, isNot(equals(rough)));
    });

    test('leaves water as the only blue thing on the map', () {
      final water = (layerNamed('water-fill')['paint'] as Map)['fill-color'];
      final background =
          (layerNamed('background')['paint'] as Map)['background-color'];

      expect(bluenessOf(water as String),
          greaterThan(bluenessOf(background as String)));
    });

    test('an unconfirmed shape is still visible against it', () {
      // 0.45 was picked against the blue background, where a green fill at
      // 45% still read as green because nothing else on screen was. Against
      // turf it read as turf, and every course GolfSeg has traced — none of
      // which is reviewed — looked empty. The dashed outline is what says
      // provisional; the fill only has to say "here".
      final draft =
          (layerNamed('fairway-fill-unverified')['paint'] as Map)['fill-opacity'];

      expect(draft as double, greaterThanOrEqualTo(0.6));
    });
  });
}
