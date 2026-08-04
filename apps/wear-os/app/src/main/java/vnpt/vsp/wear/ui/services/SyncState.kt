package vnpt.vsp.wear.ui.services

/**
 * Sync state for WatchDataSyncService.
 */
sealed class SyncState {
    data object Idle : SyncState()
    data object Syncing : SyncState()
    data object Success : SyncState()
    data class Failed(val error: String) : SyncState()
}
