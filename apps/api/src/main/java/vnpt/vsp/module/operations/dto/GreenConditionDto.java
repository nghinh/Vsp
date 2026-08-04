package vnpt.vsp.module.operations.dto;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * DTO for GreenCondition entities returned by OperationsService.
 * Per Story 8.5 AC-2: green speed (stimpmeter), firmness, moisture management.
 */
public class GreenConditionDto {

    private Long id;
    private Long courseId;
    private Integer holeNumber;
    private BigDecimal stimpmeterReading;
    private String firmness;  // SOFT, MEDIUM, FIRM, HARD
    private String moisture;  // DRY, NORMAL, WET, SATURATED
    private Instant effectiveFrom;
    private Instant expiresAt;
    private String publishedBy;
    private DataQualityDto dataQuality;

    public GreenConditionDto() {}

    public GreenConditionDto(Long id, Long courseId, Integer holeNumber,
                            BigDecimal stimpmeterReading, String firmness, String moisture,
                            Instant effectiveFrom, Instant expiresAt, String publishedBy,
                            DataQualityDto dataQuality) {
        this.id = id;
        this.courseId = courseId;
        this.holeNumber = holeNumber;
        this.stimpmeterReading = stimpmeterReading;
        this.firmness = firmness;
        this.moisture = moisture;
        this.effectiveFrom = effectiveFrom;
        this.expiresAt = expiresAt;
        this.publishedBy = publishedBy;
        this.dataQuality = dataQuality;
    }

    // Getters and Setters

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public Integer getHoleNumber() {
        return holeNumber;
    }

    public void setHoleNumber(Integer holeNumber) {
        this.holeNumber = holeNumber;
    }

    public BigDecimal getStimpmeterReading() {
        return stimpmeterReading;
    }

    public void setStimpmeterReading(BigDecimal stimpmeterReading) {
        this.stimpmeterReading = stimpmeterReading;
    }

    public String getFirmness() {
        return firmness;
    }

    public void setFirmness(String firmness) {
        this.firmness = firmness;
    }

    public String getMoisture() {
        return moisture;
    }

    public void setMoisture(String moisture) {
        this.moisture = moisture;
    }

    public Instant getEffectiveFrom() {
        return effectiveFrom;
    }

    public void setEffectiveFrom(Instant effectiveFrom) {
        this.effectiveFrom = effectiveFrom;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public String getPublishedBy() {
        return publishedBy;
    }

    public void setPublishedBy(String publishedBy) {
        this.publishedBy = publishedBy;
    }

    public DataQualityDto getDataQuality() {
        return dataQuality;
    }

    public void setDataQuality(DataQualityDto dataQuality) {
        this.dataQuality = dataQuality;
    }
}
