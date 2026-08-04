// SyncState Model — VSP Mobile App
//
// Sync state for round completion and score corrections.
// Per Story 5.5 Slice 2: AC-2 sync state indicator.

// Note: This file exists to avoid importing from data/services.
// It mirrors the SyncState enum from RoundStateService.

/// Sync state enumeration for round and score operations.
enum SyncState {
  /// All changes have been synced to the server.
  synced,

  /// There are pending changes waiting to sync.
  pending,

  /// Sync is currently in progress.
  syncing,

  /// Sync failed and needs retry.
  failed;

  /// True if this state represents a completed (successful) sync.
  bool get isSynced => this == SyncState.synced;

  /// True if this state represents a failure that needs attention.
  bool get needsRetry => this == SyncState.failed;

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case SyncState.synced:
        return 'Synced';
      case SyncState.pending:
        return 'Pending';
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.failed:
        return 'Failed';
    }
  }

  /// Icon name for UI display (Material icon name).
  String get iconName {
    switch (this) {
      case SyncState.synced:
        return 'check_circle';
      case SyncState.pending:
        return 'cloud_upload';
      case SyncState.syncing:
        return 'sync';
      case SyncState.failed:
        return 'error';
    }
  }
}
