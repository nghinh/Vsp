package vnpt.vsp.module.score;

import vnpt.vsp.module.score.dto.ScoreCorrectionRequest;
import vnpt.vsp.module.score.dto.ScoreCorrectionResponse;
import vnpt.vsp.module.score.dto.ScoreSyncRequest;
import vnpt.vsp.module.score.dto.ScoreSyncResponse;
import vnpt.vsp.module.score.dto.SyncStatusResponse;

import java.util.UUID;

/**
 * Score module public service interface.
 * Exposes score entry and flight scoring operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 */
public interface ScoreService {

    /**
     * Process a batch of score sync events from the mobile client.
     *
     * <p>The {@code idempotencyKey} is the value of the {@code Idempotency-Key} header
     * from the HTTP request. The implementation delegates to
     * {@link vnpt.vsp.api.idempotency.IdempotencyService} for deduplication —
     * this method only runs when the key is new (not a replay).
     *
     * @param accountId      authenticated golfer account ID
     * @param idempotencyKey the idempotency key from the request header
     * @param request        batch sync payload
     * @return confirmation with eventId, status, syncedAt, and optional error
     */
    SyncStatusResponse syncScores(Long accountId, String idempotencyKey, ScoreSyncRequest request);

    /**
     * Applies field-level corrections to score entries for a player in a completed round.
     * <p>
     * Validates that the round is COMPLETED, corrections target permitted fields only,
     * and creates audit entries for each change.
     * Per Story 5.5 Slice 4.
     *
     * @param roundId     the round UUID
     * @param requesterId the authenticated golfer making the correction
     * @param request     correction request with playerId and field corrections
     * @return correction response with correctionId, appliedAt, and auditId
     */
    ScoreCorrectionResponse correctScoreEntries(UUID roundId, Long requesterId, ScoreCorrectionRequest request);
}
