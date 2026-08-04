package vnpt.vsp.module.shot;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.idempotency.Idempotent;
import vnpt.vsp.module.shot.dto.*;

import java.util.UUID;

/**
 * REST controller for shot endpoints.
 *
 * <p>Per Story 10.3: Track Shots Manually.
 * All write endpoints require {@code Idempotency-Key} header for safe retry semantics.
 * The {@link Idempotent} annotation triggers the {@code IdempotencyFilter} to deduplicate
 * repeated submissions within the TTL window (24 hours).
 */
@RestController
@RequestMapping
@vnpt.vsp.module.shot.ShotModule
public class ShotController {

    private static final Logger log = LoggerFactory.getLogger(ShotController.class);

    private final ShotService shotService;

    public ShotController(ShotService shotService) {
        this.shotService = shotService;
    }

    // ─── Create shot ───────────────────────────────────────────────────────────

    /**
     * Start a new shot.
     *
     * <p>Idempotent: if the {@code Idempotency-Key} was already processed,
     * returns the existing shot with {@code X-Idempotent-Replay: true}.
     */
    @PostMapping("/rounds/{roundId}/shots")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<ShotResponse> createShot(
            Authentication authentication,
            @PathVariable UUID roundId,
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @Valid @RequestBody CreateShotRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("POST /rounds/{}/shots – accountId={}, idempotencyKey={}, hole={}, shot={}",
                roundId, accountId, idempotencyKey, request.holeNumber(), request.shotNumber());

        ShotResponse response = shotService.createShot(accountId, roundId, idempotencyKey, request);
        return ResponseEntity.status(201).body(response);
    }

    // ─── Get shot ──────────────────────────────────────────────────────────────

    /**
     * Get a single shot by ID.
     */
    @GetMapping("/shots/{shotId}")
    public ResponseEntity<ShotDto> getShot(
            Authentication authentication,
            @PathVariable UUID shotId) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("GET /shots/{} – accountId={}", shotId, accountId);

        ShotDto shot = shotService.getShot(shotId, accountId);
        return ResponseEntity.ok(shot);
    }

    // ─── Update shot ───────────────────────────────────────────────────────────

    /**
     * Edit an existing shot.
     *
     * <p>Partial update — only non-null fields in the request body are applied.
     * Idempotent: re-submitting the same idempotencyKey returns current shot state.
     */
    @PatchMapping("/shots/{shotId}")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<ShotResponse> updateShot(
            Authentication authentication,
            @PathVariable UUID shotId,
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @RequestBody UpdateShotRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("PATCH /shots/{} – accountId={}, idempotencyKey={}", shotId, accountId, idempotencyKey);

        ShotResponse response = shotService.updateShot(shotId, accountId, idempotencyKey, request);
        return ResponseEntity.ok(response);
    }

    // ─── Delete shot ───────────────────────────────────────────────────────────

    /**
     * Soft-delete a shot.
     *
     * <p>Idempotent: if already deleted, returns 200 without error.
     */
    @DeleteMapping("/shots/{shotId}")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<Void> deleteShot(
            Authentication authentication,
            @PathVariable UUID shotId,
            @RequestHeader("Idempotency-Key") String idempotencyKey) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("DELETE /shots/{} – accountId={}, idempotencyKey={}", shotId, accountId, idempotencyKey);

        shotService.deleteShot(shotId, accountId, idempotencyKey);
        return ResponseEntity.ok().build();
    }

    // ─── List shots ───────────────────────────────────────────────────────────

    /**
     * List all shots for a round with optional sync cursor for delta sync.
     */
    @GetMapping("/rounds/{roundId}/shots")
    public ResponseEntity<ShotListResponse> listShots(
            Authentication authentication,
            @PathVariable UUID roundId,
            @RequestParam(required = false) String cursor) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("GET /rounds/{}/shots – accountId={}, cursor={}", roundId, accountId, cursor);

        ShotListResponse response = shotService.listShots(roundId, accountId, cursor);
        return ResponseEntity.ok(response);
    }

    // ─── Merge shots ───────────────────────────────────────────────────────────

    /**
     * Merge two shots — source shot is marked as merged into target.
     *
     * <p>Both shots must belong to the same round and player.
     * Idempotent: if already merged, returns current state.
     */
    @PostMapping("/rounds/{roundId}/shots/merge")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<ShotResponse> mergeShots(
            Authentication authentication,
            @PathVariable UUID roundId,
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @Valid @RequestBody MergeShotsRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("POST /rounds/{}/shots/merge – accountId={}, idempotencyKey={}, source={}, target={}",
                roundId, accountId, idempotencyKey, request.sourceShotId(), request.targetShotId());

        ShotResponse response = shotService.mergeShots(roundId, accountId, idempotencyKey, request);
        return ResponseEntity.ok(response);
    }
}
