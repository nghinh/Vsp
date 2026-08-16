// Names on the shapes — VSP Mobile App
//
// A hole map is a set of coloured blobs until each one says what it is. The
// legend in the corner tells a golfer that green means green; it does not
// tell them which of the three blobs on this screen is the one they must
// carry. That has to be written on the blob.
//
// Where the label sits, and which distance it carries, is different per
// layer. A green is a target, so it is labelled at its centre with the
// distance to that centre — the number every golfer already thinks in. A
// bunker is a thing to avoid, so it is labelled with the distance to its
// near edge, which is where trouble starts.

import 'dart:math' as math;

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

class FeatureLabel {
  const FeatureLabel({
    required this.layer,
    required this.at,
    required this.meters,
  });

  /// Which layer, so the chip can carry the layer's own colour and name.
  final MapLayerType layer;

  /// Where on the ground the chip belongs.
  final LatLng at;

  /// From the golfer: to the centre for a green, to the near edge otherwise.
  final double meters;
}

abstract final class FeatureLabels {
  /// The layers worth naming. A fairway label sits in the middle of the
  /// screen saying "fairway" over ground the golfer can see is fairway, and
  /// a rough label is worse. Both are drawn; neither is named.
  static const _labelled = {
    MapLayerType.green,
    MapLayerType.bunker,
    MapLayerType.water,
    MapLayerType.penaltyArea,
    MapLayerType.ob,
    MapLayerType.tee,
  };

  /// Labels for everything on this hole worth naming, nearest first.
  ///
  /// [limit] is a screen-space decision rather than a data one: past half a
  /// dozen chips they overlap each other and the shapes underneath, and a
  /// golfer reads none of them.
  static List<FeatureLabel> forLayers({
    required Map<MapLayerType, MapLayerEntity> layers,
    required LatLng from,
    int limit = 6,
  }) {
    final labels = <FeatureLabel>[];

    for (final entry in layers.entries) {
      if (!_labelled.contains(entry.key)) continue;
      for (final ring in _ringsOf(entry.value)) {
        if (ring.isEmpty) continue;

        var sumLat = 0.0;
        var sumLng = 0.0;
        var near = double.infinity;
        for (final point in ring) {
          sumLat += point.latitude;
          sumLng += point.longitude;
          near = math.min(near, from.distanceTo(point));
        }
        final centre = LatLng(
          latitude: sumLat / ring.length,
          longitude: sumLng / ring.length,
        );

        labels.add(FeatureLabel(
          layer: entry.key,
          at: centre,
          meters: entry.key == MapLayerType.green
              ? from.distanceTo(centre)
              : near,
        ));
      }
    }

    labels.sort((a, b) => a.meters.compareTo(b.meters));
    return labels.length <= limit ? labels : labels.sublist(0, limit);
  }

  /// Every outer ring in a layer's GeoJSON.
  ///
  /// Holes in a polygon are skipped: an island green's pond is drawn by the
  /// map but is not a separate thing to name.
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
          final ring = _ring(coordinates is List && coordinates.isNotEmpty
              ? coordinates.first
              : null);
          if (ring != null) rings.add(ring);
        case 'MultiPolygon':
          if (coordinates is! List) break;
          for (final polygon in coordinates) {
            final ring = _ring(
                polygon is List && polygon.isNotEmpty ? polygon.first : null);
            if (ring != null) rings.add(ring);
          }
      }
    }
    return rings;
  }

  static List<LatLng>? _ring(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final ring = <LatLng>[];
    for (final point in raw) {
      if (point is! List || point.length < 2) continue;
      final lng = point[0];
      final lat = point[1];
      if (lng is! num || lat is! num) continue;
      ring.add(LatLng(latitude: lat.toDouble(), longitude: lng.toDouble()));
    }
    // GeoJSON repeats the first vertex to close the ring. Averaging over it
    // counts that one corner twice and drags the label off the middle of the
    // shape towards it — about four metres on a bunker, which is enough to
    // put the chip on the grass beside the sand.
    if (ring.length > 1 && ring.first == ring.last) {
      ring.removeLast();
    }
    return ring.isEmpty ? null : ring;
  }
}
