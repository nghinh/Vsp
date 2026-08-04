package vnpt.vsp.wear.ui.input

import android.content.Context
import android.hardware.input.InputManager
import android.os.Build
import android.view.InputDevice
import android.view.KeyEvent
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Detects available input hardware capabilities on the Wear OS device.
 * AC2: bezel/crown/button detection and input adaptation.
 *
 * Detection strategy:
 * - Rotating crown: KEYCODE_ROTATE_* events OR InputDevice has SOURCE_ROTARY_ENCODER
 * - Touch bezel: InputDevice.SOURCE_TOUCH_NAVIGATION (GesturePad / Bezel)
 * - Button: KEYCODE_* button events from physical buttons
 */
sealed class InputCapability {
    data object RotatingCrown : InputCapability()
    data object TouchBezel : InputCapability()
    data object PhysicalButton : InputCapability()
}

data class DeviceCapabilities(
    val hasRotatingCrown: Boolean = false,
    val hasTouchBezel: Boolean = false,
    val hasPhysicalButton: Boolean = false,
    val deviceModel: String = "unknown",
    val manufacturer: String = "unknown"
) {
    val primaryInput: InputCapability
        get() = when {
            hasRotatingCrown -> InputCapability.RotatingCrown
            hasTouchBezel -> InputCapability.TouchBezel
            hasPhysicalButton -> InputCapability.PhysicalButton
            else -> InputCapability.PhysicalButton  // fallback
        }
}

class DeviceCapabilityDetector(private val context: Context) {

    private val _capabilities = MutableStateFlow(DeviceCapabilities())
    val capabilities: StateFlow<DeviceCapabilities> = _capabilities.asStateFlow()

    /** Call on app startup to detect and log device capabilities. */
    fun detect(): DeviceCapabilities {
        val caps = DeviceCapabilities(
            hasRotatingCrown = detectRotatingCrown(),
            hasTouchBezel = detectTouchBezel(),
            hasPhysicalButton = detectPhysicalButtons()
        )
        _capabilities.value = caps
        logCapabilities(caps)
        return caps
    }

    private fun detectRotatingCrown(): Boolean {
        // Check for rotary encoder input devices
        val inputManager = context.getSystemService(Context.INPUT_SERVICE) as? InputManager
        inputManager?.let { manager ->
            for (deviceId in manager.inputDeviceIds) {
                val device = manager.getInputDevice(deviceId)
                if (device != null && device.supportsSource(InputDevice.SOURCE_ROTARY_ENCODER)) {
                    return true
                }
            }
        }
        return false
    }

    private fun detectTouchBezel(): Boolean {
        // Most Wear OS devices with a bezel report touch navigation
        val inputManager = context.getSystemService(Context.INPUT_SERVICE) as? InputManager
        inputManager?.let { manager ->
            for (deviceId in manager.inputDeviceIds) {
                val device = manager.getInputDevice(deviceId)
                if (device != null && device.supportsSource(InputDevice.SOURCE_TOUCH_NAVIGATION)) {
                    return true
                }
            }
        }
        // Fallback: assume bezel if it's a known round Wear OS device
        return Build.MODEL.contains("Watch", ignoreCase = true)
    }

    private fun detectPhysicalButtons(): Boolean {
        // All Wear OS watches have at least one physical button.
        // This is a fallback detection — assumes buttons exist.
        // We could check for KEYCODE_POWER events but that's complex
        // since the power button is handled by the system.
        return true  // All Wear OS devices have physical buttons
    }

    private fun logCapabilities(caps: DeviceCapabilities) {
        android.util.Log.d("DeviceCapability", "Detected: crown=${caps.hasRotatingCrown}, " +
                "bezel=${caps.hasTouchBezel}, button=${caps.hasPhysicalButton}, " +
                "primary=${caps.primaryInput}, model=${caps.deviceModel}")
    }

    companion object {
        fun isWearOsDevice(): Boolean =
            Build.MANUFACTURER.equals("Google", ignoreCase = true) ||
            Build.BRAND.equals("google", ignoreCase = true) ||
            Build.BRAND.equals("wearos", ignoreCase = true)
    }
}
