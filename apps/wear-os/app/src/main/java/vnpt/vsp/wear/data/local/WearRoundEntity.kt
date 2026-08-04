package vnpt.vsp.wear.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import vnpt.vsp.wear.domain.model.GpsQuality
import vnpt.vsp.wear.domain.model.RoundStatus
import vnpt.vsp.wear.domain.model.SyncStatus

/**
 * Room entity for WearRound.
 */
@Entity(tableName = "wear_rounds")
data class WearRoundEntity(
    @PrimaryKey
    val id: String,
    val roundId: String?,
    val courseId: Int,
    val courseName: String,
    val teeSetId: String,
    val currentHole: Int,
    val currentPar: Int,
    val totalHoles: Int,
    val status: String,
    val gpsQuality: String,
    val gpsAccuracyMeters: Double,
    val hasGpsFix: Boolean,
    val packageVersion: String,
    val syncStatus: String,
    val startedAt: Long,
    val updatedAt: Long,
    val endedAt: Long?
) {
    companion object {
        fun fromDomain(r: vnpt.vsp.wear.domain.model.WearRound) = WearRoundEntity(
            id = r.id,
            roundId = r.roundId,
            courseId = r.courseId,
            courseName = r.courseName,
            teeSetId = r.teeSetId,
            currentHole = r.currentHole,
            currentPar = r.currentPar,
            totalHoles = r.totalHoles,
            status = r.status.name,
            gpsQuality = r.gpsQuality.name,
            gpsAccuracyMeters = r.gpsAccuracyMeters,
            hasGpsFix = r.hasGpsFix,
            packageVersion = r.packageVersion,
            syncStatus = r.syncStatus.name,
            startedAt = r.startedAt,
            updatedAt = r.updatedAt,
            endedAt = r.endedAt
        )
    }

    fun toDomain() = vnpt.vsp.wear.domain.model.WearRound(
        id = id,
        roundId = roundId,
        courseId = courseId,
        courseName = courseName,
        teeSetId = teeSetId,
        currentHole = currentHole,
        currentPar = currentPar,
        totalHoles = totalHoles,
        status = RoundStatus.valueOf(status),
        gpsQuality = GpsQuality.valueOf(gpsQuality),
        gpsAccuracyMeters = gpsAccuracyMeters,
        hasGpsFix = hasGpsFix,
        packageVersion = packageVersion,
        syncStatus = SyncStatus.valueOf(syncStatus),
        startedAt = startedAt,
        updatedAt = updatedAt,
        endedAt = endedAt
    )
}
