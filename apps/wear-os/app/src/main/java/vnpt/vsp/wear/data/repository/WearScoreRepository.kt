package vnpt.vsp.wear.data.repository

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import vnpt.vsp.wear.data.local.WearDatabase
import vnpt.vsp.wear.data.local.WearHoleScoreEntity
import vnpt.vsp.wear.domain.model.SyncStatus
import vnpt.vsp.wear.domain.model.WearHoleScore

/**
 * Repository for WearHoleScore — local-first writes, sync when online.
 * AC1: writes go to Room immediately; sync happens async.
 */
class WearScoreRepository(private val database: WearDatabase) {

    fun observeScoresForRound(roundId: String): Flow<List<WearHoleScore>> {
        return database.scoreDao().observeScoresForRound(roundId).map { entities ->
            entities.map { it.toDomain() }
        }
    }

    fun observeScoreForHole(roundId: String, holeNumber: Int): Flow<WearHoleScore?> {
        return database.scoreDao().observeScoreForHole(roundId, holeNumber).map { it?.toDomain() }
    }

    suspend fun getScoreForHole(roundId: String, holeNumber: Int): WearHoleScore? {
        return database.scoreDao().getScoreForHole(roundId, holeNumber)?.toDomain()
    }

    /** Upsert a score — writes locally immediately. */
    suspend fun saveScore(score: WearHoleScore) {
        val entity = WearHoleScoreEntity.fromDomain(score)
        database.scoreDao().insertScore(entity)
    }

    /** Delete all scores for a round. */
    suspend fun deleteScoresForRound(roundId: String) {
        database.scoreDao().deleteScoresForRound(roundId)
    }
}
