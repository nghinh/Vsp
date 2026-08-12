// SyncWorker — VSP Mobile App
//
// Background sync worker that processes the SQLite event queue using an
// exponential backoff strategy. Runs on a dart:async Timer — never blocks
// the UI thread.
//
// Backoff formula: min(baseDelay * 2^attemptCount, maxDelay)
//
// Defaults per story 5.4 spec:
//   baseDelay = 5 seconds
//   maxDelay  = 300 seconds (5 minutes)
//   maxAttempts = 5
//
// Story 5.4: Synchronize Round Idempotently — Slice 3

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/services/connectivity_service.dart';
import '../../domain/models/sync_event.dart';
import '../../domain/models/sync_status.dart';
import '../persistence/sync_queue_repository.dart';
import 'idempotency_client.dart';

/// Configuration for the sync worker backoff strategy.
class SyncWorkerConfig {
  /// Base delay in seconds before first retry.
  final int baseDelaySeconds;

  /// Maximum delay cap in seconds.
  final int maxDelaySeconds;

  /// Maximum number of sync attempts per event.
  final int maxAttempts;

  const SyncWorkerConfig({
    this.baseDelaySeconds = 5,
    this.maxDelaySeconds = 300,
    this.maxAttempts = 5,
  });

  /// Compute backoff delay for a given attempt count.
  ///
  /// Formula: min(baseDelay * 2^attemptCount, maxDelay)
  Duration backoffDelay(int attemptCount) {
    final seconds = (baseDelaySeconds * (1 << attemptCount))
        .clamp(0, maxDelaySeconds)
        .toDouble();
    return Duration(seconds: seconds.toInt());
  }
}

/// Callback invoked when sync status changes (used by UI to react).
typedef SyncStatusCallback = void Function(SyncStatus status);

/// Background sync worker that drains the SQLite event queue.
///
/// Lifecycle:
/// 1. [start] begins listening for connectivity changes and timers.
/// 2. When connectivity returns, [processQueue] is called.
/// 3. [processQueue] iterates pending events, calls [IdempotencyClient],
///    applies backoff on failure, and marks events synced/failed.
/// 4. Worker stops automatically when all events are synced and the round
///    is complete (caller invokes [stop]).
class SyncWorker {
  final SyncQueueRepository _repository;
  final IdempotencyClient _idempotencyClient;
  final ConnectivityService _connectivity;
  final SyncWorkerConfig _config;

  /// Stream subscription for connectivity changes.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Wakes the worker the moment anything is queued.
  StreamSubscription<void>? _appendedSub;

  /// Timer for the next scheduled sync attempt.
  Timer? _syncTimer;

  /// True when the worker is running.
  bool _isRunning = false;

  /// The drain currently in flight, if any.
  ///
  /// Four things wake this worker — the retry timer, a connectivity change,
  /// [syncNow], and anything appended to the queue — and nothing stopped two
  /// of them overlapping. Both runs then read the same pending rows and posted
  /// the same event, so the server saw every score twice, microseconds apart
  /// and under one idempotency key. Concurrent duplicates race each other into
  /// the same row and the loser fails on the unique index; the score survived
  /// only because the queue retried afterwards.
  Future<void>? _draining;

  /// Callback invoked whenever the aggregated sync status changes.
  final SyncStatusCallback? onStatusChanged;

  /// Round completion flag — set to true to signal the worker to stop
  /// once all events are synced.
  bool _roundComplete = false;

  SyncWorker({
    required SyncQueueRepository repository,
    required IdempotencyClient idempotencyClient,
    required ConnectivityService connectivity,
    SyncWorkerConfig config = const SyncWorkerConfig(),
    this.onStatusChanged,
  }) : _repository = repository,
       _idempotencyClient = idempotencyClient,
       _connectivity = connectivity,
       _config = config;

  /// Whether the worker is currently active.
  bool get isRunning => _isRunning;

  /// Start the worker — begins listening for connectivity changes.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Listen for connectivity changes to trigger sync on reconnect.
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Anything newly queued is drained now rather than at the next
    // connectivity change — which, for a phone that stays online through a
    // whole round, never comes.
    _appendedSub = SyncQueueRepository.onAppended.listen(
      (_) => _triggerSyncIfOnline(),
    );

    // Also trigger an immediate sync attempt if we already have connectivity.
    _triggerSyncIfOnline();
  }

  /// Stop the worker and cancel all pending timers.
  void stop() {
    _isRunning = false;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _appendedSub?.cancel();
    _appendedSub = null;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Signal that the round is complete — the worker will stop after
  /// all events are synced.
  void setRoundComplete() {
    _roundComplete = true;
    // If nothing is pending, stop immediately.
    _checkStopCondition();
  }

  /// Drain whatever is queued right now, without waiting for connectivity to
  /// change.
  ///
  /// [start] only reacts to a connectivity *change*, so a device that was
  /// already online when the worker started, or one whose round has just ended,
  /// had no way to say "go now". A round finishing on the 18th with a bar of
  /// signal should not wait for the golfer to walk into a dead spot and out
  /// again before their scores leave the phone.
  Future<void> syncNow() => _processQueue();

  /// Manually retry a specific failed event by ID.
  Future<void> retry(String eventId) async {
    final events = await _repository.getAll();
    final event = events.where((e) => e.id == eventId).firstOrNull;
    if (event == null) return;

    // Reset to pending so it gets picked up on next sync.
    await _repository.append(
      event.copyWith(
        state: SyncStatus.pending,
        attemptCount: 0,
        errorMessage: null,
      ),
    );

    _triggerSyncIfOnline();
  }

  /// Trigger a sync if the device is currently online.
  Future<void> _triggerSyncIfOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (results.any((r) => r != ConnectivityResult.none)) {
      _scheduleSyncImmediately();
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.any((r) => r != ConnectivityResult.none)) {
      _scheduleSyncImmediately();
    }
  }

  void _scheduleSyncImmediately() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 100), _processQueue);
  }

  /// Drains the queue, and never more than once at a time.
  ///
  /// A caller that arrives mid-drain awaits the run already under way rather
  /// than starting a second one over the same rows.
  Future<void> _processQueue() {
    final running = _draining;
    if (running != null) return running;
    final started = _drainQueue().whenComplete(() => _draining = null);
    _draining = started;
    return started;
  }

  /// Main sync loop — fetches pending events and processes them one by one.
  Future<void> _drainQueue() async {
    if (!_isRunning) return;

    final pending = await _repository.getPending();
    if (pending.isEmpty) {
      _notifyStatus(SyncStatus.synced);
      _checkStopCondition();
      return;
    }

    // Check for any event that has permanently failed (max attempts reached).
    final hasHardFailure = pending.any(
      (e) => e.attemptCount >= _config.maxAttempts,
    );
    if (hasHardFailure) {
      // Mark all permanently-failed events as failed.
      for (final event in pending) {
        if (event.attemptCount >= _config.maxAttempts) {
          await _repository.markFailed(
            event.id,
            'Max retry attempts (${_config.maxAttempts}) exceeded',
          );
        }
      }
      _notifyStatus(SyncStatus.failed);
      _checkStopCondition();
      return;
    }

    _notifyStatus(
      pending.any((e) => e.state == SyncStatus.syncing)
          ? SyncStatus.syncing
          : SyncStatus.pending,
    );

    // Process each event.
    for (final event in pending) {
      if (!_isRunning) break;

      // Skip events that are already at max attempts.
      if (event.attemptCount >= _config.maxAttempts) continue;

      // Mark as syncing.
      await _repository.markSyncing(event.id);
      _notifyStatus(SyncStatus.syncing);

      // Compute backoff delay for the NEXT retry (current attempt is attemptCount).
      final delay = _config.backoffDelay(event.attemptCount);

      try {
        final result = await _idempotencyClient.syncEvent(event);

        if (result.isSuccess) {
          await _repository.markSynced(event.id);
        } else if (result.isPermanentFailure) {
          // The server rejected this data and will reject it again — a
          // validation error or a conflict. Retrying cannot help.
          await _repository.markFailed(
            event.id,
            result.errorMessage ?? 'Client error',
          );
        } else {
          // Retryable: 5xx, transport, or a 4xx about the request rather than
          // the data. Back to pending, not failed — markFailed takes the event
          // out of getPending()'s selection, so the backoff timer below would
          // fire on a queue that no longer contained it.
          await _repository.incrementAttemptCount(event.id);
          await _repository.markRetryable(
            event.id,
            result.errorMessage ?? 'Server error',
          );

          // Schedule retry after backoff.
          _scheduleRetry(delay);
        }
      } catch (e) {
        // Network or unexpected error — treat as retryable.
        await _repository.incrementAttemptCount(event.id);
        await _repository.markRetryable(event.id, e.toString());

        // Schedule retry after backoff.
        _scheduleRetry(delay);
      }
    }

    // After processing, check if queue is drained.
    final remaining = await _repository.pendingCount();
    if (remaining == 0) {
      // Check if any are permanently failed.
      final all = await _repository.getAll();
      final hasFailed = all.any((e) => e.state == SyncStatus.failed);
      _notifyStatus(hasFailed ? SyncStatus.failed : SyncStatus.synced);
      _checkStopCondition();
    }
  }

  void _scheduleRetry(Duration delay) {
    if (!_isRunning) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(delay, _processQueue);
  }

  void _checkStopCondition() {
    if (!_roundComplete || !_isRunning) return;
    // Worker will stop once pending count reaches 0 and all events are synced.
    _repository.pendingCount().then((count) {
      if (count == 0) {
        stop();
      }
    });
  }

  void _notifyStatus(SyncStatus status) {
    onStatusChanged?.call(status);
  }
}

// ---------------------------------------------------------------------------
// SyncResult — returned by IdempotencyClient.syncEvent
// ---------------------------------------------------------------------------

/// Result of a single sync attempt.
class SyncResult {
  final bool isSuccess;
  final bool isPermanentFailure;
  final String? errorMessage;

  const SyncResult._({
    required this.isSuccess,
    required this.isPermanentFailure,
    this.errorMessage,
  });

  factory SyncResult.success() =>
      const SyncResult._(isSuccess: true, isPermanentFailure: false);

  factory SyncResult.retryable({String? errorMessage}) => SyncResult._(
    isSuccess: false,
    isPermanentFailure: false,
    errorMessage: errorMessage,
  );

  factory SyncResult.permanentFailure({String? errorMessage}) => SyncResult._(
    isSuccess: false,
    isPermanentFailure: true,
    errorMessage: errorMessage,
  );
}
