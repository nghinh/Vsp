package vnpt.vsp.module.tournament.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Response DTO for leaderboard.
 */
public class LeaderboardResponse {

    private UUID tournamentId;
    private long version;
    private Instant updatedAt;
    private List<LeaderboardEntryResponse> entries;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getTournamentId() { return tournamentId; }
    public void setTournamentId(UUID tournamentId) { this.tournamentId = tournamentId; }

    public long getVersion() { return version; }
    public void setVersion(long version) { this.version = version; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public List<LeaderboardEntryResponse> getEntries() { return entries; }
    public void setEntries(List<LeaderboardEntryResponse> entries) { this.entries = entries; }
}
