// Tests for where the strategic map points.
//
// It pointed at the pin, and failing that at the golfer. A course package
// carries no pin positions, so in practice it always pointed at the golfer —
// which frames the hole correctly in exactly one situation: standing on it.
// Opening the map from the clubhouse, or stepping to the next hole to look at
// it before playing it, aimed the camera at the golfer and left the hole
// outside the frame. On a phone 1135 km away it drew an empty canvas, which
// reads as a broken map rather than a misaimed one.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/domain/golfer_position_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

/// A layer whose coordinates sit around ([lat], [lng]).
MapLayerEntity layerAt(MapLayerType type, double lat, double lng) =>
    MapLayerEntity(
      type: type,
      format: LayerGeometryFormat.geoJson,
      style: const LayerStyle(),
      geoJson: {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [lng - 0.0001, lat - 0.0001],
                  [lng + 0.0001, lat - 0.0001],
                  [lng + 0.0001, lat + 0.0001],
                  [lng - 0.0001, lat + 0.0001],
                  [lng - 0.0001, lat - 0.0001],
                ],
              ],
            },
          },
        ],
      },
    );

HoleMapEntity holeWith({
  Map<MapLayerType, MapLayerEntity> layers = const {},
  GolferPositionEntity? golfer,
}) => HoleMapEntity(
  courseId: '8',
  courseName: 'Long Thành Golf Resort — Championship',
  holeNumber: 1,
  par: 4,
  layers: layers,
  golferPosition: golfer,
);

GolferPositionEntity golferAt(double lat, double lng) => GolferPositionEntity(
  latitude: lat,
  longitude: lng,
  accuracy: 8,
  source: PositionSource.gps,
  confidence: PositionConfidence.high,
  timestamp: DateTime.utc(2026, 8, 7),
);

/// The golfer, in Hà Nội. The hole is in Đồng Nai.
GolferPositionEntity get golferFarAway => golferAt(21.0184736, 105.8091544);

void main() {
  group('a hole with geometry', () {
    test('is framed by its own shapes', () {
      final hole = holeWith(
        layers: {
          MapLayerType.tee: layerAt(MapLayerType.tee, 10.8580, 106.9000),
          MapLayerType.green: layerAt(MapLayerType.green, 10.8620, 106.9040),
        },
      );

      // Midway between tee and green, so both ends are in shot.
      expect(hole.mapCenterLat, closeTo(10.8600, 1e-4));
      expect(hole.mapCenterLng, closeTo(106.9020, 1e-4));
    });

    test('ignores a golfer who is nowhere near it', () {
      final hole = holeWith(
        layers: {
          MapLayerType.green: layerAt(MapLayerType.green, 10.8620, 106.9040),
        },
        golfer: golferFarAway,
      );

      // This is the whole bug: centring on the golfer put Đồng Nai off screen
      // and drew nothing.
      expect(hole.mapCenterLat, closeTo(10.8620, 1e-4));
      expect(hole.mapCenterLat, isNot(closeTo(21.0184736, 0.1)));
    });

    test('a golfer standing on the hole is still framed with it', () {
      final hole = holeWith(
        layers: {
          MapLayerType.tee: layerAt(MapLayerType.tee, 10.8580, 106.9000),
          MapLayerType.green: layerAt(MapLayerType.green, 10.8620, 106.9040),
        },
        golfer: golferAt(10.8581, 106.9001),
      );

      // Nothing is lost by preferring the hole: on the tee, the hole centre is
      // a few hundred metres away and both are on screen at hole zoom.
      expect(hole.mapCenterLat, closeTo(10.8600, 1e-4));
    });

    test('cart paths alone do not aim the camera', () {
      final hole = holeWith(
        layers: {
          MapLayerType.cartPath: layerAt(MapLayerType.cartPath, 10.9, 106.5),
        },
        golfer: golferFarAway,
      );

      // A cart path is not the hole, and a hole with nothing else is the case
      // the satellite path handles.
      expect(hole.mapCenterLat, closeTo(21.0184736, 1e-4));
    });
  });

  group('a hole with no geometry', () {
    test('falls back to the golfer', () {
      final hole = holeWith(golfer: golferFarAway);

      expect(hole.mapCenterLat, closeTo(21.0184736, 1e-4));
    });

    test('has nowhere to point with no golfer either', () {
      expect(holeWith().mapCenterLat, isNull);
      expect(holeWith().mapCenterLng, isNull);
    });
  });
}
