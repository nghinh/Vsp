package vnpt.vsp.module.shot;

import vnpt.vsp.module.shot.dto.*;
import java.util.UUID;

/**
 * Shot module public service interface.
 * Exposes shot CRUD and merge operations.
 * Per Story 10.3: Track Shots Manually.
 */
public interface ShotService {

    /**
     * Create (start) a new shot.
     *
     * <p>Idempotent: if the idempotencyKey already exists, returns the existing shot.
     *
     * @param accountId      authenticated golfer account ID
     * @param roundId        round UUID
     * @param idempotencyKey client-generated UUID v4
     * @param request        shot creation payload
     * @return shot response with server event ID and timestamp
     */
    ShotResponse createShot(Long accountId, UUID roundId, String idempotencyKey, CreateShotRequest request);

    /**
     * Get a single shot by ID.
     *
     * @param shotId     shot UUID
     * @param accountId  authenticated golfer account ID
     * @return shot DTO
     */
    ShotDto getShot(UUID shotId, Long accountId);

    /**
     * Update (edit) an existing shot.
     *
     * <p>Idempotent: if the idempotencyKey already exists, returns current shot state.
     *
     * @param shotId         shot UUID
     * @param accountId      authenticated golfer account ID
     * @param idempotencyKey client-generated UUID v4
     * @param request        partial update payload
     * @return updated shot response
     */
    ShotResponse updateShot(UUID shotId, Long accountId, String idempotencyKey, UpdateShotRequest request);

    /**
     * Soft-delete a shot.
     *
     * <p>Idempotent: if already deleted, returns current state.
     *
     * @param shotId         shot UUID
     * @param accountId      authenticated golfer account ID
     * @param idempotencyKey client-generated UUID v4
     */
    void deleteShot(UUID shotId, Long accountId, String idempotencyKey);

    /**
     * List shots for a round with optional sync cursor for delta sync.
     *
     * @param roundId   round UUID
     * @param accountId authenticated golfer account ID
     * @param cursor    optional sync cursor from previous response
     * @return list response with shots and next cursor
     */
    ShotListResponse listShots(UUID roundId, Long accountId, String cursor);

    /**
     * Merge two shots — source is marked as merged into target.
     *
     * <p>Both shots must belong to the same round and player.
     *
     * @param roundId        round UUID
     * @param accountId      authenticated golfer account ID
     * @param idempotencyKey client-generated UUID v4
     * @param request        merge request with source and target shot IDs
     * @return merged shot response
     */
    ShotResponse mergeShots(UUID roundId, Long accountId, String idempotencyKey, MergeShotsRequest request);

    /**
     * Record an automatic shot-detection candidate.
     *
     * <p>Per Story 10.4: Detect Shots with Confidence. The API applies the
     * confidence-threshold policy (see {@link ShotDetectionDisposition}) to the
     * candidate. Candidates below the discard threshold are dropped; all others
     * are persisted as {@code detected} shots and returned with their disposition.
     *
     * <p>Idempotent: re-submitting the same idempotencyKey returns the disposition
     * of the previously recorded detection.
     *
     * @param accountId      authenticated golfer account ID
     * @param roundId        round UUID
     * @param idempotencyKey client-generated UUID v4
     * @param request        detection candidate payload with confidence and signals
     * @return the disposition and, when persisted, the created detected shot
     */
    ShotDetectionResponse recordDetection(Long accountId, UUID roundId, String idempotencyKey, ShotDetectionRequest request);
}
