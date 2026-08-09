// Tests for the thing that carries the post.
//
// SyncWorker drains every queued round, score and shot event, with the
// exponential backoff and the attempt cap. It was complete and it was
// constructed nowhere in the app. So the offline-first path worked
// exactly as designed right up to the last step: the write landed in SQLite, an
// idempotency key was minted for it, it was appended to `sync_queue` — and it
// stayed there. Repointing the sync client at endpoints that exist fixed the
// address on the envelope; nobody was carrying the post.
//
// Two properties matter here and one of them is unusual: the runner must never
// throw at its caller. It is started from a widget's initState on a device that
// may have no preferences, no database and no network stack, and a golfer whose
// scores are safe on the phone must not be shown a red screen because the
// postman is late.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/app.dart';
import 'package:vsp_mobile/application/sync/offline_sync_runner.dart';
import 'package:vsp_mobile/data/services/connectivity_service.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';
import 'package:vsp_mobile/domain/repositories/shot_repository.dart';
import 'package:vsp_mobile/infrastructure/persistence/sync_queue_repository.dart';
import 'package:vsp_mobile/infrastructure/sync/idempotency_client.dart';
import 'package:vsp_mobile/infrastructure/sync/sync_worker.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/domain/models/shot.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

/// Records what it was asked to do, and answers nothing.
class _SpySyncWorker extends SyncWorker {
  int starts = 0;
  int stops = 0;
  int drains = 0;

  _SpySyncWorker()
    : super(
        repository: SyncQueueRepository(),
        idempotencyClient: IdempotencyClient(apiClient: ApiClient()),
        connectivity: _NullConnectivity(),
      );

  @override
  void start() => starts += 1;

  @override
  void stop() => stops += 1;

  @override
  Future<void> syncNow() async => drains += 1;
}


/// A worker whose start blows up the way a device without SQLite would.
class _ThrowingSyncWorker extends _SpySyncWorker {
  @override
  void start() => throw StateError('no database on this device');
}

class _NullConnectivity implements ConnectivityService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NullShotRepository implements ShotRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value();
}

void main() {
  group('the runner', () {
    test('starts the worker', () async {
      final sync = _SpySyncWorker();
      final runner = OfflineSyncRunner(syncWorker: sync);

      await runner.start();

      expect(sync.starts, 1);
    });

    test('starting twice does not start twice', () async {
      final sync = _SpySyncWorker();
      final runner = OfflineSyncRunner(
        syncWorker: sync,
      );

      await runner.start();
      await runner.start();

      expect(sync.starts, 1);
    });

    test('flush drains without waiting for connectivity to change', () async {
      final sync = _SpySyncWorker();
      final runner = OfflineSyncRunner(syncWorker: sync);
      await runner.start();

      await runner.flush();

      // A round finishing on the 18th with a bar of signal should not wait for
      // the golfer to walk into a dead spot and out again.
      expect(sync.drains, 1);
    });

    test('dispose stops the worker', () async {
      final sync = _SpySyncWorker();
      final runner = OfflineSyncRunner(syncWorker: sync);
      await runner.start();

      runner.dispose();

      expect(sync.stops, 1);
    });

    test('a device that cannot sync does not throw at its caller', () async {
      final runner = OfflineSyncRunner(
        syncWorker: _ThrowingSyncWorker(),
      );

      // Started from initState. A golfer whose scores are safely on the phone
      // must not be shown a crash because the queue could not be opened.
      await expectLater(runner.start(), completes);
      expect(runner.isRunning, isFalse);
      await expectLater(runner.flush(), completes);
    });

    test('flushing before starting is a no-op, not an error', () async {
      final runner = OfflineSyncRunner(
        syncWorker: _SpySyncWorker(),
      );

      await expectLater(runner.flush(), completes);
    });
  });

  group('the app', () {
    testWidgets('drains the queue a previous round left behind', (
      tester,
    ) async {
      final sync = _SpySyncWorker();
      final runner = OfflineSyncRunner(
        syncWorker: sync,
      );

      await tester.pumpWidget(VspApp(syncRunner: runner));
      await tester.pump();

      // A round that ended in a dead spot, or an app killed mid-round, leaves a
      // queue behind. Without this it waits for the next round — which for a
      // monthly golfer is a month.
      expect(sync.starts, 1);
    });
  });
}
