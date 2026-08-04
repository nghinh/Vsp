package vnpt.vsp.wear.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface WearHoleScoreDao {
    @Query("SELECT * FROM wear_hole_scores WHERE roundId = :roundId ORDER BY holeNumber ASC")
    fun observeScoresForRound(roundId: String): Flow<List<WearHoleScoreEntity>>

    @Query("SELECT * FROM wear_hole_scores WHERE roundId = :roundId AND holeNumber = :holeNumber")
    suspend fun getScoreForHole(roundId: String, holeNumber: Int): WearHoleScoreEntity?

    @Query("SELECT * FROM wear_hole_scores WHERE roundId = :roundId AND holeNumber = :holeNumber")
    fun observeScoreForHole(roundId: String, holeNumber: Int): Flow<WearHoleScoreEntity?>

    @Query("SELECT * FROM wear_hole_scores WHERE syncStatus IN (:statuses)")
    suspend fun getScoresBySyncStatus(statuses: List<String>): List<WearHoleScoreEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertScore(score: WearHoleScoreEntity)

    @Update
    suspend fun updateScore(score: WearHoleScoreEntity)

    @Query("UPDATE wear_hole_scores SET syncStatus = :status, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateSyncStatus(id: String, status: String, updatedAt: Long)

    @Query("DELETE FROM wear_hole_scores WHERE roundId = :roundId")
    suspend fun deleteScoresForRound(roundId: String)
}
