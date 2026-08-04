package vnpt.vsp.wear.data.repository

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import vnpt.vsp.wear.data.local.WearDatabase
import vnpt.vsp.wear.data.local.WearRoundEntity
import vnpt.vsp.wear.domain.model.RoundStatus
import vnpt.vsp.wear.domain.model.SyncStatus
import vnpt.vsp.wear.domain.model.WearRound

/**
 * Repository for WearRound — local-first writes, sync when online.
 * AC1: writes go to Room immediately; sync happens async.
 */
class WearRoundRepository(private val database: WearDatabase) {

    fun observeAllRounds(): Flow<List<WearRound>> {
        return database.roundDao().observeAllRounds().map { entities ->
            entities.map { it.toDomain() }
        }
    }

    fun observeActiveRound(): Flow<WearRound?> {
        return database.roundDao().observeRoundsByStatus(RoundStatus.ACTIVE.name).map { entities ->
            entities.firstOrNull()?.toDomain()
        }
    }

    fun observeRoundById(id: String): Flow<WearRound?> {
        return database.roundDao().observeRoundById(id).map { it?.toDomain() }
    }

    suspend fun getRoundById(id: String): WearRound? {
        return database.roundDao().getRoundById(id)?.toDomain()
    }

    /** Start a new round — writes locally immediately. */
    suspend fun startRound(round: WearRound): String {
        val entity = WearRoundEntity.fromDomain(round)
        database.roundDao().insertRound(entity)
        return round.id
    }

    /** Update round state (hole change, GPS quality, etc.) — writes locally immediately. */
    suspend fun updateRound(round: WearRound) {
        val updated = round.copy(
            updatedAt = System.currentTimeMillis(),
            syncStatus = if (round.syncStatus == SyncStatus.LOCAL) SyncStatus.LOCAL else SyncStatus.PENDING
        )
        database.roundDao().updateRound(WearRoundEntity.fromDomain(updated))
    }

    /** Complete a round. */
    suspend fun completeRound(roundId: String) {
        val round = database.roundDao().getRoundById(roundId) ?: return
        val updated = round.copy(
            status = RoundStatus.COMPLETED.name,
            endedAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis(),
            syncStatus = SyncStatus.PENDING.name
        )
        database.roundDao().updateRound(updated)
    }

    /** Delete a round and all its scores. */
    suspend fun deleteRound(roundId: String) {
        database.roundDao().deleteRound(roundId)
    }

    /** Mark round sync status. */
    suspend fun markSynced(roundId: String) {
        database.roundDao().updateSyncStatus(roundId, SyncStatus.SYNCED.name, System.currentTimeMillis())
    }
}
