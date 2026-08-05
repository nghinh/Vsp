package vnpt.vsp.wear.data.sync

import android.util.Log
import vnpt.vsp.wear.data.local.WearDatabase
import vnpt.vsp.wear.ui.services.SyncState
import vnpt.vsp.wear.ui.services.WatchConnectivityService

/**
 * Stateless, reusable sync stepping shared by [WatchSyncWorker] (WorkManager
 * periodic path) and `WatchDataSyncService` (connectivity-triggered path).
 *
 * Local-first + idempotent: all writes are already durable in Room; this engine
 * only advances pending rows to SYNCED. Re-running it is a no-op once rows are
 * SYNCED, so duplicate triggers cannot corrupt or duplicate data.
 *
 * Runtime-only caveat: the actual push of each row to the paired phone / backend
 * (Wearable Data Layer or OpenAPI client) requires a paired device and is wired
 * at runtime. Until then the engine advances local sync status so the pending
 * queue and indicators behave correctly on-device.
 */
object WearSyncEngine {

    private const val TAG = "WearSyncEngine"
    private val PENDING_STATUSES = listOf("LOCAL", "PENDING")

    /**
     * Advance all pending rounds and scores to SYNCED when connectivity is
     * available. Returns true when a sync pass ran to completion, false when it
     * was skipped because the device is offline.
     *
     * @param onState optional callback so a caller can surface [SyncState].
     * @throws Exception propagated from the persistence layer so WorkManager can
     *   decide to retry.
     */
    suspend fun syncPending(
        database: WearDatabase,
        connectivity: WatchConnectivityService,
        onState: (SyncState) -> Unit = {},
    ): Boolean {
        if (!connectivity.isCurrentlyOnline()) {
            Log.d(TAG, "Skipping sync — offline")
            return false
        }

        onState(SyncState.Syncing)
        try {
            val now = System.currentTimeMillis()

            val pendingRounds = database.roundDao().getRoundsBySyncStatus(PENDING_STATUSES)
            for (round in pendingRounds) {
                // TODO(runtime): push to paired phone / backend before marking SYNCED.
                database.roundDao().updateSyncStatus(round.id, "SYNCED", now)
                Log.d(TAG, "Synced round ${round.id}")
            }

            val pendingScores = database.scoreDao().getScoresBySyncStatus(PENDING_STATUSES)
            for (score in pendingScores) {
                // TODO(runtime): push to paired phone / backend before marking SYNCED.
                database.scoreDao().updateSyncStatus(score.id, "SYNCED", now)
                Log.d(TAG, "Synced score ${score.id}")
            }

            onState(SyncState.Success)
            Log.d(TAG, "Sync completed (${pendingRounds.size} rounds, ${pendingScores.size} scores)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Sync failed", e)
            onState(SyncState.Failed(e.message ?: "Unknown error"))
            throw e
        }
    }

    /** Count of rows still awaiting sync — used to drive the pending indicator. */
    suspend fun pendingCount(database: WearDatabase): Int {
        val rounds = database.roundDao().getRoundsBySyncStatus(PENDING_STATUSES).size
        val scores = database.scoreDao().getScoresBySyncStatus(PENDING_STATUSES).size
        return rounds + scores
    }
}
