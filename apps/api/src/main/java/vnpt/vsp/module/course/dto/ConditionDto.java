package vnpt.vsp.module.course.dto;

import java.time.LocalDate;

/**
 * Condition DTO for course detail view.
 * Per Story 3.3 CD-BACK-1: AC-1 current conditions section.
 */
public class ConditionDto {

    private String conditionType;
    private String severity;
    private String description;
    private LocalDate effectiveDate;
    private DataQualityDto dataQuality;

    public ConditionDto() {}

    // ─── Getters and Setters ────────────────────────────────────────────────

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

    public LocalDate getEffectiveDate() {
        return effectiveDate;
    }

    public void setEffectiveDate(LocalDate effectiveDate) {
        this.effectiveDate = effectiveDate;
    }

    public DataQualityDto getDataQuality() {
        return dataQuality;
    }

    public void setDataQuality(DataQualityDto dataQuality) {
        this.dataQuality = dataQuality;
    }
}
