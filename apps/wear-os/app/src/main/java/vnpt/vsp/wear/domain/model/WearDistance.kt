package vnpt.vsp.wear.domain.model

/**
 * Distance data for the current hole — aligned with WatchDistanceDataDto.
 * All distances in meters; confidence 0.0–1.0.
 */
data class WearDistance(
    val holeNumber: Int,
    val par: Int,
    val frontGreen: WearDistanceValue,
    val centerGreen: WearDistanceValue,
    val backGreen: WearDistanceValue,
    val pin: WearDistanceValue? = null,          // distance to pin (when known)
    val hazards: List<WearHazardDistance> = emptyList(),
    val confidence: Double,                       // 0.0–1.0 overall confidence
    val gpsAccuracyMeters: Double,
    val isLive: Boolean = true,
    val computedAt: Long = System.currentTimeMillis(),
    val holeLengthMeters: Int? = null
)

/** Single distance value with confidence. */
data class WearDistanceValue(
    val meters: Double,
    val confidence: Double  // 0.0–1.0
)

/** Hazard distance entry — water, bunker, out-of-bounds, etc. */
data class WearHazardDistance(
    val type: HazardType,
    val label: String,           // e.g. "Lake", "Bunker"
    val meters: Double,
    val confidence: Double,
    val carryMeters: Double? = null  // distance to carry hazard
)

enum class HazardType {
    WATER,
    BUNKER,
    OUT_OF_BOUNDS,
    TREES,
    OTHER
}
