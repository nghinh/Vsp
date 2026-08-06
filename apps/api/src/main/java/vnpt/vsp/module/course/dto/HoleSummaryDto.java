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

    /**
     * Provenance of this hole's tee/green coordinates — and therefore of
     * {@code playingLengthMeters}, which is derived from them.
     *
     * <p>Sent per hole rather than per course because provenance is per hole:
     * a course can hold sixteen digitised holes and two the seed invented, and
     * a golfer reading a length off one of those two has to be told which kind
     * they are looking at.</p>
     */
    private DataQualityDto dataQuality;

    public HoleSummaryDto() {}

    public HoleSummaryDto(Integer holeNumber, Integer par, BigDecimal playingLengthMeters) {
        this.holeNumber = holeNumber;
        this.par = par;
        this.playingLengthMeters = playingLengthMeters;
    }

    public HoleSummaryDto(Integer holeNumber, Integer par, BigDecimal playingLengthMeters,
                          DataQualityDto dataQuality) {
        this(holeNumber, par, playingLengthMeters);
        this.dataQuality = dataQuality;
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

    public DataQualityDto getDataQuality() {
        return dataQuality;
    }

    public void setDataQuality(DataQualityDto dataQuality) {
        this.dataQuality = dataQuality;
    }
}
