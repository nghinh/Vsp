// IdempotencyClient routing tests — VSP Mobile App
//
// A queued geometry correction has to reach the real API endpoint in the shape
// the API accepts. These tests pin both: the path it is posted to and the body
// translation from the app's local correction shape.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';
import 'package:vsp_mobile/features/correction/domain/geometry_layer.dart';
import 'package:vsp_mobile/infrastructure/sync/idempotency_client.dart';

void main() {
  group('IdempotencyClient — geometry corrections', () {
    late http.Request captured;

    IdempotencyClient buildClient() {
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', 201);
      });
      return IdempotencyClient(apiClient: ApiClient(httpClient: mock));
    }

    CourseCorrection correction({GeometryLayer? layer}) => CourseCorrection(
      id: 'correction-1',
      courseId: '42',
      holeId: '4201',
      issueType: CorrectionIssueType.greenBoundary,
      layer: layer,
      reporterLat: 10.8506,
      reporterLng: 106.7205,
      gpsAccuracy: 4.5,
      submittedAt: DateTime.utc(2026, 8, 5, 3),
      note: 'The green edge is ~10 m short of the real one',
      syncState: CorrectionSyncState.pending,
      idempotencyKey: 'idem-1',
    );

    test('posts to the course-scoped geometry-corrections endpoint', () async {
      final event = SyncEvent.forCorrection(
        correctionId: 'correction-1',
        correctionPayload: correction(layer: GeometryLayer.green).toJson(),
      );

      final result = await buildClient().syncEvent(event);

      expect(result.isSuccess, isTrue);
      expect(captured.url.path, '/courses/42/geometry-corrections');
      expect(captured.headers['Idempotency-Key'], event.id);
    });

    test('translates the local correction into the API request body', () async {
      final event = SyncEvent.forCorrection(
        correctionId: 'correction-1',
        correctionPayload: correction(layer: GeometryLayer.bunker).toJson(),
      );

      await buildClient().syncEvent(event);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['holeId'], 4201);
      expect(body['layer'], 'bunker');
      expect(body['gpsAccuracyMeters'], 4.5);
      expect(body['reporterLat'], 10.8506);
      expect(body['reporterLng'], 106.7205);
      expect(body['note'], contains('green edge'));
      // The map has no drawing tool, so the reported shape is the point the
      // golfer is standing on — GeoJSON order is [lng, lat].
      expect(body['geometry'], {
        'type': 'Point',
        'coordinates': [106.7205, 10.8506],
      });
      // Local bookkeeping must not leak into the request.
      expect(body.containsKey('syncState'), isFalse);
      expect(body.containsKey('idempotencyKey'), isFalse);
      expect(body.containsKey('id'), isFalse);
    });

    test('a score update goes to the batch endpoint that exists', () async {
      // This test used to assert '/api/scores/score-9/sync'. That path matched
      // no handler on the API — there is no /api prefix and no per-score /sync
      // endpoint — and it passed only because MockClient answers 201 to any
      // URL. Asserting the path against a mock that has no route table is how
      // a queue that had never synced a score stayed green.
      final event = SyncEvent(
        id: 'event-9',
        type: SyncEventType.scoreUpdate,
        entityId: 'score-9',
        payload: jsonEncode({
          'roundId': 'round-3',
          'flightId': 'flight-1',
          'holeIndex': 4,
          'grossScore': 5,
        }),
        state: SyncStatus.pending,
        attemptCount: 0,
        createdAt: DateTime.utc(2026, 8, 5),
      );

      await buildClient().syncEvent(event);

      expect(captured.method, 'POST');
      expect(captured.url.path, '/scores/sync');

      // ScoreSyncRequest is a batch keyed on the round, so a single score is
      // wrapped rather than posted bare.
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['roundId'], 'round-3');
      expect(body['flightId'], 'flight-1');
      expect(body['clientEventId'], 'event-9');
      expect(body['scores'], hasLength(1));
      expect((body['scores'] as List).first, containsPair('grossScore', 5));
    });
  });

  group('IdempotencyClient — routing to endpoints the API actually has', () {
    late http.Request captured;

    IdempotencyClient buildClient({int status = 200}) {
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', status);
      });
      return IdempotencyClient(apiClient: ApiClient(httpClient: mock));
    }

    SyncEvent event(
      SyncEventType type,
      String entityId,
      Map<String, dynamic> payload,
    ) => SyncEvent(
      id: 'idem-$entityId',
      type: type,
      entityId: entityId,
      payload: jsonEncode(payload),
      state: SyncStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.utc(2026, 8, 5),
    );

    test('round creation posts to /rounds', () async {
      await buildClient().syncEvent(
        event(SyncEventType.roundCreate, 'round-1', {'courseId': 7}),
      );
      expect(captured.method, 'POST');
      expect(captured.url.path, '/rounds');
      expect(jsonDecode(captured.body), {'courseId': 7});
    });

    test('round completion posts to /rounds/{id}/complete', () async {
      await buildClient().syncEvent(
        event(SyncEventType.roundComplete, 'round-1', {'endedAt': 'now'}),
      );
      expect(captured.method, 'POST');
      expect(captured.url.path, '/rounds/round-1/complete');
    });

    test('a started shot posts to /rounds/{roundId}/shots', () async {
      await buildClient().syncEvent(
        event(SyncEventType.shotStarted, 'shot-1', {
          'shotId': 'shot-1',
          'roundId': 'round-1',
          'flightId': 'flight-1',
          'holeNumber': 3,
          'shotNumber': 1,
          'playerId': 'player-1',
          'clubId': 'club-1',
          'startedAt': '2026-08-05T03:00:00Z',
          'startLocation': {
            'type': 'Point',
            'coordinates': [106.7, 10.8],
          },
          'source': 'auto',
          'confidence': 0.9,
        }),
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/rounds/round-1/shots');

      // CreateShotRequest has no shotId, roundId, flightId, source or
      // confidence. Whether Jackson ignores unknown fields is a setting; the
      // queue should not be depending on one.
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.keys, containsAll(<String>['holeNumber', 'startLocation']));
      expect(body.containsKey('shotId'), isFalse);
      expect(body.containsKey('roundId'), isFalse);
      expect(body.containsKey('flightId'), isFalse);
      expect(body.containsKey('source'), isFalse);
    });

    test('a finished shot PATCHes /shots/{shotId}', () async {
      await buildClient().syncEvent(
        event(SyncEventType.shotEnded, 'shot-1', {
          'shotId': 'shot-1',
          'roundId': 'round-1',
          'endedAt': '2026-08-05T03:01:00Z',
          'lie': 'FAIRWAY',
          'distanceMeters': 214.5,
          'result': null,
        }),
      );

      expect(captured.method, 'PATCH');
      expect(captured.url.path, '/shots/shot-1');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['lie'], 'FAIRWAY');
      expect(body['distanceMeters'], 214.5);
      // Partial update: a null must not be sent, or it erases what the server
      // already knows about this shot.
      expect(body.containsKey('result'), isFalse);
    });

    test('a deleted shot DELETEs /shots/{shotId} with no body', () async {
      await buildClient().syncEvent(
        event(SyncEventType.shotDeleted, 'shot-1', {'shotId': 'shot-1'}),
      );
      expect(captured.method, 'DELETE');
      expect(captured.url.path, '/shots/shot-1');
      expect(captured.body, isEmpty);
    });

    test('merged shots post to /rounds/{roundId}/shots/merge', () async {
      await buildClient().syncEvent(
        event(SyncEventType.shotsMerged, 'shot-1', {
          'roundId': 'round-1',
          'sourceShotId': 'shot-1',
          'targetShotId': 'shot-2',
        }),
      );
      expect(captured.method, 'POST');
      expect(captured.url.path, '/rounds/round-1/shots/merge');
      expect(jsonDecode(captured.body), {
        'sourceShotId': 'shot-1',
        'targetShotId': 'shot-2',
      });
    });

    test('no queued event addresses the /api prefix any more', () async {
      final events = <SyncEvent>[
        event(SyncEventType.roundCreate, 'round-1', {'courseId': 7}),
        event(SyncEventType.roundComplete, 'round-1', const {}),
        event(SyncEventType.scoreUpdate, 'score-1', {'roundId': 'round-1'}),
        event(SyncEventType.shotStarted, 'shot-1', {'roundId': 'round-1'}),
        event(SyncEventType.shotEnded, 'shot-1', {'roundId': 'round-1'}),
        event(SyncEventType.shotEdited, 'shot-1', {'roundId': 'round-1'}),
        event(SyncEventType.shotDeleted, 'shot-1', const {}),
        event(SyncEventType.shotsMerged, 'shot-1', {'roundId': 'round-1'}),
      ];

      final client = buildClient();
      for (final e in events) {
        await client.syncEvent(e);
        expect(
          captured.url.path.startsWith('/api/'),
          isFalse,
          reason: '${e.type} still targets an /api path',
        );
      }
    });
  });

  group('IdempotencyClient — retry classification', () {
    IdempotencyClient clientReturning(int status) {
      final mock = MockClient((request) async => http.Response('{}', status));
      return IdempotencyClient(apiClient: ApiClient(httpClient: mock));
    }

    SyncEvent anyEvent() => SyncEvent(
      id: 'event-1',
      type: SyncEventType.roundCreate,
      entityId: 'round-1',
      payload: jsonEncode({'courseId': 7}),
      state: SyncStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.utc(2026, 8, 5),
    );

    // A 404 is the failure this queue actually suffered: it meant the path was
    // wrong, not that the golfer's round was invalid, and classifying it
    // permanent deleted the round on the first attempt without a retry.
    for (final status in [401, 403, 404, 405, 408, 425, 429, 501]) {
      test('$status is retryable, not permanent', () async {
        final result = await clientReturning(status).syncEvent(anyEvent());
        expect(result.isSuccess, isFalse);
        expect(
          result.isPermanentFailure,
          isFalse,
          reason: '$status says the request was wrong, not the data',
        );
      });
    }

    // These are about the payload and will fail identically forever.
    for (final status in [400, 409, 422]) {
      test('$status stays permanent', () async {
        final result = await clientReturning(status).syncEvent(anyEvent());
        expect(result.isPermanentFailure, isTrue);
      });
    }

    test('5xx is retryable', () async {
      final result = await clientReturning(503).syncEvent(anyEvent());
      expect(result.isPermanentFailure, isFalse);
      expect(result.isSuccess, isFalse);
    });

    test('2xx is success', () async {
      final result = await clientReturning(201).syncEvent(anyEvent());
      expect(result.isSuccess, isTrue);
    });
  });
}
