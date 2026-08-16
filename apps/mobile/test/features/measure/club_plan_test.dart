// Dividing a hole among the clubs in the bag.
//
// The arithmetic is easy and the golf is not. What these tests hold down is
// the difference: a division that is correct and unplayable — 240, 240 and a
// 10 m chip — is the failure this is written to avoid.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/club_plan.dart';

void main() {
  /// A tee and a green due north of it, [metres] apart.
  (LatLng, LatLng) hole(double metres) {
    const tee = LatLng(latitude: 21.0300, longitude: 105.8900);
    return (
      tee,
      LatLng(
        latitude: 21.0300 + metres / 111_320.0,
        longitude: 105.8900,
      ),
    );
  }

  /// A plausible bag, in metres of carry.
  const bag = [
    PlannedClub(label: 'Driver', carryMeters: 230),
    PlannedClub(label: '3W', carryMeters: 205),
    PlannedClub(label: '5i', carryMeters: 160),
    PlannedClub(label: '7i', carryMeters: 140),
    PlannedClub(label: '9i', carryMeters: 115),
    PlannedClub(label: 'PW', carryMeters: 95),
  ];

  List<PlannedShot> planFor(double metres, {List<PlannedClub> clubs = bag}) {
    final (tee, green) = hole(metres);
    return ClubPlanner.plan(from: tee, to: green, clubs: clubs);
  }

  group('the plan reaches the target', () {
    test('the legs add up to the hole', () {
      final shots = planFor(470);
      final total = shots.fold<double>(0, (sum, s) => sum + s.carryMeters);

      expect(total, closeTo(470, 1));
    });

    test('the last aim point is the target and nothing is left', () {
      final (tee, green) = hole(470);
      final shots = ClubPlanner.plan(from: tee, to: green, clubs: bag);

      expect(shots.last.aimPoint.latitude, closeTo(green.latitude, 0.000001));
      expect(shots.last.remainingMeters, closeTo(0, 0.5));
      expect(shots.last.isApproach, isTrue);
    });

    test('each shot says what is left after it', () {
      // Against the hole's measured length rather than the 470 asked for:
      // the fixture places the green by dividing metres by 111 320, and the
      // planner measures it geodesically, so the two differ by half a metre.
      final (tee, green) = hole(470);
      final total = tee.distanceTo(green);
      final shots = ClubPlanner.plan(from: tee, to: green, clubs: bag);

      var travelled = 0.0;
      for (final shot in shots) {
        travelled += shot.carryMeters;
        expect(shot.remainingMeters, closeTo(total - travelled, 0.5));
      }
    });
  });

  group('how many shots', () {
    test('one, where one club covers it', () {
      expect(planFor(150), hasLength(1));
      expect(planFor(150).single.club?.label, '7i');
    });

    test('two on a long par 4, not three', () {
      // 300 m is inside two drivers. Nobody lays up out of choice.
      expect(planFor(300), hasLength(2));
    });

    test('three on a par 5 beyond two of the longest club', () {
      expect(planFor(470), hasLength(3));
    });
  });

  group('the shot into the green', () {
    // The reason this plans backwards from the flag.
    test('is a full club, not what happened to be left', () {
      // Forwards — driver, driver, remainder — leaves 470 − 460 = 10 m.
      final shots = planFor(470);

      expect(shots.last.carryMeters, greaterThan(90));
      expect(shots.last.club, isNotNull);
    });

    test('and the shots before it stay inside the longest club', () {
      final shots = planFor(470);

      for (final shot in shots.take(shots.length - 1)) {
        expect(shot.carryMeters, lessThanOrEqualTo(230.5));
      }
    });

    test('a hole that needs three of the longest club still fits', () {
      // 680 m: no room to choose a comfortable approach, and the plan must
      // not answer with a leg the golfer cannot hit.
      final shots = planFor(680);

      expect(shots, hasLength(3));
      for (final shot in shots) {
        expect(shot.carryMeters, lessThanOrEqualTo(230.5));
      }
    });
  });

  group('naming the club', () {
    test('each leg carries the club nearest it', () {
      final shots = planFor(470);

      // Two long shots and a wedge, whatever the exact split.
      expect(shots.first.club?.label, anyOf('Driver', '3W'));
      expect(shots.last.club?.label, anyOf('PW', '9i'));
    });

    test('a leg no club fits is left unnamed', () {
      // One wedge at 95 m and a 300 m hole: the second shot is about 105 m,
      // which the wedge covers, but the first is 195 m of nothing this bag
      // can hit. The plan still divides the hole; it does not invent a club.
      final shots = planFor(300, clubs: const [
        PlannedClub(label: 'PW', carryMeters: 95),
      ]);

      expect(shots.any((s) => s.club == null), isTrue);
    });
  });

  group('when there is nothing to plan', () {
    test('an empty bag plans nothing', () {
      expect(planFor(400, clubs: const []), isEmpty);
    });

    test('a club with no carry on file is not a club', () {
      expect(
        planFor(400, clubs: const [PlannedClub(label: '7i', carryMeters: 0)]),
        isEmpty,
      );
    });

    test('standing on the green plans nothing', () {
      // Under 25 m the answer is a putter and a look, not a drawn line.
      expect(planFor(12), isEmpty);
    });
  });
}
