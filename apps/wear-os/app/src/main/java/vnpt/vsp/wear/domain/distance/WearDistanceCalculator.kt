package vnpt.vsp.wear.domain.distance

import vnpt.vsp.wear.domain.model.WearDistance
import vnpt.vsp.wear.domain.model.WearDistanceValue
import vnpt.vsp.wear.domain.model.WearHazardDistance
import vnpt.vsp.wear.domain.model.WearHoleSubset
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Pure, dependency-free distance calculator for the watch round experience.
 *
 * All geometry uses WGS84 lat/lon (SRID 4326) and the great-circle (haversine)
 * distance in metres. It never fabricates precision:
 *  - Front-center-back is produced only when the hole carries real front, center
 *    and back green points; otherwise [compute] returns null and the UI shows
 *    its "no fix / no data" placeholder.
 *  - Confidence is derived solely from the reported GPS accuracy, so a poor fix
 *    is surfaced rather than hidden.
 */
object WearDistanceCalculator {

    private const val EARTH_RADIUS_M = 6_371_000.0

    /** Great-circle distance in metres between two WGS84 coordinates. */
    fun haversineMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double,
    ): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_M * c
    }

    /**
     * Map a raw GPS accuracy radius (metres) to a 0.0–1.0 confidence. Monotonic:
     * tighter fixes yield higher confidence. This is a data-quality signal, not
     * an adjustment to the measured distance.
     */
    fun confidenceForAccuracy(accuracyMeters: Double): Double = when {
        accuracyMeters <= 3 -> 0.98
        accuracyMeters <= 8 -> 0.9
        accuracyMeters <= 15 -> 0.75
        accuracyMeters <= 30 -> 0.5
        else -> 0.3
    }

    /**
     * Compute [WearDistance] for [hole] from the player's current position.
     *
     * @return a fully-populated distance panel, or null when the hole lacks the
     *   front/back green geometry required for an honest front-center-back read.
     */
    fun compute(
        playerLat: Double,
        playerLon: Double,
        accuracyMeters: Double,
        hole: WearHoleSubset,
    ): WearDistance? {
        val frontLat = hole.frontLat
        val frontLon = hole.frontLon
        val backLat = hole.backLat
        val backLon = hole.backLon
        if (frontLat == null || frontLon == null || backLat == null || backLon == null) {
            return null
        }

        val confidence = confidenceForAccuracy(accuracyMeters)

        val front = WearDistanceValue(
            meters = haversineMeters(playerLat, playerLon, frontLat, frontLon),
            confidence = confidence,
        )
        val center = WearDistanceValue(
            meters = haversineMeters(playerLat, playerLon, hole.centerLat, hole.centerLon),
            confidence = confidence,
        )
        val back = WearDistanceValue(
            meters = haversineMeters(playerLat, playerLon, backLat, backLon),
            confidence = confidence,
        )

        val pinLat = hole.pinLat
        val pinLon = hole.pinLon
        val pin = if (pinLat != null && pinLon != null) {
            WearDistanceValue(
                meters = haversineMeters(playerLat, playerLon, pinLat, pinLon),
                confidence = confidence,
            )
        } else {
            null
        }

        val hazards = hole.hazards.map { hz ->
            // Distance to the nearest edge of the hazard's bounding box — the
            // closest point the player must clear — rather than its centre.
            val nearLat = playerLat.coerceIn(min(hz.minLat, hz.maxLat), max(hz.minLat, hz.maxLat))
            val nearLon = playerLon.coerceIn(min(hz.minLon, hz.maxLon), max(hz.minLon, hz.maxLon))
            WearHazardDistance(
                type = hz.type,
                label = hz.label,
                meters = haversineMeters(playerLat, playerLon, nearLat, nearLon),
                confidence = confidence,
            )
        }

        return WearDistance(
            holeNumber = hole.holeNumber,
            par = hole.par,
            frontGreen = front,
            centerGreen = center,
            backGreen = back,
            pin = pin,
            hazards = hazards,
            confidence = confidence,
            gpsAccuracyMeters = accuracyMeters,
            isLive = true,
            holeLengthMeters = hole.holeLengthMeters,
        )
    }
}
