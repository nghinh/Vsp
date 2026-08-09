// Tests for surviving an access token that lapses mid-round.
//
// The token lives one hour. A round of golf lasts four. It was refreshed in
// exactly one place — session restore, at app launch — so from the second hour
// onward every authenticated request came back 401. The sync queue classifies
// 401 as retryable, tries five times, and then marks the event permanently
// failed: a golfer's scores, shots and corrections from hole 5 onward were
// written to the phone, rejected by the server, and abandoned, with nothing on
// screen saying so.
//
// The retry carries the original Idempotency-Key on purpose. A write the server
// accepted just before the token lapsed must replay, not duplicate.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vsp_mobile/core/network/api_client.dart';

void main() {
  tearDown(() => ApiClient.refreshAccessToken = null);

  /// A server that 401s until [refreshCount] says the token was replaced.
  ({ApiClient client, List<http.Request> requests}) clientThatRejects({
    required bool Function() tokenIsFresh,
  }) {
    final requests = <http.Request>[];
    final mock = MockClient((request) async {
      requests.add(request);
      if (!tokenIsFresh()) {
        return http.Response(
          jsonEncode({'code': 'VSP-ERR-AUTH-001', 'message': 'expired'}),
          401,
        );
      }
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    return (client: ApiClient(httpClient: mock), requests: requests);
  }

  group('an expired token on a queued write', () {
    test('is refreshed and the write repeated', () async {
      var refreshed = false;
      ApiClient.refreshAccessToken = () async {
        refreshed = true;
        return true;
      };
      final harness = clientThatRejects(tokenIsFresh: () => refreshed);

      final response = await harness.client.sendForReplay(
        method: 'POST',
        path: '/courses/8/geometry-corrections',
        idempotencyKey: 'key-1',
        body: const {'holeId': 127},
      );

      expect(response.statusCode, 200);
      expect(harness.requests, hasLength(2));
    });

    test('the retry reuses the idempotency key', () async {
      var refreshed = false;
      ApiClient.refreshAccessToken = () async {
        refreshed = true;
        return true;
      };
      final harness = clientThatRejects(tokenIsFresh: () => refreshed);

      await harness.client.sendForReplay(
        method: 'POST',
        path: '/rounds/r1/scores',
        idempotencyKey: 'key-2',
        body: const {},
      );

      // A new key would turn one score into two on a server that had already
      // accepted the first attempt.
      expect(
        harness.requests.map((r) => r.headers['Idempotency-Key']),
        everyElement('key-2'),
      );
    });

    test('a refusal to refresh leaves the 401 to stand', () async {
      ApiClient.refreshAccessToken = () async => false;
      final harness = clientThatRejects(tokenIsFresh: () => false);

      final response = await harness.client.sendForReplay(
        method: 'POST',
        path: '/rounds/r1/scores',
        idempotencyKey: 'key-3',
      );

      // One attempt, one refresh attempt, no retry. Looping here would burn
      // the golfer's battery on a session that is genuinely over.
      expect(response.statusCode, 401);
      expect(harness.requests, hasLength(1));
    });

    test('with no refresher installed nothing changes', () async {
      final harness = clientThatRejects(tokenIsFresh: () => false);

      final response = await harness.client.sendForReplay(
        method: 'POST',
        path: '/rounds/r1/scores',
        idempotencyKey: 'key-4',
      );

      expect(response.statusCode, 401);
      expect(harness.requests, hasLength(1));
    });
  });

  group('the auth endpoints themselves', () {
    test('a refused sign-in does not trigger a refresh', () async {
      var refreshCalls = 0;
      ApiClient.refreshAccessToken = () async {
        refreshCalls++;
        return true;
      };
      final harness = clientThatRejects(tokenIsFresh: () => false);

      await harness.client.sendForReplay(
        method: 'POST',
        path: '/auth/login',
        idempotencyKey: 'key-5',
      );

      // Refreshing on the refresh call is how a loop starts, and a wrong
      // password is not a stale token.
      expect(refreshCalls, 0);
    });
  });

  group('a burst of expired requests', () {
    test('produces one refresh, not one per request', () async {
      var refreshCalls = 0;
      var refreshed = false;
      ApiClient.refreshAccessToken = () async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        refreshed = true;
        return true;
      };
      final harness = clientThatRejects(tokenIsFresh: () => refreshed);

      // The queue drains several events at once the moment it wakes up.
      await Future.wait([
        for (var i = 0; i < 5; i++)
          harness.client.sendForReplay(
            method: 'POST',
            path: '/rounds/r1/scores',
            idempotencyKey: 'burst-$i',
          ),
      ]);

      expect(refreshCalls, 1);
    });
  });
}
