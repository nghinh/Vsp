package vnpt.vsp.wear.domain.model

import java.util.UUID

/**
 * Wear OS round session — aligned with WatchRoundSessionDto from packages/contracts.
 * Stored locally in Room; synced to backend when connectivity available.
 *
 * AC1: offline-first, local durability before sync
 */
data class WearRound(
    val id: String = UUID.randomUUID().toString(),
    val roundId: String? = null,           // assigned by backend after first sync
    val courseId: Int,
    val courseName: String,
    val teeSetId: String,
    val currentHole: Int = 1,
    val currentPar: Int = 4,
    val totalHoles: Int = 18,
    val status: RoundStatus = RoundStatus.ACTIVE,
    val gpsQuality: GpsQuality = GpsQuality.UNKNOWN,
    val gpsAccuracyMeters: Double = 0.0,
    val hasGpsFix: Boolean = false,
    val packageVersion: String,
    val syncStatus: SyncStatus = SyncStatus.LOCAL,
    val startedAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val endedAt: Long? = null
)

enum class RoundStatus {
    ACTIVE,
    PAUSED,
    COMPLETED,
    ABANDONED
}

enum class GpsQuality {
    UNKNOWN,
    POOR,
    MODERATE,
    GOOD,
    EXCELLENT
}

enum class SyncStatus {
    LOCAL,    // written locally, not yet submitted
    PENDING,  // submitted, awaiting server ack
    SYNCED,   // confirmed by server
    CONFLICT  // server rejected / version mismatch
}
