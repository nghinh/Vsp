// Names on the shapes — VSP Mobile App
//
// A hole map is a set of coloured blobs until each one says what it is. The
// legend in the corner tells a golfer that green means green; it does not
// tell them which of the three blobs on this screen is the one they must
// carry. That has to be written on the blob.
//
// Every chip carries two numbers: the near edge and the far edge.
//
// It used to carry one, and for the green that one was the distance to its
// centroid — on the reasoning that a green is a target and the middle is the
// number every golfer already thinks in. The middle is *a* number a golfer
// thinks in, alongside the front and the back, and it is the only one of the
// three that nothing on the ground corresponds to. A green 30 m deep is two
// clubs from front to back. Quoting its centre and nothing else hands the
// golfer a figure that is wrong by half that in whichever direction they
// cannot see.
//
// The same goes the other way for a hazard. The near edge is where trouble
// starts and it was the only number shown, so a bunker the golfer could not
// carry looked identical to one they could: "bunker 142" says nothing about
// whether 150 clears it. What decides the club is 142 *and* 158.
//
// So: near and far, for everything. One number only where the shape is too
// small for the second to mean anything.

import 'dart:math' as math;

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';

class FeatureLabel {
  const FeatureLabel({
    required this.layer,
    required this.at,
    required this.nearMeters,
    required this.farMeters,
  });

  /// Which layer, so the chip can carry the layer's own colour and name.
  final MapLayerType layer;

  /// Where on the ground the chip belongs.
  final LatLng at;

  /// Golfer to the near edge — what it takes to reach this shape.
  final double nearMeters;

  /// Golfer to the far edge — what it takes to carry it.
  final double farMeters;

  /// Below this the two edges are the same club and the same number, and
  /// printing both would suggest the outline is more precise than it is.
  /// The same threshold [FeatureDistancePanel] uses, so the chip on a shape
  /// and the panel listing it never disagree about whether it has depth.
  static const double depthThresholdMeters = 8.0;

  /// True when the far edge is far enough past the near one to be worth
  /// saying.
  bool get hasDepth => farMeters - nearMeters > depthThresholdMeters;
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
        var far = 0.0;
        for (final point in ring) {
          sumLat += point.latitude;
          sumLng += point.longitude;
          final metres = from.distanceTo(point);
          near = math.min(near, metres);
          far = math.max(far, metres);
        }
        // The chip still *sits* on the middle of the shape — that is where
        // there is room for it and what it is pointing at. What it says is
        // measured to the edges.
        final centre = LatLng(
          latitude: sumLat / ring.length,
          longitude: sumLng / ring.length,
        );

        labels.add(FeatureLabel(
          layer: entry.key,
          at: centre,
          nearMeters: near,
          farMeters: far,
        ));
      }
    }

    labels.sort((a, b) => a.nearMeters.compareTo(b.nearMeters));
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
