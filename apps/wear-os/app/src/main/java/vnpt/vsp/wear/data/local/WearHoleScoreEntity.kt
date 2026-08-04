package vnpt.vsp.wear.data.local

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Room entity for WearHoleScore.
 * Foreign key to wear_rounds.id.
 */
@Entity(
    tableName = "wear_hole_scores",
    foreignKeys = [
        ForeignKey(
            entity = WearRoundEntity::class,
            parentColumns = ["id"],
            childColumns = ["roundId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("roundId")]
)
data class WearHoleScoreEntity(
    @PrimaryKey
    val id: String,
    val roundId: String,
    val playerId: String,
    val holeNumber: Int,
    val strokes: Int?,
    val putts: Int?,
    val penalties: Int?,
    val fairwayHit: Boolean?,
    val gir: Boolean?,
    val notes: String?,
    val syncStatus: String,
    val version: Int,
    val enteredAt: Long,
    val updatedAt: Long
) {
    companion object {
        fun fromDomain(s: vnpt.vsp.wear.domain.model.WearHoleScore) = WearHoleScoreEntity(
            id = s.id,
            roundId = s.roundId,
            playerId = s.playerId,
            holeNumber = s.holeNumber,
            strokes = s.strokes,
            putts = s.putts,
            penalties = s.penalties,
            fairwayHit = s.fairwayHit,
            gir = s.gir,
            notes = s.notes,
            syncStatus = s.syncStatus.name,
            version = s.version,
            enteredAt = s.enteredAt,
            updatedAt = s.updatedAt
        )
    }

    fun toDomain() = vnpt.vsp.wear.domain.model.WearHoleScore(
        id = id,
        roundId = roundId,
        playerId = playerId,
        holeNumber = holeNumber,
        strokes = strokes,
        putts = putts,
        penalties = penalties,
        fairwayHit = fairwayHit,
        gir = gir,
        notes = notes,
        syncStatus = vnpt.vsp.wear.domain.model.SyncStatus.valueOf(syncStatus),
        version = version,
        enteredAt = enteredAt,
        updatedAt = updatedAt
    )
}
