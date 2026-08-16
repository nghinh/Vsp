// Front and back of the green, and what was eating them.
//
// A golfer plays to the front edge and carries to the back. The app has both
// numbers — GreenReferencePanel draws front / centre / back, FeatureDistances
// reports a near and a far edge for every hazard — and on Long Biên neither
// appeared. The header read "Tới cờ 509 yd" and the panel read "Green 509 yd",
// the same figure twice, which is the signature of a distance measured to a
// single point rather than to a shape.
//
// The green was a single point. Not because nothing had traced it — GolfSeg
// had, and the API was serving the outline — but because the merge that adds
// traced shapes to package shapes was keyed on the layer's name:
//
//     Map.from(traced.layers)..addAll(package.layers)
//
// and every hole in every package carries a `green` layer. The assembler seeds
// it with the hole's own `green_location` before it adds any polygons, so on
// the 62 courses whose polygons live in the draft table, that seed point *is*
// the layer — and it overwrote the outline.
//
// Nothing about that looks broken from outside. The green still had a
// position, the play line still reached it, the map still drew. What was gone
// was its depth, and a panel that needs three coordinates to state a front and
// a back had one, so it rendered nothing rather than something wrong.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/feature_distances.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

/// A green about 40 m deep, the way a traced outline arrives.
Map<String, dynamic> get _greenOutline => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [105.8900, 21.0400],
            [105.8904, 21.0400],
            [105.8904, 21.0404],
            [105.8900, 21.0404],
            [105.8900, 21.0400],
          ],
        ],
      },
      'properties': <String, dynamic>{},
    },
  ],
};

/// What a package ships for a hole nobody has digitised: one coordinate,
/// dressed as a layer.
Map<String, dynamic> get _greenReferencePoint => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [105.8902, 21.0402],
      },
      'properties': {'layer': 'reference_point'},
    },
  ],
};

MapLayerEntity _layer(MapLayerType type, Map<String, dynamic> geoJson) =>
    MapLayerEntity(
      type: type,
      format: LayerGeometryFormat.geoJson,
      geoJson: geoJson,
      style: const LayerStyle(),
    );

/// The merge rule as the bloc applies it: traced first, then the package
/// where the package has a shape.
Map<MapLayerType, MapLayerEntity> merge({
  required Map<MapLayerType, MapLayerEntity> traced,
  required Map<MapLayerType, MapLayerEntity> package,
}) {
  final merged = Map<MapLayerType, MapLayerEntity>.from(traced);
  for (final entry in package.entries) {
    if (HoleGeometryCoverage.hasAreaGeometry(entry.value) ||
        !merged.containsKey(entry.key)) {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}

void main() {
  group('a layer that is only a coordinate', () {
    test('a reference point is not geometry', () {
      expect(
        HoleGeometryCoverage.hasAreaGeometry(
          _layer(MapLayerType.green, _greenReferencePoint),
        ),
        isFalse,
      );
    });

    test('an outline is', () {
      expect(
        HoleGeometryCoverage.hasAreaGeometry(
          _layer(MapLayerType.green, _greenOutline),
        ),
        isTrue,
      );
    });

    test('an empty layer is not', () {
      expect(
        HoleGeometryCoverage.hasAreaGeometry(
          _layer(MapLayerType.green, {
            'type': 'FeatureCollection',
            'features': <Map<String, dynamic>>[],
          }),
        ),
        isFalse,
      );
    });
  });

  group('what survives the merge', () {
    test('a traced outline is not displaced by a package reference point', () {
      // The bug, stated as the rule it broke.
      final merged = merge(
        traced: {MapLayerType.green: _layer(MapLayerType.green, _greenOutline)},
        package: {
          MapLayerType.green:
              _layer(MapLayerType.green, _greenReferencePoint),
        },
      );

      final hole = HoleMapEntity(
        courseId: 'long-bien-b',
        courseName: 'Đường B',
        holeNumber: 1,
        par: 5,
        layers: merged,
      );

      expect(HoleGeometryCoverage.greenOutline(hole).length, greaterThan(3));
    });

    test('a digitised outline still beats a traced one', () {
      // The rule that was right all along and must not be lost in the fix: a
      // green a person drew is better than a green a model traced, and two
      // greens on one hole is worse than either alone.
      final surveyed = _layer(MapLayerType.green, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [105.8910, 21.0410],
                  [105.8914, 21.0410],
                  [105.8914, 21.0414],
                  [105.8910, 21.0414],
                  [105.8910, 21.0410],
                ],
              ],
            },
            'properties': <String, dynamic>{},
          },
        ],
      });

      final merged = merge(
        traced: {MapLayerType.green: _layer(MapLayerType.green, _greenOutline)},
        package: {MapLayerType.green: surveyed},
      );

      expect(merged[MapLayerType.green], same(surveyed));
    });

    test('a layer only the package has is kept', () {
      final paths = _layer(MapLayerType.cartPath, _greenReferencePoint);
      final merged = merge(traced: const {}, package: {
        MapLayerType.cartPath: paths,
      });

      expect(merged[MapLayerType.cartPath], same(paths));
    });
  });

  group('the numbers the golfer reads', () {
    // 300 m or so south-west of the green above, standing on the fairway.
    const golfer = LatLng(latitude: 21.0375, longitude: 105.8890);

    test('an outline gives a near edge and a far edge that differ', () {
      final measured = FeatureDistances.ahead(
        layers: {MapLayerType.green: _layer(MapLayerType.green, _greenOutline)},
        from: golfer,
      );

      expect(measured, hasLength(1));
      expect(measured.first.farMeters - measured.first.nearMeters,
          greaterThan(8),
          reason: 'front and back of a 40 m green are not the same number');
    });

    test('a reference point gives the same number twice', () {
      // This is what a golfer was shown. Not a wrong distance — a distance to
      // the middle, presented as though the shape had been measured.
      final measured = FeatureDistances.ahead(
        layers: {
          MapLayerType.green:
              _layer(MapLayerType.green, _greenReferencePoint),
        },
        from: golfer,
      );

      expect(measured, hasLength(1));
      expect(measured.first.nearMeters, measured.first.farMeters);
    });
  });
}
