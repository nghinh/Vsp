// How to get from here to the green with the clubs in the bag.
//
// The satellite view already lets a golfer drop points, drag them and delete
// them, and measure the chain that results. What it never did was propose one.
// So a golfer standing on a 470 m par 5 had to guess where their own second
// shot finishes before they could ask how far was left after it — which is the
// question they wanted answered in the first place.
//
// This divides the distance. Given where the golfer stands, where they are
// going, and the carry distances already in their bag, it returns the aim
// points for each shot with the club that fits each one. They land in the
// measuring tool as ordinary points, so every gesture that already works on a
// point works on these: drag the layup twenty metres left of the bunker,
// delete a shot to see the hole played in two, tap to add one back.
//
// <strong>What it does not know.</strong> Where the water is. The plan is a
// division of distance by club, drawn down the line of play, and it will
// happily put a layup in a pond. Two reasons that is the honest thing to ship
// today rather than a hazard-aware version: 67 of the 73 traced courses have
// no verified boundary, so "there is no hazard here" is a claim this database
// cannot make; and the golfer can see the pond on the photograph under the
// line and move the point. A suggestion that can be dragged is worth more than
// one that pretends to be a decision.

import 'dart:math' as math;

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

/// A club as the planner needs it: something to call it, and how far it goes.
class PlannedClub {
  const PlannedClub({required this.label, required this.carryMeters});

  /// "Driver", "5i", "PW" — whatever the golfer named it in their bag.
  final String label;

  /// Carry in metres, the bag's canonical unit. Measured where the golfer has
  /// been to the range and standard otherwise; the planner does not care
  /// which, but the panel that shows the plan should say.
  final double carryMeters;
}

/// One shot of the plan.
class PlannedShot {
  const PlannedShot({
    required this.club,
    required this.carryMeters,
    required this.remainingMeters,
    required this.aimPoint,
    required this.isApproach,
  });

  /// The club whose carry is nearest this leg. Null where the bag has none
  /// close enough to name honestly — a 30 m pitch for a golfer whose shortest
  /// club is a 95 m wedge is a shot they play, not a club they own.
  final PlannedClub? club;

  /// How far this shot is planned to travel.
  final double carryMeters;

  /// What is left after it. Zero on the last.
  final double remainingMeters;

  /// Where it is planned to finish.
  final LatLng aimPoint;

  /// True for the shot that reaches the target.
  final bool isApproach;
}

abstract final class ClubPlanner {
  /// Below this there is no plan to make — the golfer is on the green.
  static const double minimumPlannableMeters = 25.0;

  /// How far a club may be from a leg and still be named for it.
  ///
  /// A golfer with a 95 m wedge asked to hit 40 m is not hitting a wedge full,
  /// and printing "PW" beside 40 m would be advice rather than arithmetic. The
  /// leg keeps its distance and loses its club name.
  static const double clubMatchToleranceMeters = 18.0;

  /// The shots that cover [from] → [to] with [clubs].
  ///
  /// Empty when there is nothing to plan: no clubs with a carry, or a distance
  /// short enough that the answer is "one shot, you can see it".
  ///
  /// The legs sum to the distance exactly, so the last aim point *is* the
  /// target. The clubs are the nearest fit to each leg and do not have to sum
  /// to anything — a plan whose geometry was bent to match a bag's round
  /// numbers would put the flag somewhere it is not.
  static List<PlannedShot> plan({
    required LatLng from,
    required LatLng to,
    required List<PlannedClub> clubs,
  }) {
    final usable = [
      for (final club in clubs)
        if (club.carryMeters > 0) club,
    ]..sort((a, b) => a.carryMeters.compareTo(b.carryMeters));
    if (usable.isEmpty) return const [];

    final total = from.distanceTo(to);
    if (total < minimumPlannableMeters) return const [];

    final longest = usable.last.carryMeters;
    final legs = _legs(total, longest, usable);

    final shots = <PlannedShot>[];
    var travelled = 0.0;
    for (var i = 0; i < legs.length; i++) {
      travelled += legs[i];
      shots.add(PlannedShot(
        club: _clubFor(legs[i], usable),
        carryMeters: legs[i],
        // Guarded against the floating-point dust that makes a last shot
        // report "0.0000001 m to the flag".
        remainingMeters: math.max(0, total - travelled),
        aimPoint: _along(from, to, travelled / total),
        isApproach: i == legs.length - 1,
      ));
    }
    return shots;
  }

  /// How to divide [total] into legs no longer than [longest].
  ///
  /// Fewest shots first — nobody lays up out of choice — and then the division
  /// is made from the green backwards, because the shot that matters is the
  /// one into the green. Splitting forwards ("driver, driver, whatever is
  /// left") is what produces the 470 m par 5 played as 240, 240 and a 10 m
  /// chip: arithmetically fine, and not golf.
  static List<double> _legs(
      double total, double longest, List<PlannedClub> ascending) {
    final shots = (total / longest).ceil();
    if (shots <= 1) return [total];

    // The shortest the approach may be without forcing an earlier leg past
    // the longest club in the bag.
    final floor = total - (shots - 1) * longest;

    // Of the clubs that clear that floor, the one nearest a comfortable
    // approach — which is simply the floor itself, rounded up to a real club.
    // A golfer would rather hit a full club into the green than a half one.
    var approach = floor;
    for (final club in ascending) {
      if (club.carryMeters >= floor) {
        approach = club.carryMeters;
        break;
      }
    }
    // And never more than is left to play.
    approach = math.min(approach, total);

    final earlier = (total - approach) / (shots - 1);
    return [for (var i = 0; i < shots - 1; i++) earlier, total - earlier * (shots - 1)];
  }

  /// The club nearest [metres], or null where nothing in the bag is close.
  static PlannedClub? _clubFor(double metres, List<PlannedClub> clubs) {
    PlannedClub? best;
    var bestGap = double.infinity;
    for (final club in clubs) {
      final gap = (club.carryMeters - metres).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = club;
      }
    }
    return bestGap <= clubMatchToleranceMeters ? best : null;
  }

  /// A fraction of the way from [from] to [to].
  ///
  /// Interpolated in degrees rather than along a great circle. Over the length
  /// of a golf hole the two differ by well under a centimetre, and the whole
  /// point of this line is that the golfer moves the points on it anyway.
  static LatLng _along(LatLng from, LatLng to, double fraction) => LatLng(
        latitude: from.latitude + (to.latitude - from.latitude) * fraction,
        longitude: from.longitude + (to.longitude - from.longitude) * fraction,
      );
}
