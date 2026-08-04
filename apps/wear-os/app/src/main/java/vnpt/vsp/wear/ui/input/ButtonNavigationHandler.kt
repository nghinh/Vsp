package vnpt.vsp.wear.ui.input

import android.view.KeyEvent
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Handles physical button navigation on Wear OS.
 * Maps button keycodes to navigation actions.
 */
sealed class ButtonAction {
    data object Select : ButtonAction()
    data object Back : ButtonAction()
    data object StartRound : ButtonAction()
    data object EndRound : ButtonAction()
    data object NoOp : ButtonAction()
}

class ButtonNavigationHandler {

    private val _lastAction = MutableStateFlow<ButtonAction>(ButtonAction.NoOp)
    val lastAction: StateFlow<ButtonAction> = _lastAction.asStateFlow()

    /** Called by MainActivity on KEY_DOWN events. Returns true if consumed. */
    fun onButtonEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return false

        val action = mapKeyToAction(event.keyCode)
        if (action != ButtonAction.NoOp) {
            _lastAction.value = action
            return true
        }
        return false
    }

    private fun mapKeyToAction(keyCode: Int): ButtonAction {
        return when (keyCode) {
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_STEM_PRIMARY -> ButtonAction.Select

            KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_ESCAPE -> ButtonAction.Back

            // Some watches have a dedicated app button (stem tertiary)
            KeyEvent.KEYCODE_STEM_3 -> ButtonAction.StartRound

            KeyEvent.KEYCODE_POWER,
            KeyEvent.KEYCODE_ENDCALL -> ButtonAction.EndRound

            else -> ButtonAction.NoOp
        }
    }
}
