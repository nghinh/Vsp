package vnpt.vsp.module.dataquality.dto;

/**
 * Stale record entry returned by GET /admin/data-quality/stale.
 * Per Story 9.4 AC3 and Slice Plan Wave 1.
 */
public class StaleRecordDto {

    /** Type of stale record: PIN, GREEN_SPEED, COURSE_CONDITION. */
    private String recordType;

    /** Unique ID of the stale record. */
    private Long recordId;

    /** Facility ID this record belongs to. */
    private Long facilityId;

    /** Facility name. */
    private String facilityName;

    /** Course ID this record belongs to (null for PIN/GREEN_SPEED at hole level). */
    private Long courseId;

    /** Course name. */
    private String courseName;

    /** Hole number (null for course-level records). */
    private Integer holeNumber;

    /** When this record expired (ISO-8601 instant). */
    private String expiredAt;

    /** Severity: LOW, MODERATE, HIGH, CRITICAL. */
    private String severity;

    public StaleRecordDto() {}

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getRecordType() {
        return recordType;
    }

    public void setRecordType(String recordType) {
        this.recordType = recordType;
    }

    public Long getRecordId() {
        return recordId;
    }

    public void setRecordId(Long recordId) {
        this.recordId = recordId;
    }

    public Long getFacilityId() {
        return facilityId;
    }

    public void setFacilityId(Long facilityId) {
        this.facilityId = facilityId;
    }

    public String getFacilityName() {
        return facilityName;
    }

    public void setFacilityName(String facilityName) {
        this.facilityName = facilityName;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public String getCourseName() {
        return courseName;
    }

    public void setCourseName(String courseName) {
        this.courseName = courseName;
    }

    public Integer getHoleNumber() {
        return holeNumber;
    }

    public void setHoleNumber(Integer holeNumber) {
        this.holeNumber = holeNumber;
    }

    public String getExpiredAt() {
        return expiredAt;
    }

    public void setExpiredAt(String expiredAt) {
        this.expiredAt = expiredAt;
    }

    public String getSeverity() {
        return severity;
    }

    public void setSeverity(String severity) {
        this.severity = severity;
    }
}
