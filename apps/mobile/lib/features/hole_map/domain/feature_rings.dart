// Pulling rings out of a layer's GeoJSON — VSP Mobile App
//
// Three different files grew their own copy of "walk a FeatureCollection and
// collect the outer rings", and three copies is two chances to fix a bug in
// one and not the others. This is the one copy.

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

abstract final class FeatureRings {
  /// Every outer ring in a layer, from Polygon and MultiPolygon alike.
  ///
  /// Interior rings — the hole in an island green's pond — are dropped: they
  /// are not a separate shape to measure or name. A hole's water is often two
  /// ponds in one feature, so this flattens across features too.
  static List<List<LatLng>> outerRings(MapLayerEntity layer) {
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
          _addOuter(rings, coordinates);
        case 'MultiPolygon':
          if (coordinates is List) {
            for (final polygon in coordinates) {
              _addOuter(rings, polygon);
            }
          }
        case 'Point':
          if (coordinates is List && coordinates.length >= 2) {
            rings.add([_point(coordinates)]);
          }
      }
    }
    return rings;
  }

  static void _addOuter(List<List<LatLng>> rings, dynamic polygon) {
    if (polygon is! List || polygon.isEmpty) return;
    final outer = polygon.first;
    if (outer is! List) return;
    final ring = <LatLng>[];
    for (final point in outer) {
      if (point is List && point.length >= 2) {
        ring.add(_point(point));
      }
    }
    if (ring.isNotEmpty) rings.add(ring);
  }

  static LatLng _point(List<dynamic> coord) => LatLng(
        latitude: (coord[1] as num).toDouble(),
        longitude: (coord[0] as num).toDouble(),
      );
}
