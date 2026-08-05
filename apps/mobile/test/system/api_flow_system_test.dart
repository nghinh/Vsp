// System test — end-to-end golfer journey against a running API.
//
// This drives the app's real API clients against a live backend, so it fails on
// exactly the class of bug unit tests cannot see: wrong endpoints, wrong ID
// types, response shapes the parsers reject, and flows that were never wired.
//
// It is skipped automatically when no API is reachable, so `flutter test` stays
// green offline. To run it:
//
//   1. start the API (dev profile) on http://localhost:8080
//   2. flutter test test/system/api_flow_system_test.dart
//
// Override the target and account with --dart-define:
//   VSP_API_BASE_URL, VSP_TEST_EMAIL, VSP_TEST_PASSWORD

@Tags(['system'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/data/api/course_detail_api.dart';
import 'package:vsp_mobile/data/api/course_search_api.dart';
import 'package:vsp_mobile/data/api/round_api.dart';
import 'package:vsp_mobile/domain/models/course_detail.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/features/round/data/round_history_repository.dart';

const _baseUrl = String.fromEnvironment(
  'VSP_API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);
const _email = String.fromEnvironment(
  'VSP_TEST_EMAIL',
  defaultValue: 'golfer@vsp.local',
);
const _password = String.fromEnvironment(
  'VSP_TEST_PASSWORD',
  defaultValue: 'Golfer2026',
);

Future<bool> _apiReachable() async {
  try {
    final res = await http
        .get(Uri.parse('$_baseUrl/actuator/health'))
        .timeout(const Duration(seconds: 3));
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  late bool reachable;
  late ApiClient apiClient;
  late String accessToken;

  // Journey state, threaded through the ordered steps below.
  CourseSearchResult? course;
  CourseDetail? detail;
  String? roundId;

  setUpAll(() async {
    reachable = await _apiReachable();
    if (!reachable) {
      // ignore: avoid_print
      print('SKIP: no API at $_baseUrl — start the backend to run system tests');
      return;
    }
    apiClient = ApiClient();

    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': _email, 'password': _password}),
    );
    expect(
      res.statusCode,
      200,
      reason: 'login failed for $_email — is the dev account seeded?',
    );
    accessToken = (jsonDecode(res.body) as Map<String, dynamic>)['accessToken']
        as String;
    apiClient.setAccessToken(accessToken);
  });

  group('golfer journey', () {
    test('1. authenticates and reaches an authorised endpoint', () async {
      if (!reachable) return;

      expect(accessToken, isNotEmpty);

      // /profiles/me is the first authenticated call the app makes after login.
      final res = await http.get(
        Uri.parse('$_baseUrl/profiles/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      expect(
        res.statusCode,
        anyOf(200, 404),
        reason: 'profile endpoint must authorise the token (404 = no profile '
            'row yet, which the app handles)',
      );
    });

    test('2. searches courses and parses the page envelope', () async {
      if (!reachable) return;

      final api = CourseSearchApi(apiClient: apiClient);
      final page = await api.searchCourses(
        const CourseSearchParams(page: 0, size: 5),
      );

      expect(page.content, isNotEmpty, reason: 'course catalogue is empty');
      expect(page.totalElements, greaterThan(0));
      course = page.content.first;
      expect(course!.courseId, greaterThan(0));
      expect(course!.displayName, isNotEmpty);
    });

    test('3. opens course detail with holes and tee sets', () async {
      if (!reachable || course == null) return;

      detail = await CourseDetailApi(
        apiClient: apiClient,
      ).getCourseDetail(course!.courseId);

      expect(detail!.courseId, course!.courseId);
      expect(detail!.holesCount, greaterThan(0));
      // Round setup seeds the scorecard from these — an empty list silently
      // degrades every hole to par 4.
      expect(
        detail!.holes,
        isNotEmpty,
        reason: 'course detail must expose per-hole par',
      );
      for (final hole in detail!.holes) {
        expect(hole.par, inInclusiveRange(3, 6));
      }
    });

    test('4. starts a round for that course', () async {
      if (!reachable || course == null) return;

      final round = await RoundApi(apiClient: apiClient).createRound(
        courseId: course!.courseId,
        idempotencyKey: const Uuid().v4(),
        startTime: DateTime.now().toUtc(),
      );

      expect(round.id, isNotEmpty);
      expect(round.courseId, course!.courseId);
      expect(round.status, 'IN_PROGRESS');
      roundId = round.id;
    });

    test('5. syncs a hole score for the active round', () async {
      if (!reachable || roundId == null) return;

      final res = await http.post(
        Uri.parse('$_baseUrl/scores/sync'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Idempotency-Key': const Uuid().v4(),
        },
        body: jsonEncode({
          'roundId': roundId,
          'clientEventId': const Uuid().v4(),
          'scores': [
            {
              'holeIndex': 1,
              'grossScore': 4,
              'putts': 2,
              'penalties': 0,
              'version': 0,
            },
          ],
        }),
      );

      expect(
        res.statusCode,
        200,
        reason: 'score sync rejected: ${res.body}',
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['status'], 'SYNCED');
    });

    test('6. completes the round, idempotently', () async {
      if (!reachable || roundId == null) return;

      final api = RoundApi(apiClient: apiClient);
      final completed = await api.completeRound(
        roundId: roundId!,
        idempotencyKey: const Uuid().v4(),
      );
      expect(completed.status, 'COMPLETED');
      expect(completed.endedAt, isNotNull);

      // Finishing twice must not fail — the app retries this after a flaky
      // network and offline queue flushes.
      final again = await api.completeRound(
        roundId: roundId!,
        idempotencyKey: const Uuid().v4(),
      );
      expect(again.status, 'COMPLETED');
      expect(again.endedAt, completed.endedAt);
    });

    test('7. shows the finished round in history', () async {
      if (!reachable || roundId == null) return;

      final history = await RoundHistoryRepository(
        apiClient: apiClient,
      ).fetchRounds(page: 0, size: 20);

      final match = history.rounds.where((r) => r.id == roundId).toList();
      expect(
        match,
        hasLength(1),
        reason: 'the completed round must appear in GET /rounds',
      );
      expect(match.first.status.name, 'completed');
      expect(match.first.courseName, isNotEmpty);
    });

    test('8. serves the golfer-scoped list endpoints the tabs read', () async {
      if (!reachable) return;

      // Each of these backs a visible tab; a 5xx here is a blank screen.
      for (final path in const [
        '/bags',
        '/users/me/favorites',
        '/users/me/recent',
      ]) {
        final res = await http.get(
          Uri.parse('$_baseUrl$path'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        expect(
          res.statusCode,
          lessThan(500),
          reason: '$path returned ${res.statusCode}: ${res.body}',
        );
      }
    });
  });

  tearDownAll(() {
    if (reachable) apiClient.close();
  });
}
