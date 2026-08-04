package vnpt.vsp.module.correction.dto;

import jakarta.validation.constraints.NotNull;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CorrectionType;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Request DTO for the correction queue list endpoint.
 * Supports filtering by course, hole, type, status, confidence range, and date range.
 *
 * <p>All filter fields are optional.  When a field is null it is not applied
 * to the query.  The service layer assembles the dynamic query using
 * {@link vnpt.vsp.module.correction.repository.CourseCorrectionRepository}
 * derived query methods.</p>
 *
 * Per Story 9.2 AC-1 and Slice Plan §Slice A.
 */
public class CorrectionQueueRequest {

    private Long courseId;
    private Integer holeNumber;
    private CorrectionType type;
    private CorrectionStatus status;
    private BigDecimal confidenceMin;
    private BigDecimal confidenceMax;
    private Instant fromDate;
    private Instant toDate;

    @jakarta.validation.constraints.Min(0)
    private int page = 0;

    @jakarta.validation.constraints.Min(1)
    private int pageSize = 20;

    // ─── Getters and Setters ───────────────────────────────────────────────────

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Integer getHoleNumber() { return holeNumber; }
    public void setHoleNumber(Integer holeNumber) { this.holeNumber = holeNumber; }

    public CorrectionType getType() { return type; }
    public void setType(CorrectionType type) { this.type = type; }

    public CorrectionStatus getStatus() { return status; }
    public void setStatus(CorrectionStatus status) { this.status = status; }

    public BigDecimal getConfidenceMin() { return confidenceMin; }
    public void setConfidenceMin(BigDecimal confidenceMin) { this.confidenceMin = confidenceMin; }

    public BigDecimal getConfidenceMax() { return confidenceMax; }
    public void setConfidenceMax(BigDecimal confidenceMax) { this.confidenceMax = confidenceMax; }

    public Instant getFromDate() { return fromDate; }
    public void setFromDate(Instant fromDate) { this.fromDate = fromDate; }

    public Instant getToDate() { return toDate; }
    public void setToDate(Instant toDate) { this.toDate = toDate; }

    public int getPage() { return page; }
    public void setPage(int page) { this.page = page; }

    public int getPageSize() { return pageSize; }
    public void setPageSize(int pageSize) { this.pageSize = pageSize; }
}
