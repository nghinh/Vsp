package vnpt.vsp.wear.ui.input

import android.view.MotionEvent

/**
 * Handles touch bezel (GesturePad / touch navigation ring) input on Wear OS.
 * Bezel gestures: swipe around edge = navigation, tap = select, long-press = back.
 */
sealed class BezelGesture {
    data class Swipe(val direction: SwipeDirection, val degrees: Float) : BezelGesture()
    data object Tap : BezelGesture()
    data object LongPress : BezelGesture()
}

enum class SwipeDirection {
    CLOCKWISE,
    COUNTER_CLOCKWISE,
    UP,
    DOWN
}

class BezelInputHandler {

    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var touchStartTime = 0L

    /** Called from Compose touch interop. Returns parsed BezelGesture or null. */
    fun onTouchEvent(event: MotionEvent): BezelGesture? {
        return when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                lastTouchX = event.x
                lastTouchY = event.y
                touchStartTime = System.currentTimeMillis()
                null
            }
            MotionEvent.ACTION_UP -> {
                val duration = System.currentTimeMillis() - touchStartTime
                val dx = event.x - lastTouchX
                val dy = event.y - lastTouchY

                if (duration > 500) {
                    BezelGesture.LongPress
                } else if (kotlin.math.abs(dx) < 20 && kotlin.math.abs(dy) < 20) {
                    BezelGesture.Tap
                } else {
                    parseSwipeGesture(dx, dy)
                }
            }
            else -> null
        }
    }

    private fun parseSwipeGesture(dx: Float, dy: Float): BezelGesture {
        // Determine dominant axis and direction
        return if (kotlin.math.abs(dx) > kotlin.math.abs(dy)) {
            if (dx > 0) BezelGesture.Swipe(SwipeDirection.CLOCKWISE, kotlin.math.abs(dx))
            else BezelGesture.Swipe(SwipeDirection.COUNTER_CLOCKWISE, kotlin.math.abs(dx))
        } else {
            if (dy > 0) BezelGesture.Swipe(SwipeDirection.DOWN, kotlin.math.abs(dy))
            else BezelGesture.Swipe(SwipeDirection.UP, kotlin.math.abs(dy))
        }
    }
}
