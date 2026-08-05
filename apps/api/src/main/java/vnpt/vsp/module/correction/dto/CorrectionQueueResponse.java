package vnpt.vsp.module.correction.dto;

import vnpt.vsp.module.correction.entity.CourseCorrection;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

/**
 * Response DTO for the correction queue list endpoint.
 * Per Story 9.2 AC-1 and Slice Plan §Slice A.
 */
public class CorrectionQueueResponse {

    private List<CorrectionSummary> corrections;
    private long total;
    private int page;
    private int pageSize;
    private int totalPages;

    public CorrectionQueueResponse(List<CorrectionSummary> corrections, long total, int page, int pageSize) {
        this.corrections = corrections;
        this.total = total;
        this.page = page;
        this.pageSize = pageSize;
        this.totalPages = pageSize > 0 ? (int) Math.ceil((double) total / pageSize) : 0;
    }

    // ─── Summary view ──────────────────────────────────────────────────────────

    public static class CorrectionSummary {
        private Long id;
        private Long courseId;
        private String courseName;
        private Integer holeNumber;
        private String correctionType;
        private String status;
        private BigDecimal confidence;
        private Instant submittedAt;
        private Long reporterId;

        /** Geometry layer for a golfer-reported layer correction; null otherwise. */
        private String geometryLayer;

        /** Independent reports corroborating this one — cluster size. */
        private Integer corroborationCount;

        /**
         * UNVERIFIED until enough reports corroborate, then PENDING_REVIEW.
         * This is what tells a reviewer the queue row is worth opening.
         */
        private String verificationStatus;

        public static CorrectionSummary fromEntity(CourseCorrection c, String courseName) {
            CorrectionSummary s = new CorrectionSummary();
            s.setId(c.getId());
            s.setCourseId(c.getCourseId());
            s.setCourseName(courseName);
            s.setHoleNumber(c.getHoleId() != null ? c.getHoleId().intValue() : null);
            s.setCorrectionType(c.getCorrectionType().name());
            s.setStatus(c.getStatus().name());
            s.setConfidence(c.getConfidence());
            s.setSubmittedAt(c.getSubmittedAt());
            s.setReporterId(c.getReporterId());
            s.setGeometryLayer(c.getGeometryLayer() != null ? c.getGeometryLayer().getWireValue() : null);
            s.setCorroborationCount(c.getCorroborationCount());
            s.setVerificationStatus(c.getMetadata().getVerificationStatus() != null
                    ? c.getMetadata().getVerificationStatus().name() : null);
            return s;
        }

        // ─── Getters and Setters ───────────────────────────────────────────────

        public String getGeometryLayer() { return geometryLayer; }
        public void setGeometryLayer(String geometryLayer) { this.geometryLayer = geometryLayer; }

        public Integer getCorroborationCount() { return corroborationCount; }
        public void setCorroborationCount(Integer corroborationCount) { this.corroborationCount = corroborationCount; }

        public String getVerificationStatus() { return verificationStatus; }
        public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }

        public Long getCourseId() { return courseId; }
        public void setCourseId(Long courseId) { this.courseId = courseId; }

        public String getCourseName() { return courseName; }
        public void setCourseName(String courseName) { this.courseName = courseName; }

        public Integer getHoleNumber() { return holeNumber; }
        public void setHoleNumber(Integer holeNumber) { this.holeNumber = holeNumber; }

        public String getCorrectionType() { return correctionType; }
        public void setCorrectionType(String correctionType) { this.correctionType = correctionType; }

        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }

        public BigDecimal getConfidence() { return confidence; }
        public void setConfidence(BigDecimal confidence) { this.confidence = confidence; }

        public Instant getSubmittedAt() { return submittedAt; }
        public void setSubmittedAt(Instant submittedAt) { this.submittedAt = submittedAt; }

        public Long getReporterId() { return reporterId; }
        public void setReporterId(Long reporterId) { this.reporterId = reporterId; }
    }

    // ─── Getters and Setters ───────────────────────────────────────────────────

    public List<CorrectionSummary> getCorrections() { return corrections; }
    public void setCorrections(List<CorrectionSummary> corrections) { this.corrections = corrections; }

    public long getTotal() { return total; }
    public void setTotal(long total) { this.total = total; }

    public int getPage() { return page; }
    public void setPage(int page) { this.page = page; }

    public int getPageSize() { return pageSize; }
    public void setPageSize(int pageSize) { this.pageSize = pageSize; }

    public int getTotalPages() { return totalPages; }
    public void setTotalPages(int totalPages) { this.totalPages = totalPages; }
}
