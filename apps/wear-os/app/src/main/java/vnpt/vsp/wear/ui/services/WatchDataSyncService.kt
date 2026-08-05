package vnpt.vsp.wear.ui.services

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import vnpt.vsp.wear.data.local.WearDatabase

/**
 * Sync service for Wear OS round data.
 * AC3: offline + always-on — syncs local data to backend when connectivity available.
 *
 * Local-first: all writes go to Room immediately; this service
 * handles background sync when network is available.
 */
class WatchDataSyncService(
    private val context: Context,
    private val database: WearDatabase,
    private val connectivityService: WatchConnectivityService
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _syncState = MutableStateFlow<SyncState>(SyncState.Idle)
    val syncState: StateFlow<SyncState> = _syncState.asStateFlow()

    private val _pendingCount = MutableStateFlow(0)
    val pendingCount: StateFlow<Int> = _pendingCount.asStateFlow()

    private var isSyncing = false

    init {
        // Observe connectivity to trigger sync when coming online
        scope.launch {
            connectivityService.isOnline.collect { online ->
                if (online) {
                    trySyncPending()
                }
            }
        }
        // Periodically refresh pending count
        scope.launch {
            while (true) {
                refreshPendingCount()
                delay(30_000)
            }
        }
    }

    /**
     * Trigger a sync attempt for all pending rounds and scores.
     * Called when connectivity is restored or manually.
     */
    fun trySyncPending() {
        if (isSyncing) return
        scope.launch {
            syncPendingData()
        }
    }

    private suspend fun syncPendingData() {
        isSyncing = true
        try {
            // Shared stepping (also used by WatchSyncWorker) keeps a single
            // source of truth for the local-first, idempotent sync policy.
            vnpt.vsp.wear.data.sync.WearSyncEngine.syncPending(
                database = database,
                connectivity = connectivityService,
            ) { state -> _syncState.value = state }
        } catch (e: Exception) {
            // State already set to Failed by the engine; swallow so the
            // connectivity observer keeps running.
            Log.e("WatchDataSyncService", "Sync failed", e)
        } finally {
            isSyncing = false
            refreshPendingCount()
        }
    }

    private suspend fun refreshPendingCount() {
        _pendingCount.value =
            vnpt.vsp.wear.data.sync.WearSyncEngine.pendingCount(database)
    }
}

