package vnpt.vsp.wear.ui.screens.round

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import vnpt.vsp.wear.domain.model.WearHoleScore
import vnpt.vsp.wear.ui.theme.GolfGreen
import vnpt.vsp.wear.ui.theme.GolfGreenLight
import vnpt.vsp.wear.ui.theme.HazardOrange
import vnpt.vsp.wear.ui.theme.White

/**
 * Quick score card — one-tap to increment strokes, two-tap for putts/penalties.
 * AC1: quick score entry, glanceable.
 */
@Composable
fun ScoreCard(
    score: WearHoleScore?,
    currentPar: Int,
    onStrokesDelta: (Int) -> Unit,
    onPuttsDelta: (Int) -> Unit,
    onPenaltiesDelta: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val strokes = score?.strokes ?: 0
    val putts = score?.putts ?: 0
    val penalties = score?.penalties ?: 0
    val scoreToPar = score?.let { (it.strokes ?: 0) - currentPar }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        // Main score row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ScoreColumn(
                label = "STROKES",
                value = strokes,
                color = GolfGreenLight,
                onTap = { onStrokesDelta(1) },
                onLongPress = { onStrokesDelta(-1) }
            )

            // Score to par indicator
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(when {
                        scoreToPar == null -> White.copy(alpha = 0.1f)
                        scoreToPar == 0 -> GolfGreen
                        scoreToPar > 0 -> HazardOrange
                        else -> GolfGreenLight
                    }),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = scoreToPar?.let {
                        when {
                            it == 0 -> "E"
                            it > 0 -> "+$it"
                            else -> "$it"
                        }
                    } ?: "-",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = White,
                    textAlign = TextAlign.Center
                )
            }

            ScoreColumn(
                label = "PUTTS",
                value = putts,
                color = White,
                onTap = { onPuttsDelta(1) },
                onLongPress = { onPuttsDelta(-1) }
            )
        }

        // Penalties row — compact
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            PenaltyChip(
                count = penalties,
                onIncrement = { onPenaltiesDelta(1) },
                onDecrement = { onPenaltiesDelta(-1) }
            )
        }
    }
}

@Composable
private fun ScoreColumn(
    label: String,
    value: Int,
    color: androidx.compose.ui.graphics.Color,
    onTap: () -> Unit,
    onLongPress: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clickable(onClick = onTap),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = label,
            fontSize = 8.sp,
            color = White.copy(alpha = 0.6f)
        )
        Text(
            text = value.toString(),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = color
        )
    }
}

@Composable
private fun PenaltyChip(
    count: Int,
    onIncrement: () -> Unit,
    onDecrement: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(CircleShape)
            .background(White.copy(alpha = 0.1f))
            .clickable(onClick = onIncrement),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(text = "-", fontSize = 12.sp, color = White.copy(alpha = 0.6f))
        Text(text = "PEN $count", fontSize = 9.sp, color = HazardOrange)
        Text(text = "+", fontSize = 12.sp, color = White.copy(alpha = 0.6f))
    }
}
