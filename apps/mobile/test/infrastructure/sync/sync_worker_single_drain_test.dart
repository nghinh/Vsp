// Tests that the sync queue is drained by one run at a time.
//
// Four things wake SyncWorker — the retry timer, a connectivity change,
// syncNow(), and anything appended to the queue — and nothing stopped two of
// them overlapping. Both runs then read the same pending rows and posted the
// same event, so the server received every score twice, microseconds apart and
// under a single idempotency key. Concurrent duplicates race each other into
// the same (score_id, hole_number) row; the loser failed on the unique index,
// which in PostgreSQL aborts the whole transaction, so the golfer's sync came
// back a 500 and the score survived only because the queue retried afterwards.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/services/connectivity_service.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';
import 'package:vsp_mobile/infrastructure/persistence/sync_queue_repository.dart';
import 'package:vsp_mobile/infrastructure/sync/idempotency_client.dart';
import 'package:vsp_mobile/infrastructure/sync/sync_worker.dart';

SyncEvent pendingEvent(String id) => SyncEvent(
  id: id,
  type: SyncEventType.scoreUpdate,
  entityId: id,
  payload: '{}',
  state: SyncStatus.pending,
  attemptCount: 0,
  createdAt: DateTime.utc(2026, 8, 12),
);

/// A queue holding one event that never leaves it, so a second drain would
/// find the same row and post it again.
class FakeQueue implements SyncQueueRepository {
  int getPendingCalls = 0;

  @override
  Future<List<SyncEvent>> getPending() async {
    getPendingCalls++;
    // A real read is not instant, and the overlap this guards against opens
    // precisely across an await.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return [pendingEvent('e1')];
  }

  @override
  Future<int> pendingCount() async => 1;

  @override
  Future<void> markSyncing(String id) async {}
  @override
  Future<void> markSynced(String id) async {}
  @override
  Future<void> markFailed(String id, String error) async {}
  @override
  Future<void> markRetryable(String id, String error) async {}
  @override
  Future<void> incrementAttemptCount(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class FakeIdempotencyClient implements IdempotencyClient {
  final List<String> sent = [];

  @override
  Future<SyncResult> syncEvent(SyncEvent event) async {
    sent.add(event.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return SyncResult.success();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// Offline, so start() does not kick off a drain of its own and the test
/// controls exactly how many are in flight.
class OfflineConnectivity implements ConnectivityService {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream<List<ConnectivityResult>>.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.none];

  @override
  Future<bool> get isNetworkConnected async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  test('two callers arriving together drain the queue once, not twice', () async {
    final queue = FakeQueue();
    final client = FakeIdempotencyClient();
    final worker = SyncWorker(
      repository: queue,
      idempotencyClient: client,
      connectivity: OfflineConnectivity(),
    );
    worker.start();
    addTearDown(worker.stop);

    // The overlap the bug needed: a second wake-up while the first drain is
    // still awaiting its read.
    await Future.wait([worker.syncNow(), worker.syncNow()]);

    expect(queue.getPendingCalls, 1);
    expect(client.sent, ['e1']);
  });

  test('a caller after the drain finished starts a new one', () async {
    final queue = FakeQueue();
    final client = FakeIdempotencyClient();
    final worker = SyncWorker(
      repository: queue,
      idempotencyClient: client,
      connectivity: OfflineConnectivity(),
    );
    worker.start();
    addTearDown(worker.stop);

    await worker.syncNow();
    await worker.syncNow();

    // Coalescing must not turn into a latch that stops the queue draining
    // again later.
    expect(queue.getPendingCalls, 2);
  });
}
