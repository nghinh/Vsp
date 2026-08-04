package vnpt.vsp.wear

import android.Manifest
import android.os.Bundle
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import vnpt.vsp.wear.domain.state.WatchStateHolder
import vnpt.vsp.wear.ui.input.ButtonAction
import vnpt.vsp.wear.ui.input.ButtonNavigationHandler
import vnpt.vsp.wear.ui.input.CrownInputHandler
import vnpt.vsp.wear.ui.input.DeviceCapabilityDetector
import vnpt.vsp.wear.ui.screens.round.WatchRoundScreen
import vnpt.vsp.wear.ui.theme.WearTheme

class MainActivity : ComponentActivity() {

    private lateinit var deviceCapabilityDetector: DeviceCapabilityDetector
    private lateinit var crownInputHandler: CrownInputHandler
    private lateinit var buttonNavigationHandler: ButtonNavigationHandler

    private val locationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val granted = permissions.entries.any { it.value }
        android.util.Log.d("MainActivity", "Location permission granted: $granted")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Detect device capabilities at startup (AC2)
        deviceCapabilityDetector = DeviceCapabilityDetector(this)
        val capabilities = deviceCapabilityDetector.detect()

        crownInputHandler = CrownInputHandler()
        buttonNavigationHandler = ButtonNavigationHandler()

        // Request location permission on first launch
        locationPermissionLauncher.launch(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        )

        // Log input adaptation
        android.util.Log.d("MainActivity",
            "Primary input: ${capabilities.primaryInput}")

        setContent {
            WearTheme {
                val viewModel: WatchStateHolder = viewModel()
                val roundState by viewModel.roundUiState.collectAsState()
                val watchState by viewModel.watchUiState.collectAsState()
                val scoreState by viewModel.scoreUiState.collectAsState()

                var currentScreen by remember { mutableStateOf(Screen.DISTANCE) }

                WatchRoundScreen(
                    holeNumber = roundState.currentHole,
                    par = roundState.currentPar,
                    totalHoles = roundState.totalHoles,
                    distance = roundState.distance,
                    score = scoreState.score,
                    gpsQuality = roundState.gpsQuality,
                    hasGpsFix = roundState.hasGpsFix,
                    isOffline = watchState.isOffline,
                    isBatterySaving = watchState.isBatterySaving,
                    onStrokesDelta = viewModel::updateStrokes,
                    onPuttsDelta = viewModel::updatePutts,
                    onPenaltiesDelta = viewModel::updatePenalties,
                    onHolePrevious = {
                        val hole = (roundState.currentHole - 1).coerceAtLeast(1)
                        viewModel.navigateToHole(hole)
                    },
                    onHoleNext = {
                        val hole = (roundState.currentHole + 1).coerceAtMost(roundState.totalHoles)
                        viewModel.navigateToHole(hole)
                    }
                )
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (buttonNavigationHandler.onButtonEvent(event ?: return false)) {
            handleButtonAction(buttonNavigationHandler.lastAction.value)
            return true
        }
        if (CrownInputHandler.isCrownEvent(event ?: return false)) {
            crownInputHandler.onCrownEvent(event ?: return false)
            handleCrownAction(event)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun handleButtonAction(action: ButtonAction) {
        when (action) {
            ButtonAction.Select -> { /* confirm / save */ }
            ButtonAction.Back -> { /* navigate back */ }
            ButtonAction.StartRound -> { /* start round */ }
            ButtonAction.EndRound -> { /* end round */ }
            ButtonAction.NoOp -> { }
        }
    }

    private fun handleCrownAction(event: KeyEvent) {
        // Crown rotation direction handled in CrownInputHandler
    }

    override fun onDestroy() {
        super.onDestroy()
        // Location updates are stopped in ViewModel's clear()
    }
}

enum class Screen {
    DISTANCE,
    SCORE,
    ROUND_INFO
}
