package vnpt.vsp.module.score.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for sync confirmation on score and round endpoints.
 *
 * <p>Returned by idempotent sync endpoints so the client can confirm
 * whether an event was newly processed ({@code status = SYNCED}) or
 * replayed from cache ({@code X-Idempotent-Replay: true} header).
 *
 * <p>Per Story 5.4 AC2: server deduplicates repeated submissions.
 * Per architecture §8.3: idempotent APIs with sync confirmation response.
 *
 * @param eventId  the idempotency key supplied by the client (UUID)
 * @param status   outcome: SYNCED (new or first replay) or FAILED (permanent error)
 * @param syncedAt server timestamp when the event was committed; null on failure
 * @param error    human-readable error message when status is FAILED; null otherwise
 */
public class SyncStatusResponse {

    public enum Status {
        SYNCED,
        FAILED
    }

    private UUID eventId;
    private Status status;
    private Instant syncedAt;
    private String error;

    public SyncStatusResponse() {}

    public SyncStatusResponse(UUID eventId, Status status, Instant syncedAt, String error) {
        this.eventId = eventId;
        this.status = status;
        this.syncedAt = syncedAt;
        this.error = error;
    }

    /** Convenience factory for a successful sync. */
    public static SyncStatusResponse synced(UUID eventId) {
        return new SyncStatusResponse(eventId, Status.SYNCED, Instant.now(), null);
    }

    /** Convenience factory for a permanent failure. */
    public static SyncStatusResponse failed(UUID eventId, String error) {
        return new SyncStatusResponse(eventId, Status.FAILED, null, error);
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

    public UUID getEventId() {
        return eventId;
    }

    public void setEventId(UUID eventId) {
        this.eventId = eventId;
    }

    public Status getStatus() {
        return status;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public Instant getSyncedAt() {
        return syncedAt;
    }

    public void setSyncedAt(Instant syncedAt) {
        this.syncedAt = syncedAt;
    }

    public String getError() {
        return error;
    }

    public void setError(String error) {
        this.error = error;
    }
}
