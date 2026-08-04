package vnpt.vsp.wear.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material.MaterialTheme

// Golf-inspired color palette for Wear OS
val GolfGreen = Color(0xFF1B5E20)
val GolfGreenLight = Color(0xFF4CAF50)
val FairwayGreen = Color(0xFF2E7D32)
val SkyBlue = Color(0xFF03A9F4)
val SandBeige = Color(0xFFD7CCC8)
val HazardOrange = Color(0xFFFF9800)
val WaterBlue = Color(0xFF2196F3)
val RoughBrown = Color(0xFF795548)
val White = Color(0xFFFFFFFF)
val Black = Color(0xFF000000)
val Background = Color(0xFF121212)

private val DarkColors = androidx.wear.compose.material.Colors(
    primary = GolfGreenLight,
    primaryVariant = GolfGreen,
    onPrimary = White,
    secondary = SkyBlue,
    secondaryVariant = WaterBlue,
    onSecondary = Black,
    background = Color(0xFF121212),
    onBackground = Color(0xFFE0E0E0),
    surface = Color(0xFF1E1E1E),
    onSurface = Color(0xFFE0E0E0),
    error = HazardOrange,
    onError = Black
)

private val LightColors = androidx.wear.compose.material.Colors(
    primary = GolfGreen,
    primaryVariant = GolfGreenLight,
    onPrimary = White,
    secondary = SkyBlue,
    secondaryVariant = WaterBlue,
    onSecondary = White,
    background = Color(0xFFFAFAFA),
    onBackground = Color(0xFF121212),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF121212),
    error = HazardOrange,
    onError = Black
)

@Composable
fun WearTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) DarkColors else LightColors

    MaterialTheme(
        colors = colors,
        content = content
    )
}
