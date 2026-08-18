package vnpt.vsp.module.round.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Request DTO for creating a new round.
 * Per Story 5.1 Slice D and round.yaml RoundCreate contract.
 *
 * Note: courseId uses Long to match Course entity ID type (backend convention).
 * The round.yaml contract uses UUID format for courseId in the external API;
 * conversion happens at the API boundary.
 */
public class RoundCreateRequest {

    @NotNull(message = "courseId is required")
    private Long courseId;

    /**
     * The đường played, in playing order, when the club has more than one.
     *
     * <p>Long Biên has đường A, B and C and a round there is a pairing the
     * golfer chooses on the day; the phone sends both ids here. Absent — which
     * is every request from a club with a single eighteen, and every request
     * from a client built before this field — the round has one segment, the
     * {@code courseId}.
     */
    private List<Long> segmentCourseIds;

    private Instant startTime;

    @Size(min = 1, max = 4, message = "playerIds must contain between 1 and 4 players")
    private List<Long> playerIds;

    private Long packageId;

    /**
     * CASUAL, PRACTICE or TOURNAMENT — what the golfer chose on the setup
     * screen. Absent from an older client, which means casual.
     */
    private String format;

    /**
     * Whether this round should feed the handicap the app computes.
     *
     * <p>Absent means "decide from the format": practice does not count,
     * anything else does. Sent explicitly when the golfer moved the switch.
     */
    private Boolean countsTowardHandicap;

    private Boolean cartRequested = false;

    /**
     * Tournament policy ID for tournament-format rounds.
     * Required when format is TOURNAMENT.
     */
    private UUID tournamentPolicyId;

    /**
     * Tournament ID — when provided, the round is linked to a tournament
     * and tournamentPolicyId is auto-populated from the tournament.
     * Per Story 12.1 Slice F.
     */
    private UUID tournamentId;

    /**
     * The id the client has already given this round, if it has one.
     *
     * <p>Optional, and older clients send nothing — they get a
     * server-generated id exactly as before. A phone that persists a round
     * locally before it can reach the network sends the id it is already
     * using, so that the round it finishes is the round it started. Without
     * it, everything the phone said afterwards was addressed to an id this
     * server had never issued.</p>
     *
     * <p>Sending the same id twice is not an error: the round that already
     * exists is returned. That is what a retry after a lost response looks
     * like, and it is the same promise the Idempotency-Key header makes for
     * callers that have one.</p>
     */
    private UUID clientRoundId;

    // ─── Getters and Setters ───────────────────────────────────────────────

    public UUID getClientRoundId() { return clientRoundId; }
    public void setClientRoundId(UUID clientRoundId) { this.clientRoundId = clientRoundId; }

    public Long getCourseId() {
        return courseId;
    }

    public List<Long> getSegmentCourseIds() {
        return segmentCourseIds;
    }

    public void setSegmentCourseIds(List<Long> segmentCourseIds) {
        this.segmentCourseIds = segmentCourseIds;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public Instant getStartTime() {
        return startTime;
    }

    public void setStartTime(Instant startTime) {
        this.startTime = startTime;
    }

    public List<Long> getPlayerIds() {
        return playerIds;
    }

    public void setPlayerIds(List<Long> playerIds) {
        this.playerIds = playerIds;
    }

    public Long getPackageId() {
        return packageId;
    }

    public void setPackageId(Long packageId) {
        this.packageId = packageId;
    }

    public Boolean getCartRequested() {
        return cartRequested;
    }

    public void setCartRequested(Boolean cartRequested) {
        this.cartRequested = cartRequested;
    }

    public String getFormat() { return format; }
    public void setFormat(String format) { this.format = format; }

    public Boolean getCountsTowardHandicap() { return countsTowardHandicap; }
    public void setCountsTowardHandicap(Boolean countsTowardHandicap) {
        this.countsTowardHandicap = countsTowardHandicap;
    }

    public UUID getTournamentPolicyId() { return tournamentPolicyId; }
    public void setTournamentPolicyId(UUID tournamentPolicyId) { this.tournamentPolicyId = tournamentPolicyId; }

    public UUID getTournamentId() { return tournamentId; }
    public void setTournamentId(UUID tournamentId) { this.tournamentId = tournamentId; }
}
