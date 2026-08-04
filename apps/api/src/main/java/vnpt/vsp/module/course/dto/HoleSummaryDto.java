package vnpt.vsp.module.course.dto;

import java.math.BigDecimal;

/**
 * Hole summary DTO for course detail view.
 * Per Story 3.3 CD-BACK-1: AC-1 hole list section.
 */
public class HoleSummaryDto {

    private Integer holeNumber;
    private Integer par;
    private BigDecimal playingLengthMeters;

    public HoleSummaryDto() {}

    public HoleSummaryDto(Integer holeNumber, Integer par, BigDecimal playingLengthMeters) {
        this.holeNumber = holeNumber;
        this.par = par;
        this.playingLengthMeters = playingLengthMeters;
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Integer getHoleNumber() {
        return holeNumber;
    }

    public void setHoleNumber(Integer holeNumber) {
        this.holeNumber = holeNumber;
    }

    public Integer getPar() {
        return par;
    }

    public void setPar(Integer par) {
        this.par = par;
    }

    public BigDecimal getPlayingLengthMeters() {
        return playingLengthMeters;
    }

    public void setPlayingLengthMeters(BigDecimal playingLengthMeters) {
        this.playingLengthMeters = playingLengthMeters;
    }
}
