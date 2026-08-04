package vnpt.vsp.module.dataquality.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

/**
 * Query parameters for GET /admin/data-quality/metrics and /export.
 * Per Story 9.4 AC1-AC2 and Slice Plan Wave 1.
 */
public class DataQualityQueryRequest {

    /** Filter by facility (optional). */
    private Long facilityId;

    /** Filter by course (optional). */
    private Long courseId;

    /** Start of date range for correction metrics (inclusive). */
    @NotNull(message = "fromDate is required")
    private LocalDate fromDate;

    /** End of date range for correction metrics (inclusive). */
    @NotNull(message = "toDate is required")
    private LocalDate toDate;

    public DataQualityQueryRequest() {}

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getFacilityId() {
        return facilityId;
    }

    public void setFacilityId(Long facilityId) {
        this.facilityId = facilityId;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public LocalDate getFromDate() {
        return fromDate;
    }

    public void setFromDate(LocalDate fromDate) {
        this.fromDate = fromDate;
    }

    public LocalDate getToDate() {
        return toDate;
    }

    public void setToDate(LocalDate toDate) {
        this.toDate = toDate;
    }
}
