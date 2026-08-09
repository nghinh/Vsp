// Tests for the queue waking the worker.
//
// SyncWorker drained on start-up and on a connectivity *change*, and nothing
// else. A phone that stays online through a whole round never produces a
// change, so anything queued mid-round — a correction filed on the 3rd green,
// a score, a shot — sat in SQLite until the app was restarted. The queue looked
// healthy from the inside: durable, ordered, retried. It just never ran.
//
// Runs against a real SQLite file through sqflite_ffi, because the property
// under test is that the announcement happens on the write path — asserting on
// the stream's shape alone would pass against the broken code.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';
import 'package:vsp_mobile/infrastructure/persistence/sync_queue_repository.dart';

SyncEvent eventNamed(String id) => SyncEvent(
  id: id,
  type: SyncEventType.correctionSubmit,
  entityId: id,
  payload: '{}',
  state: SyncStatus.pending,
  attemptCount: 0,
  createdAt: DateTime.utc(2026, 8, 7),
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('appending wakes anything listening for work', () async {
    final woken = <void>[];
    final subscription = SyncQueueRepository.onAppended.listen(woken.add);
    addTearDown(subscription.cancel);

    await SyncQueueRepository().append(eventNamed('e1'));
    // The announcement is synchronous with the write, but the broadcast is
    // delivered on the microtask queue.
    await Future<void>.delayed(Duration.zero);

    // Without this the event is durable and invisible: the worker next looks
    // at the queue when connectivity changes, which on a phone that stays
    // online for four hours means never.
    expect(woken, hasLength(1));
  });

  test('each append is announced', () async {
    final woken = <void>[];
    final subscription = SyncQueueRepository.onAppended.listen(woken.add);
    addTearDown(subscription.cancel);

    final repository = SyncQueueRepository();
    await repository.append(eventNamed('e2'));
    await repository.append(eventNamed('e3'));
    await Future<void>.delayed(Duration.zero);

    expect(woken, hasLength(2));
  });

  test('a producer and the worker holding different instances still connect', () async {
    final woken = <void>[];
    final subscription = SyncQueueRepository.onAppended.listen(woken.add);
    addTearDown(subscription.cancel);

    // Repositories are constructed independently all over the app. A
    // per-instance stream would carry nothing between them, which is why the
    // notification is static.
    await SyncQueueRepository().append(eventNamed('e4'));
    await Future<void>.delayed(Duration.zero);

    expect(woken, hasLength(1));
    expect(SyncQueueRepository.onAppended.isBroadcast, isTrue);
  });

  test('the event really is in the queue when the wake-up arrives', () async {
    late Future<List<SyncEvent>> pendingAtWakeUp;
    final repository = SyncQueueRepository();
    final subscription = SyncQueueRepository.onAppended.listen((_) {
      pendingAtWakeUp = repository.getPending();
    });
    addTearDown(subscription.cancel);

    await repository.append(eventNamed('e5'));
    await Future<void>.delayed(Duration.zero);

    // Announcing before the write would let the drain read a queue the event
    // is not in yet, and the wake-up would be wasted.
    expect(
      (await pendingAtWakeUp).map((e) => e.id),
      contains('e5'),
    );
  });
}
