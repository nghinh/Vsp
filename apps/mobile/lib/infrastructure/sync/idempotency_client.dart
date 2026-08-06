// IdempotencyClient — VSP Mobile App
//
// HTTP client wrapper that attaches the `Idempotency-Key` header to every
// sync request, routes each event to the endpoint the API actually exposes,
// and classifies the response:
//
//   - 2xx                       → success (mark synced)
//   - X-Idempotent-Replay: true → server already processed (mark synced)
//   - 4xx the data caused       → permanent failure (mark failed, no retry)
//   - 4xx the request caused    → retryable (see _isRetryableClientError)
//   - 5xx / network ex          → retryable (increment attempt, backoff)
//
// Story 5.4: Synchronize Round Idempotently — Slice 3

import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../domain/models/sync_event.dart';
import '../../features/correction/domain/course_correction.dart';
import 'sync_worker.dart';

/// One queued event addressed to a real endpoint: method, path and body.
class SyncRequest {
  final String method;
  final String path;
  final Map<String, dynamic>? body;

  const SyncRequest(this.method, this.path, [this.body]);
}

/// Client that sends sync events to the server with idempotency support.
class IdempotencyClient {
  final ApiClient _apiClient;

  IdempotencyClient({required ApiClient apiClient}) : _apiClient = apiClient;

  /// HTTP statuses that mean "this request could not be delivered as sent",
  /// not "this data is wrong".
  ///
  /// The distinction is the whole point. A 4xx caused by the *payload* will
  /// never succeed however often it is retried, so retrying is pointless. A
  /// 4xx caused by the *request* — a path this build gets wrong, an access
  /// token that expired while the phone was in a pocket, a proxy that does not
  /// forward PATCH — has nothing to do with the golfer's data, and discarding
  /// their round for it is the worst possible response.
  ///
  ///   401/403  the token expired or was not attached; it is refreshed
  ///            elsewhere, and the event should still be there afterwards
  ///   404      the path is wrong. Every round, score and shot event this
  ///            queue has ever produced hit one, and every one was dropped
  ///   405/501  the method is not allowed or not implemented at that path
  ///   408/425  timeout or "too early" — transport, not content
  ///   429      rate limited; the retry is the correct behaviour
  static const Set<int> _retryableClientErrors = {
    401,
    403,
    404,
    405,
    408,
    425,
    429,
    501,
  };

  static bool _isRetryableClientError(int statusCode) =>
      _retryableClientErrors.contains(statusCode);

  /// Sync a single [SyncEvent] to the server.
  ///
  /// Attaches the event's UUID as the `Idempotency-Key` header so the
  /// server can deduplicate. Checks for the `X-Idempotent-Replay` header
  /// to detect server-side replays of previously processed events.
  Future<SyncResult> syncEvent(SyncEvent event) async {
    final payload = jsonDecode(event.payload) as Map<String, dynamic>;
    final request = requestFor(event, payload);

    try {
      final response = await _apiClient.sendForReplay(
        method: request.method,
        path: request.path,
        body: request.body,
        idempotencyKey: event.id,
      );

      // Detect server-side replay (duplicate submitted successfully).
      final replayHeader = response.headers['x-idempotent-replay'];
      if (replayHeader?.toLowerCase() == 'true') {
        return SyncResult.success();
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SyncResult.success();
      }

      if (response.statusCode >= 400 && response.statusCode < 500) {
        if (_isRetryableClientError(response.statusCode)) {
          return SyncResult.retryable(
            errorMessage:
                'Request error ${response.statusCode} for '
                '${request.method} ${request.path}',
          );
        }
        return SyncResult.permanentFailure(
          errorMessage: 'Client error: ${response.statusCode}',
        );
      }

      // 5xx — retryable server error.
      return SyncResult.retryable(
        errorMessage: 'Server error: ${response.statusCode}',
      );
    } on VspApiException catch (ex) {
      final statusCode = ex.statusCode;
      if (statusCode != null &&
          statusCode >= 400 &&
          statusCode < 500 &&
          !_isRetryableClientError(statusCode)) {
        return SyncResult.permanentFailure(errorMessage: ex.message);
      }
      // 5xx, transport, or a 4xx about the request rather than the data.
      return SyncResult.retryable(errorMessage: ex.message);
    } catch (e) {
      // Unknown error — treat as retryable.
      return SyncResult.retryable(errorMessage: e.toString());
    }
  }

  /// Address a queued event to the endpoint that exists.
  ///
  /// Every route here was read off the controllers. What was here before was
  /// not: rounds, scores and shots were sent to `/api/rounds/{id}/sync`,
  /// `/api/scores/{id}/sync` and `/api/shots/{id}/sync`, and the API has no
  /// `/api` prefix (no `server.servlet.context-path`, no `spring.mvc.servlet
  /// .path`) and no per-entity `/sync` endpoint. Those three paths matched no
  /// handler at all, so Spring Security answered every one of them before any
  /// controller saw it. Combined with 4xx being classified permanent, that
  /// meant a golfer's queued round was deleted on its first delivery attempt,
  /// and this queue has never successfully synced anything but a correction.
  ///
  /// Visible for testing so the routing can be asserted without a server.
  SyncRequest requestFor(SyncEvent event, Map<String, dynamic> payload) {
    switch (event.type) {
      // POST /rounds — RoundController, @Idempotent.
      case SyncEventType.roundCreate:
        return SyncRequest('POST', '/rounds', payload);

      // POST /rounds/{roundId}/complete — body is optional, the path carries
      // the round and the Idempotency-Key makes the replay safe.
      case SyncEventType.roundComplete:
        return SyncRequest(
          'POST',
          '/rounds/${event.entityId}/complete',
          const {},
        );

      // POST /scores/sync — ScoreController. A batch keyed on roundId, not a
      // per-score path: `/scores/{scoreId}/sync` would 404 even with the
      // prefix removed, and a bare score object would not bind to
      // ScoreSyncRequest.
      case SyncEventType.scoreUpdate:
        return SyncRequest('POST', '/scores/sync', _scoreSyncBody(event, payload));

      // POST /courses/{courseId}/geometry-corrections — the one route that was
      // already right, and the only reason anything ever left this queue.
      case SyncEventType.correctionSubmit:
        return SyncRequest(
          'POST',
          '/courses/${payload['courseId']}/geometry-corrections',
          CourseCorrection.fromJson(payload).toGeometryCorrectionRequest(),
        );

      // POST /rounds/{roundId}/shots — CreateShotRequest.
      case SyncEventType.shotStarted:
        return SyncRequest(
          'POST',
          '/rounds/${payload['roundId']}/shots',
          _createShotBody(payload),
        );

      // PATCH /shots/{shotId} — UpdateShotRequest, a partial update. Both
      // "the ball came to rest" and "the golfer corrected the club" are the
      // same call; only the fields present differ.
      case SyncEventType.shotEnded:
      case SyncEventType.shotEdited:
        return SyncRequest(
          'PATCH',
          '/shots/${event.entityId}',
          _updateShotBody(payload),
        );

      // DELETE /shots/{shotId} — no body. Idempotent server-side: deleting an
      // already-deleted shot is a 200, not an error.
      case SyncEventType.shotDeleted:
        return SyncRequest('DELETE', '/shots/${event.entityId}');

      // POST /rounds/{roundId}/shots/merge — MergeShotsRequest.
      case SyncEventType.shotsMerged:
        return SyncRequest(
          'POST',
          '/rounds/${payload['roundId']}/shots/merge',
          {
            'sourceShotId': payload['sourceShotId'],
            'targetShotId': payload['targetShotId'],
          },
        );
    }
  }

  /// Body for `POST /scores/sync`.
  ///
  /// The endpoint takes a batch — `{roundId, flightId, scores: [...],
  /// clientEventId}` — so a payload that is already in that shape is sent as
  /// it stands, and a single score is wrapped into a batch of one. The event
  /// id doubles as `clientEventId` when the payload does not carry one: it is
  /// the same UUID as the `Idempotency-Key`, which is exactly the identity the
  /// server deduplicates on.
  Map<String, dynamic> _scoreSyncBody(
    SyncEvent event,
    Map<String, dynamic> payload,
  ) {
    if (payload['scores'] is List) {
      return {'clientEventId': event.id, ...payload};
    }
    return {
      'roundId': payload['roundId'],
      'flightId': payload['flightId'],
      'clientEventId': event.id,
      'scores': [payload],
    };
  }

  /// Body for `POST /rounds/{roundId}/shots` (CreateShotRequest).
  ///
  /// Built field by field rather than passing the stored payload through. The
  /// stored payload carries shotId, roundId, flightId, source and confidence,
  /// none of which the record accepts; whether unknown fields are ignored is a
  /// Jackson setting, and the queue should not depend on one.
  Map<String, dynamic> _createShotBody(Map<String, dynamic> payload) =>
      _withoutNulls({
        'holeNumber': payload['holeNumber'],
        'shotNumber': payload['shotNumber'],
        'playerId': payload['playerId'],
        'clubId': payload['clubId'],
        'startedAt': payload['startedAt'],
        'startLocation': payload['startLocation'],
        'conditions': payload['conditions'],
      });

  /// Body for `PATCH /shots/{shotId}` (UpdateShotRequest).
  ///
  /// Nulls are dropped, because the endpoint is a partial update: sending
  /// `"lie": null` for a shot whose lie is simply not known on this event
  /// would erase the lie the server already holds.
  Map<String, dynamic> _updateShotBody(Map<String, dynamic> payload) =>
      _withoutNulls({
        'clubId': payload['clubId'],
        'endedAt': payload['endedAt'],
        'endLocation': payload['endLocation'],
        'lie': payload['lie'],
        'distanceYards': payload['distanceYards'],
        'distanceMeters': payload['distanceMeters'],
        'conditions': payload['conditions'],
        'result': payload['result'],
        'isPenalty': payload['isPenalty'],
        'isProvisional': payload['isProvisional'],
        'isMulligan': payload['isMulligan'],
        'confidence': payload['confidence'],
      });

  Map<String, dynamic> _withoutNulls(Map<String, dynamic> source) => {
    for (final entry in source.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
