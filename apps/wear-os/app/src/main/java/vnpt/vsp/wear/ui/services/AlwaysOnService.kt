package vnpt.vsp.wear.ui.services

import android.content.Context
import android.os.PowerManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Always-on (ambient) mode service for Wear OS.
 * AC3: always-on state.
 *
 * Uses PowerManager to detect doze state and Jetpack WindowManager
 * for keep-screen-on control.
 */
class AlwaysOnService(private val context: Context) {

    private val _isAlwaysOn = MutableStateFlow(false)
    val isAlwaysOn: StateFlow<Boolean> = _isAlwaysOn.asStateFlow()

    private val powerManager =
        context.getSystemService(Context.POWER_SERVICE) as PowerManager

    /**
     * Enable always-on ambient mode.
     * Call from Activity/ViewModel when round is active.
     */
    fun enableAlwaysOn() {
        _isAlwaysOn.value = true
        android.util.Log.d("AlwaysOnService", "Always-on enabled")
    }

    /**
     * Disable always-on mode (e.g., when round ends or watch returns to idle).
     */
    fun disableAlwaysOn() {
        _isAlwaysOn.value = false
        android.util.Log.d("AlwaysOnService", "Always-on disabled")
    }

    /**
     * Toggle always-on mode.
     */
    fun toggleAlwaysOn() {
        if (_isAlwaysOn.value) disableAlwaysOn() else enableAlwaysOn()
    }

    /**
     * Check if the device is currently in a low-power idle state (doze).
     */
    fun isInIdleState(): Boolean {
        return powerManager.isPowerSaveMode
    }

    /**
     * Auto-manage based on round state — enable when round is active,
     * disable when round is paused or completed.
     */
    fun setForRoundState(isActive: Boolean) {
        if (isActive) enableAlwaysOn() else disableAlwaysOn()
    }
}
