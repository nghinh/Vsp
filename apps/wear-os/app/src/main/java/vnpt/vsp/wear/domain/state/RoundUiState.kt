package vnpt.vsp.wear.domain.state

import vnpt.vsp.wear.domain.model.GpsQuality
import vnpt.vsp.wear.domain.model.RoundStatus
import vnpt.vsp.wear.domain.model.SyncStatus
import vnpt.vsp.wear.domain.model.WearDistance
import vnpt.vsp.wear.domain.model.WearRound

/**
 * UI state for the active watch round screen.
 */
data class RoundUiState(
    val round: WearRound? = null,
    val distance: WearDistance? = null,
    val isLoading: Boolean = false,
    val error: String? = null
) {
    val currentHole: Int get() = round?.currentHole ?: 1
    val currentPar: Int get() = round?.currentPar ?: 4
    val totalHoles: Int get() = round?.totalHoles ?: 18
    val gpsQuality: GpsQuality get() = round?.gpsQuality ?: GpsQuality.UNKNOWN
    val roundStatus: RoundStatus get() = round?.status ?: RoundStatus.ACTIVE
    val hasGpsFix: Boolean get() = round?.hasGpsFix ?: false
    val roundSyncStatus: SyncStatus get() = round?.syncStatus ?: SyncStatus.LOCAL
}

/**
 * Events emitted by the round screen.
 */
sealed class RoundEvent {
    data class HoleChanged(val hole: Int) : RoundEvent()
    data object RoundStarted : RoundEvent()
    data object RoundCompleted : RoundEvent()
    data object RoundAbandoned : RoundEvent()
    data class GpsQualityUpdated(val quality: GpsQuality) : RoundEvent()
    data class Error(val message: String) : RoundEvent()
}
