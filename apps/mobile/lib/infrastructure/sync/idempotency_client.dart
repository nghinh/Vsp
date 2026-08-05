// IdempotencyClient — VSP Mobile App
//
// HTTP client wrapper that attaches the `Idempotency-Key` header to every
// sync request and correctly classifies server responses:
//
//   - 2xx                       → success (mark synced)
//   - X-Idempotent-Replay: true → server already processed (mark synced)
//   - 4xx                       → permanent failure (mark failed, no retry)
//   - 5xx / network ex          → retryable error (increment attempt, backoff)
//
// Story 5.4: Synchronize Round Idempotently — Slice 3

import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../domain/models/sync_event.dart';
import '../../features/correction/domain/course_correction.dart';
import 'sync_worker.dart';

/// Client that sends sync events to the server with idempotency support.
class IdempotencyClient {
  final ApiClient _apiClient;

  IdempotencyClient({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Sync a single [SyncEvent] to the server.
  ///
  /// Attaches the event's UUID as the `Idempotency-Key` header so the
  /// server can deduplicate. Checks for the `X-Idempotent-Replay` header
  /// to detect server-side replays of previously processed events.
  Future<SyncResult> syncEvent(SyncEvent event) async {
    final payload = jsonDecode(event.payload) as Map<String, dynamic>;
    final path = _eventPath(event, payload);
    final body = _eventBody(event, payload);

    try {
      final response = await _apiClient.postForReplay(
        path: path,
        body: body,
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
        // 4xx — permanent failure, do not retry.
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
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        // 4xx — permanent failure.
        return SyncResult.permanentFailure(errorMessage: ex.message);
      }
      // 5xx or network error — retryable.
      return SyncResult.retryable(errorMessage: ex.message);
    } catch (e) {
      // Unknown error — treat as retryable.
      return SyncResult.retryable(errorMessage: e.toString());
    }
  }

  /// Determine the API path for a sync event.
  ///
  /// [payload] is the decoded event payload; correction events route by the
  /// course they belong to, which only the payload knows.
  String _eventPath(SyncEvent event, Map<String, dynamic> payload) {
    switch (event.type) {
      case SyncEventType.roundCreate:
      case SyncEventType.roundComplete:
        return '/api/rounds/${event.entityId}/sync';
      case SyncEventType.scoreUpdate:
        return '/api/scores/${event.entityId}/sync';
      case SyncEventType.correctionSubmit:
        // Real endpoint, not a /sync shim: the API takes the correction itself
        // and the Idempotency-Key header already makes the replay safe.
        return '/courses/${payload['courseId']}/geometry-corrections';
      case SyncEventType.shotStarted:
      case SyncEventType.shotEnded:
      case SyncEventType.shotEdited:
      case SyncEventType.shotDeleted:
      case SyncEventType.shotsMerged:
        return '/api/shots/${event.entityId}/sync';
    }
  }

  /// Build the request body for a sync event.
  ///
  /// Most events post their stored payload verbatim. A correction is stored in
  /// the app's own shape (local IDs, sync state) and must be translated into
  /// the geometry-correction request the API accepts.
  Map<String, dynamic> _eventBody(SyncEvent event, Map<String, dynamic> payload) {
    if (event.type == SyncEventType.correctionSubmit) {
      return CourseCorrection.fromJson(payload).toGeometryCorrectionRequest();
    }
    return payload;
  }
}
