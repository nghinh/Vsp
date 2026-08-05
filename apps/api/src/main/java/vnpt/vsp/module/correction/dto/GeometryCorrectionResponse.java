package vnpt.vsp.module.correction.dto;

import vnpt.vsp.module.correction.entity.CourseCorrection;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Acknowledgement for a submitted geometry correction.
 *
 * <p>Carries the corroboration outcome so the app can tell the golfer whether
 * their report stands alone or has just tipped a cluster into the review queue,
 * and echoes the provenance stamped on the stored row.</p>
 */
public class GeometryCorrectionResponse {

    private Long id;
    private Long courseId;
    private Long holeId;
    private String layer;
    private String correctionType;
    private String status;
    private String verificationStatus;
    private String accuracyClass;
    private BigDecimal confidence;
    private Instant submittedAt;

    /** Reports (including this one) that corroborate the same shape. */
    private int corroborationCount;

    /** True when this submission pushed the cluster to PENDING_REVIEW. */
    private boolean promotedForReview;

    /** The stored shape, echoed back as WKT. */
    private String proposedGeometryWkt;

    // ─── Provenance ───────────────────────────────────────────────────────────

    private String source;
    private String publisher;
    private String license;

    public static GeometryCorrectionResponse fromEntity(CourseCorrection c,
                                                        String proposedGeometryWkt,
                                                        int corroborationCount,
                                                        boolean promotedForReview,
                                                        String verificationStatus) {
        GeometryCorrectionResponse r = new GeometryCorrectionResponse();
        r.id = c.getId();
        r.courseId = c.getCourseId();
        r.holeId = c.getHoleId();
        r.layer = c.getGeometryLayer() != null ? c.getGeometryLayer().getWireValue() : null;
        r.correctionType = c.getCorrectionType() != null ? c.getCorrectionType().name() : null;
        r.status = c.getStatus() != null ? c.getStatus().name() : null;
        r.verificationStatus = verificationStatus;
        r.accuracyClass = c.getMetadata().getAccuracyClass() != null
                ? c.getMetadata().getAccuracyClass().name() : null;
        r.confidence = c.getConfidence();
        r.submittedAt = c.getSubmittedAt();
        r.corroborationCount = corroborationCount;
        r.promotedForReview = promotedForReview;
        r.proposedGeometryWkt = proposedGeometryWkt;
        r.source = c.getMetadata().getSource();
        r.publisher = c.getMetadata().getPublisher();
        r.license = c.getMetadata().getLicense();
        return r;
    }

    // ─── Getters and Setters ──────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Long getHoleId() { return holeId; }
    public void setHoleId(Long holeId) { this.holeId = holeId; }

    public String getLayer() { return layer; }
    public void setLayer(String layer) { this.layer = layer; }

    public String getCorrectionType() { return correctionType; }
    public void setCorrectionType(String correctionType) { this.correctionType = correctionType; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getVerificationStatus() { return verificationStatus; }
    public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }

    public String getAccuracyClass() { return accuracyClass; }
    public void setAccuracyClass(String accuracyClass) { this.accuracyClass = accuracyClass; }

    public BigDecimal getConfidence() { return confidence; }
    public void setConfidence(BigDecimal confidence) { this.confidence = confidence; }

    public Instant getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(Instant submittedAt) { this.submittedAt = submittedAt; }

    public int getCorroborationCount() { return corroborationCount; }
    public void setCorroborationCount(int corroborationCount) { this.corroborationCount = corroborationCount; }

    public boolean isPromotedForReview() { return promotedForReview; }
    public void setPromotedForReview(boolean promotedForReview) { this.promotedForReview = promotedForReview; }

    public String getProposedGeometryWkt() { return proposedGeometryWkt; }
    public void setProposedGeometryWkt(String proposedGeometryWkt) { this.proposedGeometryWkt = proposedGeometryWkt; }

    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }

    public String getPublisher() { return publisher; }
    public void setPublisher(String publisher) { this.publisher = publisher; }

    public String getLicense() { return license; }
    public void setLicense(String license) { this.license = license; }
}
