package vnpt.vsp.wear.ui.services

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Haptic feedback service for Wear OS.
 * AC3: haptic feedback on interactions.
 */
class WatchHapticService(private val context: Context) {

    private val _isEnabled = MutableStateFlow(true)
    val isEnabled: StateFlow<Boolean> = _isEnabled.asStateFlow()

    private val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
        manager.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    fun setEnabled(enabled: Boolean) {
        _isEnabled.value = enabled
    }

    /** Short tap — for score increment, button press. */
    fun tap() {
        if (!_isEnabled.value) return
        vibrate(VibrationEffect.createOneShot(30, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    /** Double tap — for selection confirmation. */
    fun doubleTap() {
        if (!_isEnabled.value) return
        val pattern = longArrayOf(0, 40, 60, 40)
        vibrate(VibrationEffect.createWaveform(pattern, -1))
    }

    /** Long vibration — for error or end-of-round. */
    fun longBuzz() {
        if (!_isEnabled.value) return
        vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    /** Rising tone — for achievement (e.g., hole-in-one). */
    fun risingTone() {
        if (!_isEnabled.value) return
        val timings = longArrayOf(0, 50, 50, 100, 50, 150)
        val amplitudes = intArrayOf(0, 80, 0, 150, 0, 255)
        vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
    }

    private fun vibrate(effect: VibrationEffect) {
        if (!vibrator.hasVibrator()) return
        try {
            vibrator.vibrate(effect)
        } catch (e: SecurityException) {
            android.util.Log.w("WatchHapticService", "Vibration permission not granted", e)
        }
    }
}
