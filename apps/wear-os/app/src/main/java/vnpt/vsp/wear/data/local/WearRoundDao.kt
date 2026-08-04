package vnpt.vsp.wear.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface WearRoundDao {
    @Query("SELECT * FROM wear_rounds ORDER BY startedAt DESC")
    fun observeAllRounds(): Flow<List<WearRoundEntity>>

    @Query("SELECT * FROM wear_rounds WHERE id = :id")
    suspend fun getRoundById(id: String): WearRoundEntity?

    @Query("SELECT * FROM wear_rounds WHERE id = :id")
    fun observeRoundById(id: String): Flow<WearRoundEntity?>

    @Query("SELECT * FROM wear_rounds WHERE status = :status ORDER BY startedAt DESC")
    fun observeRoundsByStatus(status: String): Flow<List<WearRoundEntity>>

    @Query("SELECT * FROM wear_rounds WHERE syncStatus IN (:statuses)")
    suspend fun getRoundsBySyncStatus(statuses: List<String>): List<WearRoundEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRound(round: WearRoundEntity)

    @Update
    suspend fun updateRound(round: WearRoundEntity)

    @Query("UPDATE wear_rounds SET syncStatus = :status, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateSyncStatus(id: String, status: String, updatedAt: Long)

    @Query("DELETE FROM wear_rounds WHERE id = :id")
    suspend fun deleteRound(id: String)

    @Query("SELECT COUNT(*) FROM wear_rounds")
    suspend fun getRoundCount(): Int
}
