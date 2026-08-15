// What stands between a golfer and the first tee.
//
// Two things did, and neither should have. The start button was disabled
// until the golfer acknowledged a warning that their course data was "not
// downloaded" — on a course with no package published, which is most of
// them, so the acknowledgement was of nothing and the tap was pure ceremony.
// And the warning itself appeared for those same courses, inviting a
// download that does not exist.
//
// A round needs a course and a player. The package buys a map that works
// without signal; scoring needs a par and a hole list, which the round
// already carries.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/player.dart';
import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const me = Player(id: 'p1', name: 'nghi', isPrimary: true);

  RoundSetupReady form({
    PackageStatus? status,
    bool available = false,
    bool acknowledged = false,
    List<Player> players = const [me],
  }) => RoundSetupReady(
    courseId: 1,
    courseName: 'ANARA Bình Tiên Golf Club',
    players: players,
    warningAcknowledged: acknowledged,
    coursePackageAvailable: available,
    packageReadiness: status == null ? null : PackageReadiness(status: status),
  );

  group('starting the round', () {
    test('a course and a player is enough, package or no package', () {
      final state = form(status: PackageStatus.notDownloaded);

      expect(state.canStartRound, isTrue);
      expect(state.isStartEnabled, isTrue);
    });

    test('nothing has to be acknowledged first', () {
      final unacknowledged = form(
        status: PackageStatus.notDownloaded,
        acknowledged: false,
      );

      expect(unacknowledged.isStartEnabled, isTrue);
    });

    test('still refuses without a course or without a player', () {
      expect(
        const RoundSetupReady(players: [me]).canStartRound,
        isFalse,
      );
      expect(form(players: const []).canStartRound, isFalse);
    });

    test('and refuses a fifth player', () {
      final crowded = form(
        players: const [
          me,
          Player(id: 'p2', name: 'B'),
          Player(id: 'p3', name: 'C'),
          Player(id: 'p4', name: 'D'),
          Player(id: 'p5', name: 'E'),
        ],
      );

      expect(crowded.canStartRound, isFalse);
    });
  });

  group('the package banner', () {
    test('says nothing where no package is published', () {
      final state = form(status: PackageStatus.notDownloaded, available: false);

      expect(state.showsPackageBanner, isFalse);
    });

    test('invites the download where one exists', () {
      final state = form(status: PackageStatus.notDownloaded, available: true);

      expect(state.showsPackageBanner, isTrue);
    });

    test('still reports a package that is here but stale or broken', () {
      // These are about data the golfer already downloaded, so they are worth
      // saying whatever the server currently publishes.
      expect(form(status: PackageStatus.expired).showsPackageBanner, isTrue);
      expect(form(status: PackageStatus.invalid).showsPackageBanner, isTrue);
      expect(form(status: PackageStatus.valid).showsPackageBanner, isTrue);
    });

    test('says nothing before any course is chosen', () {
      expect(const RoundSetupReady().showsPackageBanner, isFalse);
    });
  });
}
