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
import vnpt.vsp.wear.domain.state.WatchSyncState
import vnpt.vsp.wear.ui.theme.GolfGreen
import vnpt.vsp.wear.ui.theme.HazardOrange
import vnpt.vsp.wear.ui.theme.SkyBlue
import vnpt.vsp.wear.ui.theme.White

/**
 * Sync status indicator — shown when syncing/sync error.
 */
@Composable
fun SyncStatusIndicator(
    syncState: WatchSyncState,
    modifier: Modifier = Modifier
) {
    val (color, label) = when (syncState) {
        WatchSyncState.Idle -> return
        WatchSyncState.Syncing -> SkyBlue to "SYNCING"
        WatchSyncState.Success -> GolfGreen to "SYNCED"
        WatchSyncState.Failed -> HazardOrange to "SYNC ERR"
    }

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(color.copy(alpha = 0.2f))
            .padding(horizontal = 4.dp, vertical = 2.dp)
    ) {
        Text(
            text = label,
            fontSize = 8.sp,
            fontWeight = FontWeight.Medium,
            color = color
        )
    }
}
