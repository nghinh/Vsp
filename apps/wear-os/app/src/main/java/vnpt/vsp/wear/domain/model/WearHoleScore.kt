package vnpt.vsp.wear.domain.model

import java.util.UUID

/**
 * Per-hole score for Wear OS — aligned with WatchHoleScoreDto from packages/contracts.
 */
data class WearHoleScore(
    val id: String = UUID.randomUUID().toString(),
    val roundId: String,           // WearRound.id
    val playerId: String,
    val holeNumber: Int,           // 1–18 (or 1–9 for 9-hole)
    val strokes: Int? = null,
    val putts: Int? = null,
    val penalties: Int? = null,
    val fairwayHit: Boolean? = null,
    val gir: Boolean? = null,      // green-in-regulation
    val notes: String? = null,
    val syncStatus: SyncStatus = SyncStatus.LOCAL,
    val version: Int = 1,
    val enteredAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
) {
    /** Net score relative to par for this hole. */
    fun scoreToPar(par: Int): Int? = strokes?.let { it - par }
}
