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
import vnpt.vsp.wear.data.local.WearHoleScoreEntity
import vnpt.vsp.wear.data.local.WearRoundEntity

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
        if (!connectivityService.isCurrentlyOnline()) {
            Log.d("WatchDataSyncService", "Skipping sync — offline")
            return
        }

        isSyncing = true
        _syncState.value = SyncState.Syncing

        try {
            // Sync pending rounds
            val pendingRounds = database.roundDao()
                .getRoundsBySyncStatus(listOf("LOCAL", "PENDING"))
            for (roundEntity in pendingRounds) {
                syncRound(roundEntity)
            }

            // Sync pending scores
            val pendingScores = database.scoreDao()
                .getScoresBySyncStatus(listOf("LOCAL", "PENDING"))
            for (scoreEntity in pendingScores) {
                syncScore(scoreEntity)
            }

            _syncState.value = SyncState.Success
            Log.d("WatchDataSyncService", "Sync completed")
        } catch (e: Exception) {
            Log.e("WatchDataSyncService", "Sync failed", e)
            _syncState.value = SyncState.Failed(e.message ?: "Unknown error")
        } finally {
            isSyncing = false
            refreshPendingCount()
        }
    }

    private suspend fun syncRound(entity: WearRoundEntity) {
        // TODO: Replace with actual OpenAPI client call to backend
        // For now: mark as synced (idempotent — no real network call)
        database.roundDao().updateSyncStatus(
            id = entity.id,
            status = "SYNCED",
            updatedAt = System.currentTimeMillis()
        )
        Log.d("WatchDataSyncService", "Synced round ${entity.id}")
    }

    private suspend fun syncScore(entity: WearHoleScoreEntity) {
        // TODO: Replace with actual OpenAPI client call to backend
        database.scoreDao().updateSyncStatus(
            id = entity.id,
            status = "SYNCED",
            updatedAt = System.currentTimeMillis()
        )
        Log.d("WatchDataSyncService", "Synced score ${entity.id}")
    }

    private suspend fun refreshPendingCount() {
        val rounds = database.roundDao()
            .getRoundsBySyncStatus(listOf("LOCAL", "PENDING")).size
        val scores = database.scoreDao()
            .getScoresBySyncStatus(listOf("LOCAL", "PENDING")).size
        _pendingCount.value = rounds + scores
    }
}

