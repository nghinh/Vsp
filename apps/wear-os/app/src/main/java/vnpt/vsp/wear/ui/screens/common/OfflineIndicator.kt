package vnpt.vsp.wear.ui.screens.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import vnpt.vsp.wear.ui.theme.HazardOrange
import vnpt.vsp.wear.ui.theme.White

/**
 * Offline indicator — shown in status bar when no network connectivity.
 * AC3: explicit offline state.
 */
@Composable
fun OfflineIndicator(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(HazardOrange.copy(alpha = 0.2f))
            .padding(horizontal = 4.dp, vertical = 2.dp)
    ) {
        Text(
            text = "OFFLINE",
            fontSize = 8.sp,
            fontWeight = FontWeight.Medium,
            color = HazardOrange
        )
    }
}
