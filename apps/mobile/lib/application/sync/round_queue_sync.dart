// Round Queue Sync — VSP Mobile App
//
// Carries the post for the round queue, which nobody was carrying.
//
// `RoundSyncStore` has an enqueue, a dequeue, a synced marker and a retry
// counter, and four places in the app write to it: the scorecard's finish
// action, both branches of RoundCompletionBloc, and RoundStateService. Its
// `dequeueAll()` had no callers anywhere. The comment at the scorecard's catch
// block reads "queue the completion so it can be retried"; nothing retried it,
// so a round finished out of signal was finished only on the phone.
//
// That mattered more than it sounds. Round history is read from the server —
// `RoundHistoryRepository` calls GET /rounds and nothing else — so a round the
// server never heard about is not "unsynced" in the list, it is absent from
// it. A golfer who played a course with no signal came home to a history that
// did not contain the round.
//
// The other half of the same defect is the address rather than the postman:
// until the API accepted `clientRoundId`, a round started out of signal kept a
// local UUID the server had never issued, and completing it answered 404
// VSP-ERR-ROUND-001. Draining the queue without that would only have posted
// letters to an address that does not exist.

import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/storage/round_sync_store.dart';
import '../../data/api/round_api.dart';
import '../../domain/models/queued_round_update.dart';
import '../../domain/models/round_sync_operation.dart';

/// Sends what the round queue is holding, oldest first.
class RoundQueueSync {
  final RoundApi _api;
  final RoundSyncStore _store;

  RoundQueueSync({RoundApi? api, RoundSyncStore? store})
    : _api = api ?? RoundApi(),
      _store = store ?? RoundSyncStore();

  /// Sends every pending entry and returns how many were accepted.
  ///
  /// Oldest first, which is not a detail: a round's `startRound` has to reach
  /// the server before the `endRound` that closes it, or the second one is
  /// addressed to a round that does not exist yet. `dequeueAll` orders by
  /// creation time, and this relies on it.
  ///
  /// Stops at the first entry that fails for a reason that will not resolve
  /// itself — a lost network — because everything behind it is for the same
  /// round or a later one, and hammering a dead connection with the rest of
  /// the queue only spends battery.
  Future<int> drain() async {
    List<QueuedRoundUpdate> pending;
    try {
      pending = await _store.dequeueAll();
    } catch (_) {
      // No database. The queue is still on the device.
      return 0;
    }

    var sent = 0;
    for (final entry in pending) {
      try {
        final handled = await _send(entry);
        if (!handled) continue;
        await _store.markSynced(entry.idempotencyKey);
        sent++;
      } on VspApiException catch (e) {
        // The server understood and refused. Retrying sends the same bytes to
        // the same endpoint for the same answer, so the entry is counted
        // against its retry budget rather than repeated immediately — but the
        // rest of the queue is still worth trying, because it is not
        // necessarily about this round.
        await _retry(entry);
        if (e.isNetworkError) return sent;
      } catch (_) {
        // Transport. Nothing behind this will get through either.
        await _retry(entry);
        return sent;
      }
    }
    return sent;
  }

  Future<void> _retry(QueuedRoundUpdate entry) async {
    try {
      await _store.incrementRetry(entry.idempotencyKey);
    } catch (_) {
      // Counting the attempt is a nicety; failing to count it is not a reason
      // to lose the entry.
    }
  }

  /// Sends one entry. Returns false for an operation this does not carry yet,
  /// so it stays in the queue rather than being marked done.
  Future<bool> _send(QueuedRoundUpdate entry) async {
    switch (entry.operation) {
      case RoundSyncOperation.startRound:
        final payload = entry.payloadMap;
        final courseId = (payload['courseId'] as num?)?.toInt();
        if (courseId == null) return false;
        await _api.createRound(
          courseId: courseId,
          // The name the phone has been using since the golfer teed off. The
          // server takes it, so everything already queued against this round
          // — the completion above all — is addressed correctly.
          clientRoundId: entry.roundId,
          idempotencyKey: entry.idempotencyKey,
          segmentCourseIds:
              (payload['segmentCourseIds'] as List<dynamic>? ?? const [])
                  .map((e) => (e as num).toInt())
                  .toList(),
          startTime: payload['startTime'] == null
              ? null
              : DateTime.tryParse(payload['startTime'] as String),
          packageId: (payload['packageId'] as num?)?.toInt(),
          format: payload['format'] as String?,
          countsTowardHandicap: payload['countsTowardHandicap'] as bool?,
        );
        return true;

      case RoundSyncOperation.endRound:
        await _api.completeRound(
          roundId: entry.roundId,
          idempotencyKey: entry.idempotencyKey,
        );
        return true;

      // Scores and their edits travel on the other queue, drained by
      // SyncWorker. Listing them here rather than defaulting keeps the
      // compiler on the case if a new operation is added.
      case RoundSyncOperation.updateRound:
      case RoundSyncOperation.addHoleScore:
      case RoundSyncOperation.updateHoleScore:
      case RoundSyncOperation.deleteHoleScore:
        return false;
    }
  }
}

/// The payload a queued `startRound` needs to be sendable later.
///
/// Written at the moment the round is created, because that is the only moment
/// the app knows the answers — the setup screen is gone by the time the queue
/// drains.
String encodeStartRoundPayload({
  required int courseId,
  List<int> segmentCourseIds = const [],
  DateTime? startTime,
  int? packageId,
  String? format,
  bool? countsTowardHandicap,
}) {
  return jsonEncode({
    'courseId': courseId,
    if (segmentCourseIds.isNotEmpty) 'segmentCourseIds': segmentCourseIds,
    if (startTime != null) 'startTime': startTime.toUtc().toIso8601String(),
    if (packageId != null) 'packageId': packageId,
    if (format != null) 'format': format,
    if (countsTowardHandicap != null)
      'countsTowardHandicap': countsTowardHandicap,
  });
}
