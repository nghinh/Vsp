package vnpt.vsp.wear.ui.screens.round

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import vnpt.vsp.wear.domain.model.GpsQuality
import vnpt.vsp.wear.ui.theme.GolfGreen
import vnpt.vsp.wear.ui.theme.GolfGreenLight
import vnpt.vsp.wear.ui.theme.HazardOrange
import vnpt.vsp.wear.ui.theme.SkyBlue
import vnpt.vsp.wear.ui.theme.White

/**
 * Hole info card — shows current hole number, par, and GPS quality.
 * AC1: glanceable one-screen summary.
 */
@Composable
fun HoleInfoCard(
    holeNumber: Int,
    par: Int,
    totalHoles: Int,
    gpsQuality: GpsQuality,
    hasGpsFix: Boolean,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Hole number — large, prominent
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "HOLE",
                fontSize = 8.sp,
                color = White.copy(alpha = 0.6f)
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = holeNumber.toString(),
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = GolfGreenLight
                )
                Text(
                    text = "/$totalHoles",
                    fontSize = 12.sp,
                    color = White.copy(alpha = 0.5f)
                )
            }
        }

        // Par indicator
        ParBadge(par = par)

        // GPS quality indicator
        GpsIndicator(quality = gpsQuality, hasFix = hasGpsFix)
    }
}

@Composable
private fun ParBadge(par: Int, modifier: Modifier = Modifier) {
    val color = when (par) {
        3 -> SkyBlue
        4 -> GolfGreen
        5 -> GolfGreenLight
        else -> White.copy(alpha = 0.5f)
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(color.copy(alpha = 0.2f))
            .padding(horizontal = 8.dp, vertical = 2.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "Par $par",
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = color
        )
    }
}

@Composable
private fun GpsIndicator(
    quality: GpsQuality,
    hasFix: Boolean,
    modifier: Modifier = Modifier
) {
    val (dotColor, label) = when {
        !hasFix -> White.copy(alpha = 0.3f) to "NO FIX"
        quality == GpsQuality.EXCELLENT || quality == GpsQuality.GOOD -> GolfGreen to "GPS"
        quality == GpsQuality.MODERATE -> HazardOrange to "GPS"
        else -> HazardOrange to "WEAK"
    }

    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(RoundedCornerShape(50))
                .background(dotColor)
        )
        Text(
            text = label,
            fontSize = 8.sp,
            color = White.copy(alpha = 0.7f)
        )
    }
}
