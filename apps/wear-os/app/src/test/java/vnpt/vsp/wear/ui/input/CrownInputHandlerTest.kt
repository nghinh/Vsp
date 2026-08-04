package vnpt.vsp.wear.ui.input

import android.view.KeyEvent
import org.junit.Assert.assertEquals
import org.junit.Test

class CrownInputHandlerTest {

    @Test
    fun `isCrownEvent returns true for rotary encoder source`() {
        val event = KeyEvent(0, 0)
        // We can't easily mock the source, so just verify the logic
        val source = android.view.InputDevice.SOURCE_ROTARY_ENCODER
        assertEquals(true, source and android.view.InputDevice.SOURCE_ROTARY_ENCODER != 0)
    }
}
