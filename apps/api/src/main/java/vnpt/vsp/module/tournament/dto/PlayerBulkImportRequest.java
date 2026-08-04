package vnpt.vsp.module.tournament.dto;

import jakarta.validation.constraints.NotNull;
import vnpt.vsp.module.tournament.entity.TournamentPlayerStatus;

import java.util.List;
import java.util.Map;

/**
 * Request DTO for bulk player import.
 */
public class PlayerBulkImportRequest {

    @NotNull(message = "Players list is required")
    private List<Map<String, Object>> players;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public List<Map<String, Object>> getPlayers() { return players; }
    public void setPlayers(List<Map<String, Object>> players) { this.players = players; }
}
