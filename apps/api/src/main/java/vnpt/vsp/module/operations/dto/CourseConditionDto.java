package vnpt.vsp.module.operations.dto;

import java.time.Instant;

/**
 * DTO for CourseCondition entities returned by OperationsService.
 * Per Story 8.5 AC-2: course status, maintenance, and alert management.
 */
public class CourseConditionDto {

    private Long id;
    private Long courseId;
    private String conditionType;  // GREEN_SPEED, GREEN_FIRMNESS, FAIRWAY_FIRMNESS, etc.
    private String severity;       // LOW, MODERATE, HIGH, CRITICAL
    private String description;
    private Instant effectiveFrom;
    private Instant expiresAt;
    private String publishedBy;
    private DataQualityDto dataQuality;

    public CourseConditionDto() {}

    public CourseConditionDto(Long id, Long courseId, String conditionType, String severity,
                            String description, Instant effectiveFrom, Instant expiresAt,
                            String publishedBy, DataQualityDto dataQuality) {
        this.id = id;
        this.courseId = courseId;
        this.conditionType = conditionType;
        this.severity = severity;
        this.description = description;
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

    public String getConditionType() {
        return conditionType;
    }

    public void setConditionType(String conditionType) {
        this.conditionType = conditionType;
    }

    public String getSeverity() {
        return severity;
    }

    public void setSeverity(String severity) {
        this.severity = severity;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
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
