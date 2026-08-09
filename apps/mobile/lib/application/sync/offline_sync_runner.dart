// Offline Sync Runner — VSP Mobile App
//
// Starts the workers that drain the offline queue.
//
// This exists because nothing did. `SyncWorker` — the drainer for every queued
// round, score and shot event, with the exponential backoff and attempt cap —
// was complete and constructed nowhere in the app. Every on-course write was
// persisted locally exactly as
// designed, an idempotency key was generated for it exactly as designed, it was
// appended to `sync_queue` exactly as designed, and then it sat in SQLite for
// ever. Repointing the sync client at endpoints that exist fixed the address on
// the envelope; nobody was carrying the post.
//
// Two places need this and they need it for different reasons:
//
//   • A round. Four hours of writes, and the phone drifts in and out of signal
//     the whole time — the queue has to drain as soon as a bar comes back, not
//     when the golfer next opens the app.
//   • App start. A round that ended in a dead spot, or an app that was killed
//     mid-round, leaves a queue behind. Without a drain at launch it waits for
//     the next round, and a golfer who plays monthly waits a month.
//
// Nothing here throws at its caller. A sync runner that cannot start is a
// golfer whose scores are still safely on the device; a sync runner that throws
// into the widget tree is a golfer looking at a red screen.

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../data/services/connectivity_service.dart';
import '../../infrastructure/persistence/sync_queue_repository.dart';
import '../../infrastructure/sync/idempotency_client.dart';
import '../../infrastructure/sync/sync_worker.dart';

/// Owns the workers that drain the offline queue, and their lifetime.
class OfflineSyncRunner {
  SyncWorker? _syncWorker;
  bool _disposed = false;

  /// Injectable for tests, which have neither SharedPreferences nor SQLite.
  final SyncWorker? _injectedSyncWorker;

  OfflineSyncRunner({SyncWorker? syncWorker})
    : _injectedSyncWorker = syncWorker;

  /// True once the worker is running.
  bool get isRunning => _syncWorker?.isRunning ?? false;

  /// Builds and starts the worker.
  ///
  /// Safe to call more than once and safe to fail: a device that cannot give up
  /// its preferences or open its database simply keeps its queue until the next
  /// attempt.
  Future<void> start() async {
    if (_disposed || _syncWorker != null) return;

    try {
      final injected = _injectedSyncWorker;
      final connectivity = injected != null
          ? null
          : ConnectivityService(prefs: await SharedPreferences.getInstance());
      if (_disposed) return;

      final queue = SyncQueueRepository();
      _syncWorker =
          injected ??
          SyncWorker(
            repository: queue,
            idempotencyClient: IdempotencyClient(apiClient: ApiClient()),
            connectivity: connectivity!,
          );
      _syncWorker!.start();
    } catch (_) {
      // No preferences, no database, no network stack. The queue is still on
      // the device and the next start will find it.
      _syncWorker = null;
    }
  }

  /// Drains whatever is queued right now, without waiting for connectivity to
  /// change. Used when a round ends.
  Future<void> flush() async {
    try {
      await _syncWorker?.syncNow();
    } catch (_) {
      // Same reasoning as start(): a failed flush loses nothing.
    }
  }

  /// Stops the worker. Safe to call more than once.
  void dispose() {
    _disposed = true;
    _syncWorker?.stop();
    _syncWorker = null;
  }
}
