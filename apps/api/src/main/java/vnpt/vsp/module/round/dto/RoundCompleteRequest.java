package vnpt.vsp.module.round.dto;

/**
 * Request DTO for completing a round.
 * Per Story 5.5 Slice 1: idempotent round completion via POST /rounds/{id}/complete.
 */
public class RoundCompleteRequest {
    // Empty body — the roundId in path is sufficient.
    // Idempotency key provided via Idempotency-Key header.
}
