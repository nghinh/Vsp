package vnpt.vsp.module.round;

import vnpt.vsp.module.course.dto.PageResponse;
import vnpt.vsp.module.round.dto.RoundCompleteRequest;
import vnpt.vsp.module.round.dto.RoundCreateRequest;
import vnpt.vsp.module.round.dto.RoundResponse;
import vnpt.vsp.module.tournament.dto.TournamentPolicyResponse;

import java.util.UUID;

/**
 * Round module public service interface.
 * Exposes round lifecycle and configuration operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 */
public interface RoundService {

    /**
     * Creates a new round and associated score records for all players.
     * <p>
     * Validates that:
     * <ul>
     *   <li>The course exists and is active</li>
     *   <li>All player IDs correspond to valid golfer accounts</li>
     *   <li>The requesting golfer has an active round (if required by business rules)</li>
     * </ul>
     * <p>
     * The round is created with status IN_PROGRESS and startedAt set to the provided startTime
     * (or now if not provided).
     * <p>
     * Per Story 5.1 Slice D: idempotency handled by the controller layer via @Idempotent.
     *
     * @param accountId  the ID of the golfer creating the round (authenticated principal)
     * @param request    the round creation request
     * @return the created round response with ID, status, and startedAt
     * @throws vnpt.vsp.api.error.VspApiException with code COURSE_001 if course not found
     * @throws vnpt.vsp.api.error.VspApiException with code AUTH_010 if a player account not found
     */
    RoundResponse createRound(Long accountId, RoundCreateRequest request);

    /**
     * Lists the authenticated golfer's rounds, most recent first, paginated.
     * Excludes soft-deleted rounds.
     *
     * @param accountId the authenticated golfer's account ID
     * @param page      zero-based page index
     * @param size      page size
     * @return a paginated page of the golfer's rounds
     */
    PageResponse<RoundResponse> listRounds(Long accountId, int page, int size);

    /**
     * Completes a round — marks it as COMPLETED and sets endedAt.
     * <p>
     * Idempotent: if the round is already COMPLETED, returns the existing round without error.
     * Validates that:
     * <ul>
     *   <li>The round exists</li>
     *   <li>The round belongs to the authenticated golfer (they started it)</li>
     *   <li>The round is not already COMPLETED, ABANDONED, or CANCELLED</li>
     * </ul>
     * <p>
     * Per Story 5.5 Slice 1: idempotent completion endpoint.
     *
     * @param accountId the authenticated golfer's account ID
     * @param roundId  the round UUID
     * @param request  the completion request (may be empty — idempotency handled by controller)
     * @return the completed round response with status=COMPLETED and endedAt set
     * @throws vnpt.vsp.api.error.VspApiException with code ROUND_004 if round not found
     */
    RoundResponse completeRound(Long accountId, UUID roundId, RoundCompleteRequest request);

    /**
     * Returns the tournament policy for a round.
     *
     * @param roundId the round UUID
     * @param accountId the authenticated golfer's account ID (for ownership validation)
     * @return the tournament policy response
     * @throws vnpt.vsp.api.error.VspApiException with code ROUND_001 if round not found
     * @throws vnpt.vsp.api.error.VspApiException with code TOURNAMENT_001 if no policy attached
     */
    TournamentPolicyResponse getRoundTournamentPolicy(UUID roundId, Long accountId);
}
