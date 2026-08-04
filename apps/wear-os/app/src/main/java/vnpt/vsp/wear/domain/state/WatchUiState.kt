package vnpt.vsp.wear.domain.state

/**
 * Cross-cutting watch runtime state: offline, always-on, haptics, battery.
 * AC3: offline, always-on, haptic, battery-saving states.
 */
data class WatchUiState(
    val isOffline: Boolean = false,              // no network connectivity
    val isAlwaysOnEnabled: Boolean = false,     // ambient mode active
    val isHapticsEnabled: Boolean = true,        // haptic feedback on
    val isBatterySaving: Boolean = false,         // reduced GPS frequency
    val batteryLevel: Int = 100,                // 0–100
    val syncStatus: WatchSyncState = WatchSyncState.Idle,
    val lastSyncAt: Long? = null
)

enum class WatchSyncState {
    Idle,
    Syncing,
    Success,
    Failed
}
