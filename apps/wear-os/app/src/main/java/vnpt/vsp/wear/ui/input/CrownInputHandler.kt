package vnpt.vsp.wear.ui.input

import android.view.KeyEvent
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Handles rotating crown (rotary encoder) input on Wear OS.
 * Maps rotation delta to UI actions: scroll, score increment, navigation.
 */
class CrownInputHandler {

    private val _accumulatedDelta = MutableStateFlow(0f)
    val accumulatedDelta: StateFlow<Float> = _accumulatedDelta.asStateFlow()

    // Crown sensitivity: key repeat events before action triggers
    private val sensitivityThreshold = 2  // events before action triggers

    /** Called by MainActivity on ROTATE_* events. Returns true if consumed. */
    fun onCrownEvent(event: KeyEvent): Boolean {
        if (!isCrownEvent(event)) return false

        // Crown rotation comes as KEYCODE_DPAD_UP/DOWN or volume keys on rotary devices
        // Increment/decrement based on key direction
        val direction = when (event.keyCode) {
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_VOLUME_UP -> 1
            KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_VOLUME_DOWN -> -1
            else -> 0
        }

        if (direction == 0) return true

        _accumulatedDelta.value += direction.toFloat()

        if (kotlin.math.abs(_accumulatedDelta.value) >= sensitivityThreshold) {
            onCrownAction(direction)
            _accumulatedDelta.value = 0f
        }
        return true
    }

    protected open fun onCrownAction(direction: Int) {
        // Override in Compose layer to wire to state
    }

    fun reset() {
        _accumulatedDelta.value = 0f
    }

    companion object {
        fun isCrownEvent(event: KeyEvent): Boolean {
            return event.source and android.view.InputDevice.SOURCE_ROTARY_ENCODER != 0
        }
    }
}
