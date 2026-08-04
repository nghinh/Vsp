package vnpt.vsp.wear.domain.state

import vnpt.vsp.wear.domain.model.SyncStatus
import vnpt.vsp.wear.domain.model.WearHoleScore

/**
 * UI state for score entry on the watch.
 */
data class ScoreUiState(
    val score: WearHoleScore? = null,
    val isEditing: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null
) {
    val syncStatus: SyncStatus get() = score?.syncStatus ?: SyncStatus.LOCAL
}

/**
 * Events emitted by the score entry screen.
 */
sealed class ScoreEvent {
    data class ScoreEntered(val strokes: Int, val putts: Int?, val penalties: Int?) : ScoreEvent()
    data class FairwayHitToggled(val hit: Boolean) : ScoreEvent()
    data class GirToggled(val gir: Boolean) : ScoreEvent()
    data object ScoreSaved : ScoreEvent()
    data class Error(val message: String) : ScoreEvent()
}
