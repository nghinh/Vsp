// Where the distances on this hole are measured from — VSP Mobile App
//
// A golfer standing on the hole is the obvious answer, and it is the answer
// this map used unconditionally. Which meant that opening hole 1 of Long Biên
// from a flat in Hanoi read "Tới cờ 6.1 mi" — technically the truth, and
// useless: nobody is hitting that shot, and every hazard number on the screen
// was the same six miles.
//
// A golfer who is not on the hole is looking at it, not playing it. What they
// want is what they would face from the tee. So the fix is theirs the moment
// they arrive, and the tee's until then.

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

abstract final class HoleVantage {
  /// Past this far from both ends of the hole, the golfer is not on it.
  ///
  /// Generous on purpose. A tee shot on a long par 5 leaves a golfer 400 m
  /// from the green and 250 from the tee, and somebody walking to the next
  /// tee is further still. What this has to catch is the golfer at home or
  /// in the clubhouse, who is kilometres away, not the one who has strayed.
  static const offHoleMetres = 800.0;

  /// The point to measure from: the golfer where they are on this hole, and
  /// the tee where they are not.
  ///
  /// Returns null when there is neither — a hole with no tee coordinate and
  /// no fix has no distances to show, and inventing one is worse than the
  /// blank space.
  static LatLng? measuringPoint({
    LatLng? golfer,
    LatLng? tee,
    LatLng? green,
  }) {
    if (golfer == null) return tee;
    if (isOnHole(golfer: golfer, tee: tee, green: green)) return golfer;
    return tee ?? golfer;
  }

  /// Whether the golfer is close enough to either end to be playing it.
  ///
  /// Both ends, rather than the line between them: a hole whose tee and
  /// green are both known but whose line passes near the clubhouse would
  /// otherwise decide that somebody having lunch is on the fairway.
  static bool isOnHole({
    required LatLng? golfer,
    LatLng? tee,
    LatLng? green,
  }) {
    if (golfer == null) return false;
    if (tee == null && green == null) return true;
    var nearest = double.infinity;
    if (tee != null) nearest = golfer.distanceTo(tee);
    if (green != null) {
      final toGreen = golfer.distanceTo(green);
      if (toGreen < nearest) nearest = toGreen;
    }
    return nearest <= offHoleMetres;
  }
}
