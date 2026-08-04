package vnpt.vsp.module.course.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.math.BigDecimal;

/**
 * Request DTO for updating a hole (partial update).
 * Per Story 8.1 AC-2: all fields optional for PATCH semantics.
 */
public class HoleUpdateRequest {

    @Min(value = 1, message = "holeNumber must be between 1 and 9")
    @Max(value = 9, message = "holeNumber must be between 1 and 9")
    private Integer holeNumber;

    @Min(value = 3, message = "par must be at least 3")
    @Max(value = 7, message = "par must not exceed 7")
    private Integer par;

    /** WKT POINT string (SRID 4326) for teeing ground location */
    private String teeingGroundLocation;
    /** WKT POINT string (SRID 4326) for green center location */
    private String greenLocation;
    private BigDecimal playingLengthMeters;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public Integer getHoleNumber() { return holeNumber; }
    public void setHoleNumber(Integer holeNumber) { this.holeNumber = holeNumber; }

    public Integer getPar() { return par; }
    public void setPar(Integer par) { this.par = par; }

    public String getTeeingGroundLocation() { return teeingGroundLocation; }
    public void setTeeingGroundLocation(String teeingGroundLocation) { this.teeingGroundLocation = teeingGroundLocation; }

    public String getGreenLocation() { return greenLocation; }
    public void setGreenLocation(String greenLocation) { this.greenLocation = greenLocation; }

    public BigDecimal getPlayingLengthMeters() { return playingLengthMeters; }
    public void setPlayingLengthMeters(BigDecimal playingLengthMeters) { this.playingLengthMeters = playingLengthMeters; }
}
