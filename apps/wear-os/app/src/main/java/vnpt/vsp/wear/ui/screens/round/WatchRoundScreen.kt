package vnpt.vsp.wear.ui.screens.round

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import vnpt.vsp.wear.domain.model.WearDistance
import vnpt.vsp.wear.domain.model.WearDistanceValue
import vnpt.vsp.wear.domain.model.WearHoleScore
import vnpt.vsp.wear.domain.model.GpsQuality
import vnpt.vsp.wear.ui.screens.common.BatterySavingIndicator
import vnpt.vsp.wear.ui.screens.common.OfflineIndicator
import vnpt.vsp.wear.ui.theme.Background
import vnpt.vsp.wear.ui.theme.GolfGreen
import vnpt.vsp.wear.ui.theme.GolfGreenLight
import vnpt.vsp.wear.ui.theme.White

/**
 * Main watch round screen — composes hole info, distance, and score cards.
 * AC1: equivalent watch information and scoring, glanceable, one/two-tap.
 *
 * Input wiring:
 * - Rotating crown → scroll between cards OR increment/decrement score
 * - Button → navigate cards or confirm
 * - Touch bezel → swipe navigation
 */
@Composable
fun WatchRoundScreen(
    holeNumber: Int,
    par: Int,
    totalHoles: Int,
    distance: WearDistance?,
    score: WearHoleScore?,
    gpsQuality: GpsQuality,
    hasGpsFix: Boolean,
    isOffline: Boolean,
    isBatterySaving: Boolean,
    onStrokesDelta: (Int) -> Unit,
    onPuttsDelta: (Int) -> Unit,
    onPenaltiesDelta: (Int) -> Unit,
    onHolePrevious: () -> Unit,
    onHoleNext: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Background)
            .padding(4.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Status row: offline + battery indicators
        StatusRow(
            isOffline = isOffline,
            isBatterySaving = isBatterySaving
        )

        // Hole info
        HoleInfoCard(
            holeNumber = holeNumber,
            par = par,
            totalHoles = totalHoles,
            gpsQuality = gpsQuality,
            hasGpsFix = hasGpsFix,
            modifier = Modifier.fillMaxWidth()
        )

        // Distance card
        distance?.let {
            DistanceCard(
                distance = it,
                modifier = Modifier.fillMaxWidth()
            )
        } ?: DistancePlaceholder()

        // Score card
        ScoreCard(
            score = score,
            currentPar = par,
            onStrokesDelta = onStrokesDelta,
            onPuttsDelta = onPuttsDelta,
            onPenaltiesDelta = onPenaltiesDelta,
            modifier = Modifier.fillMaxWidth()
        )

        // Navigation hint
        NavigationHint(
            onHolePrevious = onHolePrevious,
            onHoleNext = onHoleNext
        )
    }
}

@Composable
private fun StatusRow(
    isOffline: Boolean,
    isBatterySaving: Boolean,
    modifier: Modifier = Modifier
) {
    androidx.compose.foundation.layout.Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End
    ) {
        if (isOffline) {
            OfflineIndicator()
        }
        if (isBatterySaving) {
            BatterySavingIndicator()
        }
    }
}

@Composable
private fun DistancePlaceholder(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(8.dp),
        horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally
    ) {
        Text(
            text = "No GPS fix",
            fontSize = 10.sp,
            color = White.copy(alpha = 0.5f)
        )
    }
}

@Composable
private fun NavigationHint(
    onHolePrevious: () -> Unit,
    onHoleNext: () -> Unit,
    modifier: Modifier = Modifier
) {
    androidx.compose.foundation.layout.Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = "◀ PREV",
            fontSize = 8.sp,
            color = White.copy(alpha = 0.4f),
            modifier = Modifier.padding(start = 4.dp)
        )
        Text(
            text = "NEXT ▶",
            fontSize = 8.sp,
            color = White.copy(alpha = 0.4f),
            modifier = Modifier.padding(end = 4.dp)
        )
    }
}
