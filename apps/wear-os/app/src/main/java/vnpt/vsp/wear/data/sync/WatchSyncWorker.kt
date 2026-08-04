package vnpt.vsp.wear.data.sync

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker for periodic background sync of watch data.
 * AC1/AC3: idempotent sync when connectivity is available.
 */
class WatchSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        Log.d(TAG, "WatchSyncWorker starting")
        return try {
            // TODO: Inject WearDataSyncService and call trySyncPending()
            // For now, the WatchDataSyncService handles its own background observation.
            // This worker serves as a periodic trigger when WorkManager is the preferred path.
            Log.d(TAG, "WatchSyncWorker completed")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "WatchSyncWorker failed", e)
            if (runAttemptCount < MAX_RETRIES) {
                Result.retry()
            } else {
                Result.failure()
            }
        }
    }

    companion object {
        private const val TAG = "WatchSyncWorker"
        private const val MAX_RETRIES = 3
        private const val WORK_NAME = "watch_round_sync"

        fun schedulePeriodic(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = PeriodicWorkRequestBuilder<WatchSyncWorker>(
                15, TimeUnit.MINUTES  // sync every 15 minutes
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )

            Log.d(TAG, "WatchSyncWorker scheduled")
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.d(TAG, "WatchSyncWorker cancelled")
        }
    }
}
