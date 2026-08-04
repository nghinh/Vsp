package vnpt.vsp.module.score.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * Request DTO for submitting score corrections on a completed round.
 * Per Story 5.5 Slice 4: validates permitted fields, round ownership, round completion.
 */
public class ScoreCorrectionRequest {

    @NotNull(message = "playerId is required")
    private Long playerId;

    @NotEmpty(message = "corrections list cannot be empty")
    @Valid
    private List<FieldCorrection> corrections;

    public ScoreCorrectionRequest() {}

    public Long getPlayerId() { return playerId; }
    public void setPlayerId(Long playerId) { this.playerId = playerId; }
    public List<FieldCorrection> getCorrections() { return corrections; }
    public void setCorrections(List<FieldCorrection> corrections) { this.corrections = corrections; }
}
