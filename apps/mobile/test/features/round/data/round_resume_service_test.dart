// Tests for RoundResumeService — rebuilding scorecard inputs for a round
// that was started but never finished.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/data/api/course_detail_api.dart';
import 'package:vsp_mobile/data/repositories/player_repository.dart';
import 'package:vsp_mobile/data/repositories/round_repository.dart';
import 'package:vsp_mobile/domain/models/player.dart';
import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/domain/models/score.dart';
import 'package:vsp_mobile/domain/repositories/score_repository.dart';
import 'package:vsp_mobile/features/round/data/round_resume_service.dart';

/// Player store that answers from memory (or fails, like a wiped install).
class _FakePlayerRepository extends PlayerRepository {
  _FakePlayerRepository({this.players = const [], this.throws = false});

  final List<Player> players;
  final bool throws;

  @override
  Future<List<Player>> getPlayersForRound(String roundId) async {
    if (throws) throw StateError('no local player store');
    return players;
  }
}

/// Local round store — the only place the round's package id survives.
class _FakeRoundRepository extends RoundRepository {
  _FakeRoundRepository({this.round, this.throws = false});

  final Round? round;
  final bool throws;

  @override
  Future<Round?> getRound(String id) async {
    if (throws) throw StateError('no local round store');
    return round;
  }
}

/// Score store holding whatever the golfer has entered so far.
class _FakeScoreRepository implements ScoreRepository {
  _FakeScoreRepository({this.scoredHoles = const [], this.throws = false});

  /// Hole ids with a gross score entered.
  final List<String> scoredHoles;
  final bool throws;

  @override
  Future<List<Score>> getScoresForFlight(String flightId) async {
    if (throws) throw StateError('no local score store');
    return [
      for (final hole in scoredHoles)
        Score(
          id: '$flightId-$hole',
          flightId: flightId,
          holeId: hole,
          playerId: 'p1',
          grossScore: 4,
          updatedAt: DateTime(2026, 8, 5, 8),
        ),
      // A row with no gross score is a hole that was opened, not played.
      Score(
        id: '$flightId-blank',
        flightId: flightId,
        holeId: '18',
        playerId: 'p1',
        updatedAt: DateTime(2026, 8, 5, 8),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

CourseDetailApi _courseApi({
  required int statusCode,
  List<int>? pars,
  List<int?>? lengths,
}) {
  final client = MockClient((http.Request request) async {
    return http.Response(
      jsonEncode({
        'courseId': 42,
        'facilityId': 1,
        'facilityName': 'Long Thành',
        'latitude': 10.9,
        'longitude': 106.9,
        'holesCount': pars?.length ?? 0,
        'holes': [
          for (var i = 0; i < (pars?.length ?? 0); i++)
            {
              'holeNumber': i + 1,
              'par': pars![i],
              if (lengths != null && lengths[i] != null)
                'playingLengthMeters': lengths[i],
            },
        ],
      }),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
  return CourseDetailApi(apiClient: ApiClient(httpClient: client));
}

Round _round({String packageVersion = ''}) {
  final now = DateTime(2026, 8, 5, 7);
  return Round(
    id: 'round-1',
    courseId: 42,
    courseName: 'Sân Golf Long Thành',
    status: RoundStatus.inProgress,
    startedAt: now,
    packageVersion: packageVersion,
    createdAt: now,
    updatedAt: now,
  );
}

RoundResumeService _service({
  _FakePlayerRepository? players,
  CourseDetailApi? courses,
  _FakeRoundRepository? rounds,
  _FakeScoreRepository? scores,
}) {
  return RoundResumeService(
    players: players ?? _FakePlayerRepository(),
    courses: courses ?? _courseApi(statusCode: 200, pars: [4, 3, 5]),
    rounds: rounds ?? _FakeRoundRepository(),
    scores: scores ?? _FakeScoreRepository(),
  );
}

void main() {
  group('RoundResumeService', () {
    test('uses the stored flight and the course\'s real pars', () async {
      final service = _service(
        players: _FakePlayerRepository(
          players: const [
            Player(id: 'p1', name: 'Nghi', isPrimary: true),
            Player(id: 'p2', name: 'Khách'),
          ],
        ),
        courses: _courseApi(statusCode: 200, pars: [4, 3, 5]),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.playerIds, ['p1', 'p2']);
      expect(plan.playerNames, {'p1': 'Nghi', 'p2': 'Khách'});
      expect(plan.holeIds, ['1', '2', '3']);
      expect(plan.holePars, {'1': 4, '2': 3, '3': 5});
      expect(plan.parsAreDefaults, isFalse);
      expect(plan.playersAreDefaults, isFalse);
    });

    test('falls back to the signed-in golfer when no players are stored',
        () async {
      final service = _service(
        players: _FakePlayerRepository(throws: true),
        courses: _courseApi(statusCode: 200, pars: [4, 4]),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.playerIds, [RoundResumeService.selfPlayerId]);
      expect(plan.playerNames, {RoundResumeService.selfPlayerId: 'Tôi'});
      expect(plan.playersAreDefaults, isTrue);
    });

    test('falls back to 18 holes of par 4 when the course cannot be loaded',
        () async {
      final service = _service(
        players: _FakePlayerRepository(
          players: const [Player(id: 'p1', name: 'Nghi', isPrimary: true)],
        ),
        courses: _courseApi(statusCode: 503),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.holeIds, hasLength(18));
      expect(plan.holeIds.first, '1');
      expect(plan.holeIds.last, '18');
      expect(plan.holePars.values.toSet(), {RoundResumeService.defaultPar});
      expect(plan.parsAreDefaults, isTrue);
      // The flight is still the real one — only the pars are guessed.
      expect(plan.playersAreDefaults, isFalse);
    });
  });

  // Everything below is what the round needs beyond the scorecard: the hole
  // the golfer is on, that hole's par and length, and the package the map,
  // the satellite basemap and the measuring tool all read from.
  group('the hole the round reopens on', () {
    test('is the first one with no score entered', () async {
      final service = _service(
        courses: _courseApi(statusCode: 200, pars: [4, 3, 5, 4]),
        // Holes 1 and 2 played; hole 3 is where the golfer is standing.
        scores: _FakeScoreRepository(scoredHoles: const ['1', '2']),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.currentHole, 3);
      expect(plan.currentPar, 5);
    });

    test('is the first hole of the round when nothing has been scored',
        () async {
      final service = _service(
        courses: _courseApi(statusCode: 200, pars: [4, 3, 5]),
        scores: _FakeScoreRepository(),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.currentHole, 1);
    });

    test('is the last hole once every hole has a score', () async {
      final service = _service(
        courses: _courseApi(statusCode: 200, pars: [4, 3, 5]),
        scores: _FakeScoreRepository(scoredHoles: const ['1', '2', '3']),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      // The round is waiting to be finished, not to be played on — it does
      // not wrap around to the 1st tee.
      expect(plan.currentHole, 3);
    });

    test('is the first hole when the score store cannot be read', () async {
      final service = _service(
        courses: _courseApi(statusCode: 200, pars: [4, 3, 5]),
        scores: _FakeScoreRepository(throws: true),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.currentHole, 1);
    });
  });

  group('what the round knows about the hole it reopens on', () {
    test('carries its real par and length', () async {
      final service = _service(
        courses: _courseApi(
          statusCode: 200,
          pars: [4, 3, 5],
          lengths: const [362, 168, null],
        ),
        scores: _FakeScoreRepository(scoredHoles: const ['1']),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.currentHole, 2);
      expect(plan.currentPar, 3);
      expect(plan.currentYardage, 168);
    });

    test('omits a length the course does not record', () async {
      final service = _service(
        courses: _courseApi(
          statusCode: 200,
          pars: [4, 3, 5],
          lengths: const [362, 168, null],
        ),
        scores: _FakeScoreRepository(scoredHoles: const ['1', '2']),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.currentHole, 3);
      expect(plan.currentPar, 5);
      expect(plan.currentYardage, isNull);
    });

    test('omits the par entirely when the course cannot be loaded', () async {
      final service = _service(courses: _courseApi(statusCode: 503));

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      // The scorecard still gets par 4 for every hole so scoring works; the
      // round header is given nothing rather than a guess it would display.
      expect(plan.holePars['1'], RoundResumeService.defaultPar);
      expect(plan.currentPar, isNull);
      expect(plan.currentYardage, isNull);
    });
  });

  group('the package the round was started against', () {
    test('is recovered from the local round row', () async {
      // The history API never returns it; round start wrote it here.
      final service = _service(
        rounds: _FakeRoundRepository(round: _round(packageVersion: 'pkg-77')),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.packageId, 'pkg-77');
    });

    test('is null when the round was started without one', () async {
      final service = _service(
        rounds: _FakeRoundRepository(
          round: _round(packageVersion: RoundResumeService.unknownPackage),
        ),
      );

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      // Null, not the literal 'unknown' — the map tab treats a missing
      // package as an unsurveyed hole and opens satellite instead.
      expect(plan.packageId, isNull);
    });

    test('is null when there is no local round row at all', () async {
      final service = _service(rounds: _FakeRoundRepository(round: null));

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.packageId, isNull);
    });

    test('is null when the local round store cannot be read', () async {
      final service = _service(rounds: _FakeRoundRepository(throws: true));

      final plan = await service.planFor(_round(), selfPlayerName: 'Tôi');

      expect(plan.packageId, isNull);
    });
  });
}
