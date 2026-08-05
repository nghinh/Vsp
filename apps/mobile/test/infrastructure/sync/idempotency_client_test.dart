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

    test('other sync events still post their payload verbatim', () async {
      final event = SyncEvent(
        id: 'event-9',
        type: SyncEventType.scoreUpdate,
        entityId: 'score-9',
        payload: jsonEncode({'strokes': 4}),
        state: SyncStatus.pending,
        attemptCount: 0,
        createdAt: DateTime.utc(2026, 8, 5),
      );

      await buildClient().syncEvent(event);

      expect(captured.url.path, '/api/scores/score-9/sync');
      expect(jsonDecode(captured.body), {'strokes': 4});
    });
  });
}
