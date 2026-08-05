// Tests for RoundApi — POST /rounds and POST /rounds/{id}/complete.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/data/api/round_api.dart';

Map<String, dynamic> _roundJson({
  String id = '11111111-1111-1111-1111-111111111111',
  int courseId = 42,
  String status = 'IN_PROGRESS',
  String? endedAt,
}) => {
  'id': id,
  'courseId': courseId,
  'courseName': 'Sân Golf Long Thành',
  'status': status,
  'startedAt': '2026-08-05T02:30:00Z',
  'endedAt': endedAt,
  'createdAt': '2026-08-05T02:29:00Z',
};

RoundApi _apiReturning(
  Map<String, dynamic> body, {
  int statusCode = 200,
  void Function(http.Request)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
  return RoundApi(apiClient: ApiClient(httpClient: client));
}

void main() {
  group('RoundApi.createRound', () {
    test('posts to /rounds and parses the created round', () async {
      http.Request? captured;
      final api = _apiReturning(
        _roundJson(),
        statusCode: 201,
        onRequest: (r) => captured = r,
      );

      final round = await api.createRound(
        courseId: 42,
        idempotencyKey: 'key-1',
        startTime: DateTime.utc(2026, 8, 5, 2, 30),
        packageId: 7,
      );

      expect(round.id, '11111111-1111-1111-1111-111111111111');
      expect(round.courseId, 42);
      expect(round.status, 'IN_PROGRESS');
      expect(round.endedAt, isNull);

      expect(captured!.method, 'POST');
      expect(captured!.url.path, endsWith('/rounds'));
      expect(captured!.headers['Idempotency-Key'], 'key-1');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['courseId'], 42);
      expect(body['packageId'], 7);
      expect(body['startTime'], '2026-08-05T02:30:00.000Z');
      // playerIds is deliberately omitted — the server scores the caller.
      expect(body.containsKey('playerIds'), isFalse);
    });

    test('omits optional fields that were not provided', () async {
      http.Request? captured;
      final api = _apiReturning(
        _roundJson(),
        statusCode: 201,
        onRequest: (r) => captured = r,
      );

      await api.createRound(courseId: 42, idempotencyKey: 'key-2');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body.keys, containsAll(<String>['courseId', 'cartRequested']));
      expect(body.containsKey('packageId'), isFalse);
      expect(body.containsKey('tournamentPolicyId'), isFalse);
    });

    test('throws VspApiException on an error response', () async {
      final api = _apiReturning({
        'code': 'COURSE_001',
        'message': 'Course not found',
      }, statusCode: 404);

      expect(
        () => api.createRound(courseId: 999, idempotencyKey: 'key-3'),
        throwsA(isA<VspApiException>()),
      );
    });
  });

  group('RoundApi.completeRound', () {
    test('posts to the complete endpoint and parses endedAt', () async {
      http.Request? captured;
      final api = _apiReturning(
        _roundJson(status: 'COMPLETED', endedAt: '2026-08-05T06:30:00Z'),
        onRequest: (r) => captured = r,
      );

      final round = await api.completeRound(
        roundId: '11111111-1111-1111-1111-111111111111',
        idempotencyKey: 'key-4',
      );

      expect(round.status, 'COMPLETED');
      expect(round.endedAt, DateTime.utc(2026, 8, 5, 6, 30));
      expect(
        captured!.url.path,
        endsWith('/rounds/11111111-1111-1111-1111-111111111111/complete'),
      );
      expect(captured!.headers['Idempotency-Key'], 'key-4');
    });
  });
}
