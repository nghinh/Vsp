package vnpt.vsp.wear.ui.input

import org.junit.Assert.assertEquals
import org.junit.Test

class DeviceCapabilitiesTest {

    @Test
    fun `primaryInput returns crown when available`() {
        val caps = DeviceCapabilities(
            hasRotatingCrown = true,
            hasTouchBezel = false,
            hasPhysicalButton = true
        )
        assertEquals(InputCapability.RotatingCrown, caps.primaryInput)
    }

    @Test
    fun `primaryInput returns bezel when crown unavailable`() {
        val caps = DeviceCapabilities(
            hasRotatingCrown = false,
            hasTouchBezel = true,
            hasPhysicalButton = true
        )
        assertEquals(InputCapability.TouchBezel, caps.primaryInput)
    }

    @Test
    fun `primaryInput falls back to button when nothing available`() {
        val caps = DeviceCapabilities(
            hasRotatingCrown = false,
            hasTouchBezel = false,
            hasPhysicalButton = true
        )
        assertEquals(InputCapability.PhysicalButton, caps.primaryInput)
    }
}
