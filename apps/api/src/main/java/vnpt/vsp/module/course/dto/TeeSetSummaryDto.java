package vnpt.vsp.module.course.dto;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

/**
 * Tee set summary DTO for course detail view.
 * Per Story 3.3 CD-BACK-1: AC-1 tee sets section.
 * Yardages map is keyed by hole number (1-18+), value is yardage in meters.
 */
public class TeeSetSummaryDto {

    private Long id;
    private String name;
    private Integer totalPar;
    /** Hole number → yardage in meters, built from TeeBox entities per hole. */
    private Map<Integer, Integer> yardages;
    /** Course-level rating (null if unavailable). */
    private BigDecimal rating;
    /** Course-level slope (null if unavailable). */
    private Integer slope;
    private DataQualityDto dataQuality;

    public TeeSetSummaryDto() {
        this.yardages = new HashMap<>();
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Integer getTotalPar() {
        return totalPar;
    }

    public void setTotalPar(Integer totalPar) {
        this.totalPar = totalPar;
    }

    public Map<Integer, Integer> getYardages() {
        return yardages;
    }

    public void setYardages(Map<Integer, Integer> yardages) {
        this.yardages = yardages;
    }

    public BigDecimal getRating() {
        return rating;
    }

    public void setRating(BigDecimal rating) {
        this.rating = rating;
    }

    public Integer getSlope() {
        return slope;
    }

    public void setSlope(Integer slope) {
        this.slope = slope;
    }

    public DataQualityDto getDataQuality() {
        return dataQuality;
    }

    public void setDataQuality(DataQualityDto dataQuality) {
        this.dataQuality = dataQuality;
    }
}
