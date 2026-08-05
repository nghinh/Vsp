package vnpt.vsp.wear.domain.state

import android.app.Application
import android.location.Location
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import vnpt.vsp.wear.data.local.WearDatabase
import vnpt.vsp.wear.data.repository.WearRoundRepository
import vnpt.vsp.wear.data.repository.WearScoreRepository
import vnpt.vsp.wear.data.sync.WatchSyncWorker
import vnpt.vsp.wear.domain.distance.WearDistanceCalculator
import vnpt.vsp.wear.domain.model.GpsQuality
import vnpt.vsp.wear.domain.model.SyncStatus
import vnpt.vsp.wear.domain.model.WearCourseSubset
import vnpt.vsp.wear.domain.model.WearHoleScore
import vnpt.vsp.wear.domain.model.WearRound
import vnpt.vsp.wear.ui.services.AlwaysOnService
import vnpt.vsp.wear.ui.services.WatchConnectivityService
import vnpt.vsp.wear.ui.services.WatchDataSyncService
import vnpt.vsp.wear.ui.services.SyncState
import vnpt.vsp.wear.ui.services.WatchHapticService
import vnpt.vsp.wear.ui.services.WatchLocationService

/**
 * Main ViewModel for the Wear OS round experience.
 * Ties together RoundState, ScoreState, WatchState, and all services.
 */
class WatchStateHolder(application: Application) : AndroidViewModel(application) {

    private val database = WearDatabase.getInstance(application)

    // Repositories
    private val roundRepository = WearRoundRepository(database)
    private val scoreRepository = WearScoreRepository(database)

    // Services
    val connectivityService = WatchConnectivityService(application)
    private val alwaysOnService = AlwaysOnService(application)
    val hapticService = WatchHapticService(application)
    private val locationService = WatchLocationService(application)
    private val syncService = WatchDataSyncService(application, database, connectivityService)

    // ── UI State ──────────────────────────────────────────────────────────────

    private val _roundUiState = MutableStateFlow(RoundUiState())
    val roundUiState: StateFlow<RoundUiState> = _roundUiState.asStateFlow()

    private val _scoreUiState = MutableStateFlow(ScoreUiState())
    val scoreUiState: StateFlow<ScoreUiState> = _scoreUiState.asStateFlow()

    private val _watchUiState = MutableStateFlow(WatchUiState())
    val watchUiState: StateFlow<WatchUiState> = _watchUiState.asStateFlow()

    /**
     * Offline course geometry for the active round. Populated at runtime from
     * the paired phone via the Wearable Data Layer (see WatchDataSyncService /
     * WatchConnectivityService); that transport requires a paired device and is
     * therefore verified only on real hardware. Once set, distances are computed
     * on-device from GPS with no further phone round-trips.
     */
    private var courseSubset: WearCourseSubset? = null

    // ── Init ──────────────────────────────────────────────────────────────────

    init {
        // Observe active round
        roundRepository.observeActiveRound()
            .onEach { round ->
                _roundUiState.value = _roundUiState.value.copy(round = round)
            }
            .launchIn(viewModelScope)

        // Observe connectivity → update WatchUiState
        connectivityService.isOnline
            .onEach { online ->
                _watchUiState.value = _watchUiState.value.copy(isOffline = !online)
            }
            .launchIn(viewModelScope)

        // Observe sync state
        syncService.syncState
            .onEach { state ->
                _watchUiState.value = _watchUiState.value.copy(
                    syncStatus = when (state) {
                        is SyncState.Idle -> vnpt.vsp.wear.domain.state.WatchSyncState.Idle
                        is SyncState.Syncing -> vnpt.vsp.wear.domain.state.WatchSyncState.Syncing
                        is SyncState.Success -> vnpt.vsp.wear.domain.state.WatchSyncState.Success
                        is SyncState.Failed -> vnpt.vsp.wear.domain.state.WatchSyncState.Failed
                    }
                )
            }
            .launchIn(viewModelScope)

        // Observe location
        locationService.latestLocation
            .onEach { location ->
                updateGpsQuality(location)
            }
            .launchIn(viewModelScope)

        // Observe battery saving mode
        locationService.isBatterySaving
            .onEach { eco ->
                _watchUiState.value = _watchUiState.value.copy(isBatterySaving = eco)
            }
            .launchIn(viewModelScope)

        // Schedule periodic sync worker
        WatchSyncWorker.schedulePeriodic(application)
    }

    // ── Round Actions ──────────────────────────────────────────────────────────

    fun startRound(courseId: Int, courseName: String, teeSetId: String, packageVersion: String) {
        viewModelScope.launch {
            val round = WearRound(
                courseId = courseId,
                courseName = courseName,
                teeSetId = teeSetId,
                packageVersion = packageVersion
            )
            roundRepository.startRound(round)
            alwaysOnService.enableAlwaysOn()
            locationService.startLocationUpdates(ecoMode = _watchUiState.value.isBatterySaving)
        }
    }

    fun navigateToHole(hole: Int) {
        viewModelScope.launch {
            val round = _roundUiState.value.round ?: return@launch
            val updated = round.copy(currentHole = hole, updatedAt = System.currentTimeMillis())
            roundRepository.updateRound(updated)
            loadScoreForCurrentHole()
            // Refresh the distance panel for the new hole using the last fix.
            recomputeDistance(locationService.latestLocation.value, hole)
        }
    }

    /**
     * Provide (or replace) the offline course geometry used to compute
     * distances. Called at runtime once the paired phone has synced the course
     * subset for the active round.
     */
    fun setCourseSubset(subset: WearCourseSubset) {
        courseSubset = subset
        recomputeDistance(locationService.latestLocation.value, _roundUiState.value.currentHole)
    }

    fun completeRound() {
        viewModelScope.launch {
            val round = _roundUiState.value.round ?: return@launch
            roundRepository.completeRound(round.id)
            alwaysOnService.disableAlwaysOn()
            locationService.stopLocationUpdates()
            hapticService.risingTone()
        }
    }

    // ── Score Actions ──────────────────────────────────────────────────────────

    fun loadScoreForCurrentHole() {
        viewModelScope.launch {
            val round = _roundUiState.value.round ?: return@launch
            val score = scoreRepository.getScoreForHole(round.id, round.currentHole)
            _scoreUiState.value = _scoreUiState.value.copy(score = score)
        }
    }

    fun updateStrokes(delta: Int) {
        viewModelScope.launch {
            val current = _scoreUiState.value.score
            val round = _roundUiState.value.round ?: return@launch
            val newStrokes = (current?.strokes ?: 0) + delta
            if (newStrokes < 0) return@launch

            val updatedScore = (current ?: createEmptyScore(round.id, round.currentHole))
                .copy(strokes = newStrokes, updatedAt = System.currentTimeMillis())
            scoreRepository.saveScore(updatedScore)
            _scoreUiState.value = _scoreUiState.value.copy(score = updatedScore)
            hapticService.tap()
        }
    }

    fun updatePutts(delta: Int) {
        viewModelScope.launch {
            val current = _scoreUiState.value.score
            val round = _roundUiState.value.round ?: return@launch
            val newPutts = (current?.putts ?: 0) + delta
            if (newPutts < 0) return@launch

            val updatedScore = (current ?: createEmptyScore(round.id, round.currentHole))
                .copy(putts = newPutts, updatedAt = System.currentTimeMillis())
            scoreRepository.saveScore(updatedScore)
            _scoreUiState.value = _scoreUiState.value.copy(score = updatedScore)
            hapticService.tap()
        }
    }

    fun updatePenalties(delta: Int) {
        viewModelScope.launch {
            val current = _scoreUiState.value.score
            val round = _roundUiState.value.round ?: return@launch
            val newPenalties = (current?.penalties ?: 0) + delta
            if (newPenalties < 0) return@launch

            val updatedScore = (current ?: createEmptyScore(round.id, round.currentHole))
                .copy(penalties = newPenalties, updatedAt = System.currentTimeMillis())
            scoreRepository.saveScore(updatedScore)
            _scoreUiState.value = _scoreUiState.value.copy(score = updatedScore)
            hapticService.tap()
        }
    }

    fun toggleFairwayHit() {
        viewModelScope.launch {
            val current = _scoreUiState.value.score ?: return@launch
            val updated = current.copy(
                fairwayHit = !(current.fairwayHit ?: false),
                updatedAt = System.currentTimeMillis()
            )
            scoreRepository.saveScore(updated)
            _scoreUiState.value = _scoreUiState.value.copy(score = updated)
        }
    }

    fun toggleGir() {
        viewModelScope.launch {
            val current = _scoreUiState.value.score ?: return@launch
            val updated = current.copy(
                gir = !(current.gir ?: false),
                updatedAt = System.currentTimeMillis()
            )
            scoreRepository.saveScore(updated)
            _scoreUiState.value = _scoreUiState.value.copy(score = updated)
        }
    }

    private suspend fun createEmptyScore(roundId: String, holeNumber: Int): WearHoleScore {
        return WearHoleScore(
            roundId = roundId,
            playerId = "local_watch",  // TODO: actual player ID
            holeNumber = holeNumber
        )
    }

    // ── Watch State Actions ────────────────────────────────────────────────────

    fun toggleBatterySaving() {
        locationService.toggleBatterySaving()
    }

    fun setHapticsEnabled(enabled: Boolean) {
        hapticService.setEnabled(enabled)
    }

    fun setAlwaysOn(enabled: Boolean) {
        if (enabled) alwaysOnService.enableAlwaysOn() else alwaysOnService.disableAlwaysOn()
    }

    fun forceSyncNow() {
        syncService.trySyncPending()
    }

    // ── GPS ───────────────────────────────────────────────────────────────────

    private fun updateGpsQuality(location: Location?) {
        if (location == null) return
        val quality = when {
            location.accuracy <= 3 -> GpsQuality.EXCELLENT
            location.accuracy <= 8 -> GpsQuality.GOOD
            location.accuracy <= 15 -> GpsQuality.MODERATE
            location.accuracy <= 30 -> GpsQuality.POOR
            else -> GpsQuality.UNKNOWN
        }
        viewModelScope.launch {
            val round = _roundUiState.value.round ?: return@launch
            val updated = round.copy(
                gpsQuality = quality,
                gpsAccuracyMeters = location.accuracy.toDouble(),
                hasGpsFix = true,
                updatedAt = System.currentTimeMillis()
            )
            roundRepository.updateRound(updated)
        }
        // Recompute glanceable distances from the new fix (no-op until a course
        // subset has been synced from the paired phone).
        recomputeDistance(location, _roundUiState.value.currentHole)
    }

    /**
     * Recompute front-center-back / pin / hazard distances for [hole] from the
     * given fix. Sets `distance` to null when there is no fix or no course
     * geometry, so the UI falls back to its placeholder rather than showing
     * stale values.
     */
    private fun recomputeDistance(location: Location?, hole: Int) {
        val subset = courseSubset
        val holeSubset = subset?.holes?.firstOrNull { it.holeNumber == hole }
        if (location == null || holeSubset == null) {
            if (_roundUiState.value.distance != null) {
                _roundUiState.value = _roundUiState.value.copy(distance = null)
            }
            return
        }
        val distance = WearDistanceCalculator.compute(
            playerLat = location.latitude,
            playerLon = location.longitude,
            accuracyMeters = location.accuracy.toDouble(),
            hole = holeSubset,
        )
        _roundUiState.value = _roundUiState.value.copy(distance = distance)
    }
}
