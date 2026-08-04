package vnpt.vsp.wear.domain.model

/**
 * Minimal course data subset synced to watch for offline play.
 * Derived from packages/contracts course package manifest.
 * Only holes for the active round are stored to conserve watch storage.
 */
data class WearCourseSubset(
    val courseId: Int,
    val courseName: String,
    val tees: List<WearTeeSetSubset> = emptyList(),
    val holes: List<WearHoleSubset> = emptyList(),
    val packageVersion: String,
    val syncedAt: Long = System.currentTimeMillis()
)

data class WearTeeSetSubset(
    val teeSetId: String,
    val name: String,          // e.g. "Black", "White", "Gold"
    val par: Int,              // total par for this tee set
    val gender: String? = null // "male", "female", null
)

data class WearHoleSubset(
    val holeNumber: Int,
    val par: Int,
    val holeLengthMeters: Int? = null,
    // Simplified geometry — only centroid stored for distance calc
    val centerLat: Double,
    val centerLon: Double,
    val pinLat: Double? = null,
    val pinLon: Double? = null,
    // Simplified hazard bounding boxes (min/max lat/lon)
    val hazards: List<WearHoleSubset.WearHazardGeometry> = emptyList()
) {
    data class WearHazardGeometry(
        val type: HazardType,
        val label: String,
        val minLat: Double,
        val minLon: Double,
        val maxLat: Double,
        val maxLon: Double
    )
}
