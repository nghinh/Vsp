package vnpt.vsp.module.operations.dto;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * DTO for PinPosition entities returned by OperationsService.
 * Per Story 8.5 AC-1: place/schedule pins with effective + expiration times.
 */
public class PinPositionDto {

    private Long id;
    private Long courseId;
    private Integer holeNumber;
    private String position; // WKT geometry (GeoJSON Point)
    private String pinPositionType;
    private Instant effectiveFrom;
    private Instant expiresAt;
    private String publishedBy;
    private BigDecimal confidence;
    private DataQualityDto dataQuality;

    public PinPositionDto() {}

    public PinPositionDto(Long id, Long courseId, Integer holeNumber, String position,
                          String pinPositionType, Instant effectiveFrom, Instant expiresAt,
                          String publishedBy, BigDecimal confidence, DataQualityDto dataQuality) {
        this.id = id;
        this.courseId = courseId;
        this.holeNumber = holeNumber;
        this.position = position;
        this.pinPositionType = pinPositionType;
        this.effectiveFrom = effectiveFrom;
        this.expiresAt = expiresAt;
        this.publishedBy = publishedBy;
        this.confidence = confidence;
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

    public String getPosition() {
        return position;
    }

    public void setPosition(String position) {
        this.position = position;
    }

    public String getPinPositionType() {
        return pinPositionType;
    }

    public void setPinPositionType(String pinPositionType) {
        this.pinPositionType = pinPositionType;
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

    public BigDecimal getConfidence() {
        return confidence;
    }

    public void setConfidence(BigDecimal confidence) {
        this.confidence = confidence;
    }

    public DataQualityDto getDataQuality() {
        return dataQuality;
    }

    public void setDataQuality(DataQualityDto dataQuality) {
        this.dataQuality = dataQuality;
    }
}
