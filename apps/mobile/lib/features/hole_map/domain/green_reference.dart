// Front, centre and back of the green — VSP Mobile App
//
// The three numbers a golfer reads before every approach, and the reason the
// green is not just another shape with a near and a far edge. Front is what
// carries the false front; back is what holds a back pin without flying the
// green; centre is what they aim at when they cannot see the flag.
//
// Measured along the line the golfer is playing, never north-to-south. A green
// is longest front-to-back along the approach, and "front" only means anything
// relative to where the shot is coming from — the same green gives different
// front and back numbers from the fairway and from a greenside bunker, and
// both are correct.
//
// Pure geometry. §30: the distance engine takes a polygon and a position and
// returns metres, deterministically. No model is consulted and none could
// help — this is arithmetic a golfer can check with a rangefinder.

import 'dart:math' as math;

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

class GreenReference {
  const GreenReference({
    required this.frontMeters,
    required this.centreMeters,
    required this.backMeters,
    required this.front,
    required this.centre,
    required this.back,
  });

  /// To the near edge, the centre, and the far edge — along the approach.
  final double frontMeters;
  final double centreMeters;
  final double backMeters;

  /// The points themselves, so the map can mark them.
  final LatLng front;
  final LatLng centre;
  final LatLng back;

  /// How deep the green plays front-to-back, which is the club spread between
  /// a front pin and a back one.
  double get depthMeters => backMeters - frontMeters;

  /// Front, centre and back of a green, from where the golfer stands.
  ///
  /// [greenRing] is the green's outline in order. [from] is the golfer — or
  /// the tee, before there is a fix. Returns null for a ring too small to have
  /// a front and a back, which is a point mislabelled as a polygon rather than
  /// a green.
  static GreenReference? of({
    required List<LatLng> greenRing,
    required LatLng from,
  }) {
    if (greenRing.length < 3) return null;

    final centre = _centroid(greenRing);
    // The approach runs from the golfer to the middle of the green. Everything
    // is projected onto it: the vertex furthest back along that line is the
    // back of the green, the one least far is the front.
    final scale = _metresPerDegree(from.latitude);
    final ax = (centre.longitude - from.longitude) * scale.x;
    final ay = (centre.latitude - from.latitude) * scale.y;
    final axisLength = math.sqrt(ax * ax + ay * ay);
    if (axisLength == 0) return null;
    final ux = ax / axisLength;
    final uy = ay / axisLength;

    LatLng? frontVertex;
    LatLng? backVertex;
    var minAlong = double.infinity;
    var maxAlong = double.negativeInfinity;
    for (final vertex in greenRing) {
      final vx = (vertex.longitude - from.longitude) * scale.x;
      final vy = (vertex.latitude - from.latitude) * scale.y;
      final along = vx * ux + vy * uy;
      if (along < minAlong) {
        minAlong = along;
        frontVertex = vertex;
      }
      if (along > maxAlong) {
        maxAlong = along;
        backVertex = vertex;
      }
    }
    if (frontVertex == null || backVertex == null) return null;

    return GreenReference(
      frontMeters: from.distanceTo(frontVertex),
      centreMeters: from.distanceTo(centre),
      backMeters: from.distanceTo(backVertex),
      front: frontVertex,
      centre: centre,
      back: backVertex,
    );
  }

  static LatLng _centroid(List<LatLng> ring) {
    // Area-weighted centroid (the shoelace centroid), so a green with a long
    // tail does not pull its middle towards the crowded end the way a plain
    // vertex average would. Falls back to the vertex mean for a degenerate
    // ring.
    //
    // Computed relative to the first vertex. The cross products are
    // differences of longitude×latitude, which at 105°E · 21°N are ~2200 —
    // and subtracting two such numbers throws away most of a double's
    // precision, enough to move a green's centre 15 m. Shifting the origin to
    // the ring makes the coordinates small and the subtraction exact.
    final origin = ring.first;
    var twiceArea = 0.0;
    var cx = 0.0;
    var cy = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final ax = ring[i].longitude - origin.longitude;
      final ay = ring[i].latitude - origin.latitude;
      final bx = ring[(i + 1) % ring.length].longitude - origin.longitude;
      final by = ring[(i + 1) % ring.length].latitude - origin.latitude;
      final cross = ax * by - bx * ay;
      twiceArea += cross;
      cx += (ax + bx) * cross;
      cy += (ay + by) * cross;
    }
    if (twiceArea.abs() < 1e-12) {
      var sumLat = 0.0;
      var sumLng = 0.0;
      for (final point in ring) {
        sumLat += point.latitude;
        sumLng += point.longitude;
      }
      return LatLng(
        latitude: sumLat / ring.length,
        longitude: sumLng / ring.length,
      );
    }
    // cx/cy are relative to the shifted origin — add it back.
    return LatLng(
      latitude: origin.latitude + cy / (3 * twiceArea),
      longitude: origin.longitude + cx / (3 * twiceArea),
    );
  }

  /// Metres per degree of longitude and latitude at this latitude, so a dot
  /// product is taken in a locally isotropic space rather than in degrees —
  /// where a degree of longitude at 21°N is 8% shorter than a degree of
  /// latitude, and the projection would lean east.
  static ({double x, double y}) _metresPerDegree(double latitude) => (
        x: 111320.0 * math.cos(latitude * math.pi / 180.0),
        y: 111132.0,
      );
}
