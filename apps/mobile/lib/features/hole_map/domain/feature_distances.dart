// How far to each shape on the hole — VSP Mobile App
//
// A polygon has two distances that matter and they are not its centre: the
// near edge, which is what a golfer must not reach, and the far edge, which
// is what they must carry. "Bunker 142 / 158" is a club decision; "bunker
// 150" is a fact about a centroid nobody is aiming at.
//
// Only what is still ahead. A hazard behind the golfer is scenery, and a
// panel that lists it pushes the one they are about to hit off the screen.

import 'dart:math' as math;

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

class MeasuredFeature {
  const MeasuredFeature({
    required this.layer,
    required this.nearMeters,
    required this.farMeters,
  });

  final MapLayerType layer;
  final double nearMeters;
  final double farMeters;
}

abstract final class FeatureDistances {
  /// Layers worth a number. Rough and cart paths are neither a target nor a
  /// hazard, and listing them buries the two that are.
  static const _measured = {
    MapLayerType.green,
    MapLayerType.bunker,
    MapLayerType.water,
    MapLayerType.penaltyArea,
    MapLayerType.ob,
  };

  /// Everything ahead of [from], nearest first.
  ///
  /// "Ahead" is measured along the line to [target] — the flag, usually. A
  /// shape whose nearest point is behind that line is behind the golfer, and
  /// a golfer walking up the hole leaves hazards behind them constantly.
  static List<MeasuredFeature> ahead({
    required Map<MapLayerType, MapLayerEntity> layers,
    required LatLng from,
    LatLng? target,
    int limit = 4,
  }) {
    final measured = <MeasuredFeature>[];

    for (final entry in layers.entries) {
      if (!_measured.contains(entry.key)) continue;
      for (final ring in _ringsOf(entry.value)) {
        if (ring.isEmpty) continue;
        var near = double.infinity;
        var far = 0.0;
        for (final point in ring) {
          final metres = from.distanceTo(point);
          near = math.min(near, metres);
          far = math.max(far, metres);
        }
        if (near.isInfinite) continue;
        if (target != null && !_isAhead(from: from, target: target, ring: ring)) {
          continue;
        }
        measured.add(MeasuredFeature(
          layer: entry.key,
          nearMeters: near,
          farMeters: far,
        ));
      }
    }

    measured.sort((a, b) => a.nearMeters.compareTo(b.nearMeters));
    return measured.take(limit).toList();
  }

  /// True when any part of the ring lies on the target's side of the golfer.
  ///
  /// Projected onto the line of play, so a bunker level with the golfer but
  /// twenty metres left of them still counts — it is beside the shot, not
  /// behind it.
  static bool _isAhead({
    required LatLng from,
    required LatLng target,
    required List<LatLng> ring,
  }) {
    final dx = target.longitude - from.longitude;
    final dy = target.latitude - from.latitude;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return true;

    for (final point in ring) {
      final px = point.longitude - from.longitude;
      final py = point.latitude - from.latitude;
      // Fraction along the line of play, 0 at the golfer, 1 at the target.
      final along = (px * dx + py * dy) / lengthSquared;
      if (along > 0.02) return true;
    }
    return false;
  }

  /// Every ring in a layer's GeoJSON, flattened. Polygons and multipolygons
  /// alike; a hole's water is often two ponds in one feature.
  static List<List<LatLng>> _ringsOf(MapLayerEntity layer) {
    final geoJson = layer.geoJson;
    if (geoJson == null) return const [];
    final features = geoJson['features'];
    if (features is! List) return const [];

    final rings = <List<LatLng>>[];
    for (final feature in features) {
      if (feature is! Map) continue;
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final coordinates = geometry['coordinates'];
      switch (geometry['type']) {
        case 'Polygon':
          _addRing(rings, coordinates);
        case 'MultiPolygon':
          if (coordinates is List) {
            for (final polygon in coordinates) {
              _addRing(rings, polygon);
            }
          }
        case 'Point':
          if (coordinates is List && coordinates.length >= 2) {
            rings.add([
              LatLng(
                latitude: (coordinates[1] as num).toDouble(),
                longitude: (coordinates[0] as num).toDouble(),
              ),
            ]);
          }
      }
    }
    return rings;
  }

  static void _addRing(List<List<LatLng>> rings, dynamic polygon) {
    if (polygon is! List || polygon.isEmpty) return;
    final outer = polygon.first;
    if (outer is! List) return;
    final ring = <LatLng>[];
    for (final point in outer) {
      if (point is List && point.length >= 2) {
        ring.add(LatLng(
          latitude: (point[1] as num).toDouble(),
          longitude: (point[0] as num).toDouble(),
        ));
      }
    }
    if (ring.isNotEmpty) rings.add(ring);
  }
}
