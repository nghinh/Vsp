package vnpt.vsp.module.correction.dto;

import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CorrectionType;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Response DTO for a single correction detail view.
 * Includes reporter evidence, location, map context, and official data comparison fields.
 *
 * <p>Per Story 9.2 AC-2: Review displays reporter evidence, location, map context,
 * and existing official data.</p>
 *
 * Per Slice Plan §Slice A.
 */
public class CorrectionDetailResponse {

    // ─── Core identification ───────────────────────────────────────────────────

    private Long id;
    private Long courseId;
    private String courseName;
    private Long holeId;
    private Integer holeNumber;
    private Long reporterId;

    // ─── Reporter evidence (AC-2) ─────────────────────────────────────────────

    private String reporterNote;
    private String reporterEvidenceUrl;

    // ─── Location (AC-2) ────────────────────────────────────────────────────

    /** Reporter's GPS location as SRID 4326 WKT (e.g. "POINT(106.7205 10.8506)") */
    private String reporterGpsLocation;

    // ─── Classification ─────────────────────────────────────────────────────

    private String correctionType;
    private String status;
    private BigDecimal confidence;

    /** Geometry layer for a golfer-reported layer correction; null otherwise. */
    private String geometryLayer;

    /** Reporter's horizontal GPS accuracy in metres at submission time. */
    private Double gpsAccuracyMeters;

    /** Independent reports corroborating this one — cluster size. */
    private Integer corroborationCount;

    // ─── Submission ─────────────────────────────────────────────────────────

    private Instant submittedAt;

    // ─── Review fields ──────────────────────────────────────────────────────

    private Instant reviewedAt;
    private Long reviewedBy;
    private String reviewNote;
    private String resolution;

    // ─── Data quality metadata ───────────────────────────────────────────────

    private String source;
    private String license;
    private String accuracyClass;
    private BigDecimal dataConfidence;
    private String verificationStatus;
    private Instant createdAt;
    private Instant updatedAt;
    private Integer version;

    // ─── Factory method ───────────────────────────────────────────────────────

    public static CorrectionDetailResponse fromEntity(CourseCorrection c, String courseName, Integer holeNumber) {
        CorrectionDetailResponse r = new CorrectionDetailResponse();
        r.setId(c.getId());
        r.setCourseId(c.getCourseId());
        r.setCourseName(courseName);
        r.setHoleId(c.getHoleId());
        r.setHoleNumber(holeNumber);
        r.setReporterId(c.getReporterId());
        r.setReporterNote(c.getReporterNote());
        r.setReporterEvidenceUrl(c.getReporterEvidenceUrl());
        r.setReporterGpsLocation(c.getReporterGpsLocation());
        r.setCorrectionType(c.getCorrectionType().name());
        r.setStatus(c.getStatus().name());
        r.setConfidence(c.getConfidence());
        r.setGeometryLayer(c.getGeometryLayer() != null ? c.getGeometryLayer().getWireValue() : null);
        r.setGpsAccuracyMeters(c.getGpsAccuracyMeters());
        r.setCorroborationCount(c.getCorroborationCount());
        r.setSubmittedAt(c.getSubmittedAt());
        r.setReviewedAt(c.getReviewedAt());
        r.setReviewedBy(c.getReviewedBy());
        r.setReviewNote(c.getReviewNote());
        r.setResolution(c.getResolution());
        r.setSource(c.getMetadata().getSource());
        r.setLicense(c.getMetadata().getLicense());
        r.setAccuracyClass(c.getMetadata().getAccuracyClass() != null
                ? c.getMetadata().getAccuracyClass().name() : null);
        r.setDataConfidence(c.getMetadata().getConfidence());
        r.setVerificationStatus(c.getMetadata().getVerificationStatus() != null
                ? c.getMetadata().getVerificationStatus().name() : null);
        r.setCreatedAt(c.getMetadata().getCreatedAt());
        r.setUpdatedAt(c.getMetadata().getUpdatedAt());
        r.setVersion(c.getMetadata().getVersion());
        return r;
    }

    // ─── Getters and Setters ─────────────────────────────────────────────────

    public String getGeometryLayer() { return geometryLayer; }
    public void setGeometryLayer(String geometryLayer) { this.geometryLayer = geometryLayer; }

    public Double getGpsAccuracyMeters() { return gpsAccuracyMeters; }
    public void setGpsAccuracyMeters(Double gpsAccuracyMeters) { this.gpsAccuracyMeters = gpsAccuracyMeters; }

    public Integer getCorroborationCount() { return corroborationCount; }
    public void setCorroborationCount(Integer corroborationCount) { this.corroborationCount = corroborationCount; }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public String getCourseName() { return courseName; }
    public void setCourseName(String courseName) { this.courseName = courseName; }

    public Long getHoleId() { return holeId; }
    public void setHoleId(Long holeId) { this.holeId = holeId; }

    public Integer getHoleNumber() { return holeNumber; }
    public void setHoleNumber(Integer holeNumber) { this.holeNumber = holeNumber; }

    public Long getReporterId() { return reporterId; }
    public void setReporterId(Long reporterId) { this.reporterId = reporterId; }

    public String getReporterNote() { return reporterNote; }
    public void setReporterNote(String reporterNote) { this.reporterNote = reporterNote; }

    public String getReporterEvidenceUrl() { return reporterEvidenceUrl; }
    public void setReporterEvidenceUrl(String reporterEvidenceUrl) { this.reporterEvidenceUrl = reporterEvidenceUrl; }

    public String getReporterGpsLocation() { return reporterGpsLocation; }
    public void setReporterGpsLocation(String reporterGpsLocation) { this.reporterGpsLocation = reporterGpsLocation; }

    public String getCorrectionType() { return correctionType; }
    public void setCorrectionType(String correctionType) { this.correctionType = correctionType; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public BigDecimal getConfidence() { return confidence; }
    public void setConfidence(BigDecimal confidence) { this.confidence = confidence; }

    public Instant getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(Instant submittedAt) { this.submittedAt = submittedAt; }

    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; }

    public Long getReviewedBy() { return reviewedBy; }
    public void setReviewedBy(Long reviewedBy) { this.reviewedBy = reviewedBy; }

    public String getReviewNote() { return reviewNote; }
    public void setReviewNote(String reviewNote) { this.reviewNote = reviewNote; }

    public String getResolution() { return resolution; }
    public void setResolution(String resolution) { this.resolution = resolution; }

    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }

    public String getLicense() { return license; }
    public void setLicense(String license) { this.license = license; }

    public String getAccuracyClass() { return accuracyClass; }
    public void setAccuracyClass(String accuracyClass) { this.accuracyClass = accuracyClass; }

    public BigDecimal getDataConfidence() { return dataConfidence; }
    public void setDataConfidence(BigDecimal dataConfidence) { this.dataConfidence = dataConfidence; }

    public String getVerificationStatus() { return verificationStatus; }
    public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public Integer getVersion() { return version; }
    public void setVersion(Integer version) { this.version = version; }
}
