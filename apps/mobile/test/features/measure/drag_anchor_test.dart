// Dragging a measured point on a map that has been turned.
//
// The map is rotatable now, because a golfer on a tee wants the photograph
// facing the way they are. That makes the old drag maths wrong: it treated
// screen x as longitude and screen y as latitude, which holds only while the
// map points north. Turned forty degrees, a point dragged upward set off
// sideways.
//
// DragAnchor now carries all four terms, measured from the map's own answers
// along each screen axis. No bearing is read anywhere — the rotation is
// already inside the numbers — so these are the cases that proves.

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';

/// The anchor a map at [bearing] degrees would calibrate, for a camera where
/// one pixel is [degPerPixel] of longitude at the equator.
DragAnchor anchorAt(double bearing, {double degPerPixel = 0.00001}) {
  final theta = bearing * math.pi / 180;
  // Screen right, in (east, north). Screen down is the negative of screen up.
  final rightEast = math.cos(theta);
  final rightNorth = -math.sin(theta);
  final downEast = -math.sin(theta);
  final downNorth = -math.cos(theta);

  return DragAnchor(
    origin: Offset.zero,
    latitude: 10.0,
    longitude: 106.0,
    lngPerX: rightEast * degPerPixel,
    latPerX: rightNorth * degPerPixel,
    lngPerY: downEast * degPerPixel,
    latPerY: downNorth * degPerPixel,
  );
}

void main() {
  group('dragging a point', () {
    /// North-up, the case that used to be the only one that worked.
    test('moves north when the finger moves up on a north-up map', () {
      final moved = anchorAt(0).resolve(const Offset(0, -100));

      expect(moved.latitude, greaterThan(10.0));
      expect(moved.longitude, closeTo(106.0, 1e-9));
    });

    test('moves east when the finger moves right on a north-up map', () {
      final moved = anchorAt(0).resolve(const Offset(100, 0));

      expect(moved.longitude, greaterThan(106.0));
      expect(moved.latitude, closeTo(10.0, 1e-9));
    });

    /// The bug this replaced: with the map turned a quarter turn, up the
    /// screen is east, not north.
    test('moves east when the finger moves up on a map turned 90°', () {
      final moved = anchorAt(90).resolve(const Offset(0, -100));

      expect(moved.longitude, greaterThan(106.0));
      expect(moved.latitude, closeTo(10.0, 1e-9));
    });

    /// Turned all the way round, up the screen is south.
    test('moves south when the finger moves up on a map turned 180°', () {
      final moved = anchorAt(180).resolve(const Offset(0, -100));

      expect(moved.latitude, lessThan(10.0));
    });

    /// The awkward angle, where the old maths did not merely swap axes but
    /// sent the point off at a wrong angle entirely.
    test('splits the movement between both axes at 40°', () {
      final moved = anchorAt(40).resolve(const Offset(0, -100));

      expect(moved.latitude, greaterThan(10.0));
      expect(moved.longitude, greaterThan(106.0));
    });

    /// However the map is turned, the finger and the point travel the same
    /// distance — a rotation moves the ground under the finger, not further.
    test('travels the same distance whatever the bearing', () {
      double distance(double bearing) {
        final moved = anchorAt(bearing).resolve(const Offset(60, -80));
        final dLat = moved.latitude - 10.0;
        final dLng = moved.longitude - 106.0;
        return math.sqrt(dLat * dLat + dLng * dLng);
      }

      final north = distance(0);
      for (final bearing in [37.0, 90.0, 145.0, 210.0, 315.0]) {
        expect(distance(bearing), closeTo(north, 1e-12));
      }
    });

    test('a finger that has not moved leaves the point where it was', () {
      final moved = anchorAt(73).resolve(Offset.zero);

      expect(moved.latitude, closeTo(10.0, 1e-12));
      expect(moved.longitude, closeTo(106.0, 1e-12));
    });
  });
}
