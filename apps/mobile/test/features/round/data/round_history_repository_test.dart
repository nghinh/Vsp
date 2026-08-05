// Tests for RoundHistoryRepository — GET /rounds hydration.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/features/round/data/round_history_repository.dart';

Map<String, dynamic> _pageEnvelope(List<Map<String, dynamic>> content) => {
  'content': content,
  'page': 0,
  'size': 20,
  'totalElements': content.length,
  'totalPages': 1,
  'first': true,
  'last': true,
};

Map<String, dynamic> _roundJson({
  String id = '11111111-1111-1111-1111-111111111111',
  int courseId = 42,
  String courseName = 'Sân Golf Long Thành',
  String status = 'COMPLETED',
  String startedAt = '2026-08-01T02:30:00Z',
  String? endedAt = '2026-08-01T06:30:00Z',
  String createdAt = '2026-08-01T02:29:00Z',
  String? tournamentPolicyId,
  String? tournamentId,
  int? tournamentPolicyVersion,
}) => {
  'id': id,
  'courseId': courseId,
  'courseName': courseName,
  'status': status,
  'startedAt': startedAt,
  'endedAt': endedAt,
  'createdAt': createdAt,
  'tournamentPolicyId': tournamentPolicyId,
  'tournamentId': tournamentId,
  'tournamentPolicyVersion': tournamentPolicyVersion,
};

RoundHistoryRepository _repoReturning(
  Map<String, dynamic> body, {
  void Function(http.Request)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return RoundHistoryRepository(apiClient: ApiClient(httpClient: client));
}

void main() {
  group('RoundHistoryRepository.fetchRounds', () {
    test('calls GET /rounds with page and size query params', () async {
      http.Request? captured;
      final repo = _repoReturning(
        _pageEnvelope([_roundJson()]),
        onRequest: (r) => captured = r,
      );

      await repo.fetchRounds(page: 2, size: 5);

      expect(captured, isNotNull);
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/rounds');
      expect(captured!.url.queryParameters['page'], '2');
      expect(captured!.url.queryParameters['size'], '5');
    });

    test('parses page envelope and hydrates rounds', () async {
      final repo = _repoReturning(
        _pageEnvelope([
          _roundJson(status: 'COMPLETED'),
          _roundJson(
            id: '22222222-2222-2222-2222-222222222222',
            status: 'IN_PROGRESS',
            endedAt: null,
          ),
        ]),
      );

      final page = await repo.fetchRounds();

      expect(page.rounds, hasLength(2));
      expect(page.last, isTrue);
      expect(page.hasNext, isFalse);
      expect(page.rounds.first.status, RoundStatus.completed);
      expect(page.rounds[1].status, RoundStatus.inProgress);
      expect(page.rounds[1].endedAt, isNull);
    });

    test('defaults packageVersion to empty (API omits it)', () async {
      final repo = _repoReturning(_pageEnvelope([_roundJson()]));

      final page = await repo.fetchRounds();

      expect(page.rounds.single.packageVersion, '');
    });

    test('maps course fields and tournament metadata', () async {
      final repo = _repoReturning(
        _pageEnvelope([
          _roundJson(
            courseId: 7,
            courseName: 'Tân Sơn Nhất',
            tournamentPolicyId: '33333333-3333-3333-3333-333333333333',
            tournamentId: '44444444-4444-4444-4444-444444444444',
            tournamentPolicyVersion: 3,
          ),
        ]),
      );

      final round = (await repo.fetchRounds()).rounds.single;

      expect(round.courseId, 7);
      expect(round.courseName, 'Tân Sơn Nhất');
      expect(round.isTournamentRound, isTrue);
      expect(round.tournamentPolicyVersion, 3);
    });

    test('throws VspApiException on server error', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'code': 'SERVER_ERROR', 'message': 'boom'}),
          500,
        ),
      );
      final repo = RoundHistoryRepository(
        apiClient: ApiClient(httpClient: client),
      );

      expect(repo.fetchRounds(), throwsA(isA<VspApiException>()));
    });
  });

  group('roundFromApiJson', () {
    test('tolerates unknown status by defaulting to inProgress', () {
      final round = roundFromApiJson(_roundJson(status: 'WHATEVER'));
      expect(round.status, RoundStatus.inProgress);
    });

    test('maps ABANDONED and CANCELLED statuses', () {
      expect(
        roundFromApiJson(_roundJson(status: 'ABANDONED')).status,
        RoundStatus.abandoned,
      );
      expect(
        roundFromApiJson(_roundJson(status: 'CANCELLED')).status,
        RoundStatus.cancelled,
      );
    });

    test('falls back to placeholder when courseName is blank', () {
      final round = roundFromApiJson(_roundJson(courseName: ''));
      expect(round.courseName, isNotEmpty);
    });
  });
}
