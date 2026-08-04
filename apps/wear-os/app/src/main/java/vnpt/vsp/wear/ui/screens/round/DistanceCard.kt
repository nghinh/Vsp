package vnpt.vsp.wear.ui.screens.round

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import vnpt.vsp.wear.domain.model.WearDistance
import vnpt.vsp.wear.domain.model.WearDistanceValue
import vnpt.vsp.wear.domain.model.WearHazardDistance
import vnpt.vsp.wear.ui.theme.GolfGreen
import vnpt.vsp.wear.ui.theme.HazardOrange
import vnpt.vsp.wear.ui.theme.SkyBlue
import vnpt.vsp.wear.ui.theme.White

/**
 * Distance card showing front/center/back green distances + pin + hazards.
 * AC1: glanceable, one-tap for hazards, front-center-back display.
 */
@Composable
fun DistanceCard(
    distance: WearDistance,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        // Front / Center / Back distances — largest text, glanceable
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            DistanceValue(label = "F", value = distance.frontGreen)
            DistanceValue(label = "C", value = distance.centerGreen, highlight = true)
            DistanceValue(label = "B", value = distance.backGreen)
        }

        // Pin distance (if available)
        distance.pin?.let { pin ->
            PinRow(pin = pin)
        }

        // Hazards row — compact, one-tap
        if (distance.hazards.isNotEmpty()) {
            HazardRow(hazards = distance.hazards)
        }
    }
}

@Composable
private fun DistanceValue(
    label: String,
    value: WearDistanceValue,
    highlight: Boolean = false,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = label,
            fontSize = 10.sp,
            color = White.copy(alpha = 0.7f)
        )
        Text(
            text = formatMeters(value.meters),
            fontSize = if (highlight) 18.sp else 16.sp,
            fontWeight = if (highlight) FontWeight.Bold else FontWeight.Medium,
            color = if (highlight) GolfGreen else White
        )
        ConfidenceIndicator(confidence = value.confidence)
    }
}

@Composable
private fun PinRow(pin: WearDistanceValue, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Text(text = "PIN ", fontSize = 9.sp, color = White.copy(alpha = 0.6f))
        Text(
            text = formatMeters(pin.meters),
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = SkyBlue
        )
    }
}

@Composable
private fun HazardRow(hazards: List<WearHazardDistance>, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.CenterVertically
    ) {
        hazards.take(3).forEach { hazard ->
            HazardChip(hazard = hazard)
        }
        if (hazards.size > 3) {
            Text(text = "+${hazards.size - 3}", fontSize = 9.sp, color = HazardOrange)
        }
    }
}

@Composable
private fun HazardChip(hazard: WearHazardDistance, modifier: Modifier = Modifier) {
    val color = when (hazard.type) {
        vnpt.vsp.wear.domain.model.HazardType.WATER -> SkyBlue
        vnpt.vsp.wear.domain.model.HazardType.BUNKER -> vnpt.vsp.wear.ui.theme.SandBeige
        vnpt.vsp.wear.domain.model.HazardType.OUT_OF_BOUNDS -> HazardOrange
        vnpt.vsp.wear.domain.model.HazardType.TREES -> GolfGreen
        vnpt.vsp.wear.domain.model.HazardType.OTHER -> White.copy(alpha = 0.7f)
    }

    Row(
        modifier = modifier.padding(end = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "${hazard.label.take(4)} ${formatMeters(hazard.meters)}",
            fontSize = 9.sp,
            color = color
        )
    }
}

@Composable
private fun ConfidenceIndicator(confidence: Double, modifier: Modifier = Modifier) {
    val color = when {
        confidence >= 0.9 -> GolfGreen
        confidence >= 0.7 -> SkyBlue
        else -> HazardOrange
    }
    Text(
        text = "%.0f%%".format(confidence * 100),
        fontSize = 8.sp,
        color = color
    )
}

private fun formatMeters(meters: Double): String {
    return if (meters >= 1000) {
        "%.1fk".format(meters / 1000)
    } else {
        "${meters.toInt()}m"
    }
}
