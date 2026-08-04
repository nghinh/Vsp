// SyncStatus — VSP Mobile App
//
// Aggregated sync status enum and helpers for the round sync queue.
// Displayed via SyncStatusBadge in the scorecard.
//
// Story 5.4: Synchronize Round Idempotently

import 'sync_event.dart';

/// Aggregated sync status shown at the round/scorecard level.
///
/// Derived from the worst state of all queued sync events:
/// - failed  → any event has permanently failed
/// - syncing → any event is currently syncing
/// - pending → events waiting to sync (no syncing or failed)
/// - synced  → no pending events
enum SyncStatus { pending, syncing, synced, failed }

SyncStatus parseSyncStatus(String? value) {
  return SyncStatus.values.firstWhere(
    (status) => status.name == value?.toLowerCase(),
    orElse: () => SyncStatus.pending,
  );
}

/// Extension helpers for SyncStatus.
extension SyncStatusHelpers on SyncStatus {
  /// Human-readable label for display in SyncStatusBadge.
  String get label {
    switch (this) {
      case SyncStatus.pending:
        return 'Saved offline';
      case SyncStatus.syncing:
        return 'Syncing…';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.failed:
        return 'Sync failed';
    }
  }

  /// Accessibility label for screen readers.
  String get accessibilityLabel {
    switch (this) {
      case SyncStatus.pending:
        return 'Round sync status: saved offline, will sync when online';
      case SyncStatus.syncing:
        return 'Round sync status: syncing now';
      case SyncStatus.synced:
        return 'Round sync status: all changes synced';
      case SyncStatus.failed:
        return 'Round sync status: sync failed, tap to retry';
    }
  }
}

/// Aggregate a list of SyncEvents into a round-level SyncStatus.
///
/// Priority order (highest → lowest):
///   failed > syncing > pending > synced
SyncStatus aggregateSyncStatus(List<SyncEvent> events) {
  if (events.isEmpty) return SyncStatus.synced;

  bool hasFailed = false;
  bool hasSyncing = false;
  bool hasPending = false;

  for (final event in events) {
    switch (event.state) {
      case SyncStatus.failed:
        hasFailed = true;
      case SyncStatus.syncing:
        hasSyncing = true;
      case SyncStatus.pending:
        hasPending = true;
      case SyncStatus.synced:
      // no-op
    }
  }

  if (hasFailed) return SyncStatus.failed;
  if (hasSyncing) return SyncStatus.syncing;
  if (hasPending) return SyncStatus.pending;
  return SyncStatus.synced;
}
