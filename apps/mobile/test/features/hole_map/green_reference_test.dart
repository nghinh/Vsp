// Front, centre and back — the three numbers before every approach.
//
// A green is not a shape with a near and a far edge; it has a front and a back
// measured along the shot, and the same green reads differently from the
// fairway and from beside it. These tests pin that down with a green of known
// size in a known place.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/green_reference.dart';

/// A roughly 30 m (deep) × 24 m (wide) green centred on a point, its long axis
/// running north–south — the way a green fronting a hole played from the south
/// usually sits.
List<LatLng> green(double lat, double lng) {
  const halfDepth = 0.000135; // ~15 m north–south
  const halfWide = 0.000115; // ~12 m east–west
  return [
    LatLng(latitude: lat - halfDepth, longitude: lng - halfWide),
    LatLng(latitude: lat - halfDepth, longitude: lng + halfWide),
    LatLng(latitude: lat + halfDepth, longitude: lng + halfWide),
    LatLng(latitude: lat + halfDepth, longitude: lng - halfWide),
    LatLng(latitude: lat - halfDepth, longitude: lng - halfWide),
  ];
}

void main() {
  // The golfer 100 m due south of the green's centre, playing north.
  const centreLat = 21.0360;
  const centreLng = 105.8900;
  const golfer = LatLng(latitude: 21.03510, longitude: 105.8900);

  test('front is nearer than centre, and centre nearer than back', () {
    final ref = GreenReference.of(greenRing: green(centreLat, centreLng), from: golfer)!;

    expect(ref.frontMeters, lessThan(ref.centreMeters));
    expect(ref.centreMeters, lessThan(ref.backMeters));
  });

  test('the depth is the green front-to-back, ~30 m here', () {
    final ref = GreenReference.of(greenRing: green(centreLat, centreLng), from: golfer)!;

    // ~15 m of half-depth each side of centre, along the line of play.
    expect(ref.depthMeters, closeTo(30, 6));
  });

  test('centre is about 100 m, front ~85 and back ~115', () {
    final ref = GreenReference.of(greenRing: green(centreLat, centreLng), from: golfer)!;

    expect(ref.centreMeters, closeTo(100, 6));
    expect(ref.frontMeters, closeTo(85, 8));
    expect(ref.backMeters, closeTo(115, 8));
  });

  /// The whole reason it is measured along the approach: from beside the green,
  /// what was "front" from the fairway is now the near side, and the front/back
  /// axis rotates with the golfer.
  test('front and back rotate with where the shot comes from', () {
    final fromSouth = GreenReference.of(
        greenRing: green(centreLat, centreLng), from: golfer)!;
    // A golfer level with the green but 100 m to the west, playing east.
    const fromWest = LatLng(latitude: 21.0360, longitude: 105.88904);
    final west = GreenReference.of(
        greenRing: green(centreLat, centreLng), from: fromWest)!;

    // Playing north, the front vertex is on the south edge.
    expect(fromSouth.front.latitude, lessThan(centreLat));
    // Playing east, the front vertex is on the west edge instead.
    expect(west.front.longitude, lessThan(centreLng));
  });

  test('the centroid is inside the green', () {
    final ref = GreenReference.of(greenRing: green(centreLat, centreLng), from: golfer)!;

    expect(ref.centre.latitude, closeTo(centreLat, 0.00005));
    expect(ref.centre.longitude, closeTo(centreLng, 0.00005));
  });

  test('a ring too small to be a green is refused', () {
    expect(
      GreenReference.of(
        greenRing: const [LatLng(latitude: 21.0, longitude: 105.0)],
        from: golfer,
      ),
      isNull,
    );
  });

  test('a golfer standing on the centre does not divide by zero', () {
    final ref = GreenReference.of(
      greenRing: green(centreLat, centreLng),
      from: const LatLng(latitude: centreLat, longitude: centreLng),
    );
    // Either a clean null (no approach direction) or finite numbers — never a
    // NaN reaching the panel.
    if (ref != null) {
      expect(ref.frontMeters.isFinite, isTrue);
      expect(ref.backMeters.isFinite, isTrue);
    }
  });
}
