// Tests for RoundResumeService — rebuilding scorecard inputs for a round
// that was started but never finished.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/data/api/course_detail_api.dart';
import 'package:vsp_mobile/data/repositories/player_repository.dart';
import 'package:vsp_mobile/domain/models/player.dart';
import 'package:vsp_mobile/domain/models/round.dart';
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

CourseDetailApi _courseApi({required int statusCode, List<int>? pars}) {
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
            {'holeNumber': i + 1, 'par': pars![i]},
        ],
      }),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
  return CourseDetailApi(apiClient: ApiClient(httpClient: client));
}

Round _round() {
  final now = DateTime(2026, 8, 5, 7);
  return Round(
    id: 'round-1',
    courseId: 42,
    courseName: 'Sân Golf Long Thành',
    status: RoundStatus.inProgress,
    startedAt: now,
    packageVersion: '',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('RoundResumeService', () {
    test('uses the stored flight and the course\'s real pars', () async {
      final service = RoundResumeService(
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
      final service = RoundResumeService(
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
      final service = RoundResumeService(
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
}
