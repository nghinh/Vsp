package vnpt.vsp.module.correction.entity;

import jakarta.persistence.*;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.VerificationStatus;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * JPA entity representing a golfer-submitted course data correction.
 *
 * <p>Submitted via the mobile app (Story 9.1) and reviewed through the
 * Course Operations Portal (Story 9.2).  Each correction carries the
 * reporter's GPS location and optional photo evidence so the reviewer
 * can validate the claim against official geometry.</p>
 *
 * <p>State transitions are enforced at the service layer:
 * <ul>
 *   <li>{@code PENDING} → {@code IN_REVIEW} when a reviewer opens the correction</li>
 *   <li>{@code IN_REVIEW} → {@code APPROVED | REJECTED | INFO_REQUESTED | CONVERTED_TO_DRAFT}</li>
 * </ul>
 *
 * Per Story 9.2 AC-1, AC-2, AC-3 and Slice Plan §Slice A.
 */
@Entity
@Table(name = "course_corrections", indexes = {
        @Index(name = "idx_correction_course", columnList = "course_id"),
        @Index(name = "idx_correction_hole", columnList = "hole_id"),
        @Index(name = "idx_correction_reporter", columnList = "reporter_id"),
        @Index(name = "idx_correction_status", columnList = "status"),
        @Index(name = "idx_correction_type", columnList = "correction_type"),
        @Index(name = "idx_correction_submitted", columnList = "submitted_at"),
        @Index(name = "idx_correction_confidence", columnList = "confidence")
})
public class CourseCorrection {

    // ─── Primary key ─────────────────────────────────────────────────────────

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ─── Core identification ───────────────────────────────────────────────────

    /** The course this correction relates to */
    @Column(name = "course_id", nullable = false)
    private Long courseId;

    /** The specific hole this correction relates to (nullable for course-level corrections) */
    @Column(name = "hole_id")
    private Long holeId;

    /** Golfer account ID of the person who submitted this correction */
    @Column(name = "reporter_id", nullable = false)
    private Long reporterId;

    // ─── Reporter evidence (AC-2) ─────────────────────────────────────────────

    /** Free-text description from the reporter */
    @Column(name = "reporter_note", columnDefinition = "TEXT")
    private String reporterNote;

    /** URL to an optional photo the reporter uploaded */
    @Column(name = "reporter_evidence_url")
    private String reporterEvidenceUrl;

    /**
     * Reporter's GPS position when the correction was submitted, SRID 4326.
     *
     * <p>Read-only through JPA for the same reason as {@link #proposedGeometry}:
     * PostgreSQL rejects a {@code varchar} bind parameter against a
     * {@code geometry} column, so an INSERT that carries this field — even as
     * NULL — fails at statement-parse time. Written via
     * {@link vnpt.vsp.module.correction.repository.CourseCorrectionRepository#setGeometryColumns}.</p>
     */
    @Column(name = "reporter_gps_location", columnDefinition = "geometry(Point,4326)",
            insertable = false, updatable = false)
    private String reporterGpsLocation;

    // ─── Classification ────────────────────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "correction_type", nullable = false, length = 30)
    private CorrectionType correctionType;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private CorrectionStatus status = CorrectionStatus.PENDING;

    /** Reporter's self-assessed confidence 0.00 – 100.00 */
    @Column(name = "confidence", precision = 5, scale = 2)
    private BigDecimal confidence;

    // ─── Geometry correction (golfer-reported layer fix) ───────────────────────

    /**
     * Which per-hole geometry layer this correction is about.
     * Null for non-geometry corrections (course condition, green speed, …).
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "geometry_layer", length = 20)
    private GeometryLayer geometryLayer;

    /**
     * The shape the reporter believes is correct, as SRID 4326.
     *
     * <p><strong>Never written through JPA.</strong> PostgreSQL refuses a
     * {@code varchar} bind parameter for a {@code geometry} column
     * ("column is of type geometry but expression is of type character
     * varying"), and every geometry column in this codebase is mapped as a
     * {@code String}. The column is therefore declared read-only here — so
     * Hibernate still creates it under {@code ddl-auto} — and is populated by
     * {@link vnpt.vsp.module.correction.repository.CourseCorrectionRepository#setGeometryColumns}
     * which wraps the WKT in {@code ST_GeomFromText}. Read it back as WKT with
     * {@code findProposedGeometryWkt}; a plain read of this field yields EWKB hex.</p>
     */
    @Column(name = "proposed_geometry", columnDefinition = "geometry(Geometry,4326)",
            insertable = false, updatable = false)
    private String proposedGeometry;

    /** Reporter's horizontal GPS accuracy in metres at submission time. */
    @Column(name = "gps_accuracy_meters")
    private Double gpsAccuracyMeters;

    /**
     * How many independent reports (including this one) corroborate this
     * correction — i.e. the size of the spatial cluster it belongs to.
     * Maintained by the corroboration pass; 1 until a second report lands nearby.
     */
    @Column(name = "corroboration_count", nullable = false)
    private Integer corroborationCount = 1;

    // ─── Review fields ────────────────────────────────────────────────────────

    @Column(name = "submitted_at", nullable = false)
    private Instant submittedAt;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    /** Admin account ID that performed the review */
    @Column(name = "reviewed_by")
    private Long reviewedBy;

    /** Reviewer's optional note explaining the decision */
    @Column(name = "review_note", columnDefinition = "TEXT")
    private String reviewNote;

    /** Resolution summary for APPROVED or REJECTED */
    @Column(name = "resolution", columnDefinition = "TEXT")
    private String resolution;

    /**
     * ID of the {@code DataVersion} created when this approved correction was published.
     * Populated by {@code PublishService} after the DRAFT → PUBLISHED transition
     * (Story 9.3 AC-1: correction remains linked through publication).
     */
    @Column(name = "resulting_version_id")
    private Long resultingVersionId;

    // ─── Data quality metadata (Architecture §9.3) ─────────────────────────────

    @Embedded
    @AttributeOverride(
            name = "confidence",
            column = @Column(name = "confidence", precision = 5, scale = 2, insertable = false, updatable = false))
    private DataQualityMetadata metadata = new DataQualityMetadata();

    // ─── Lifecycle callbacks ───────────────────────────────────────────────────

    @PrePersist
    protected void onCreate() {
        if (metadata.getCreatedAt() == null) {
            metadata.onCreate();
        }
        if (submittedAt == null) {
            submittedAt = Instant.now();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        metadata.onUpdate();
    }

    // ─── State-transition helpers ─────────────────────────────────────────────

    /**
     * Marks this correction as being reviewed, preventing simultaneous review.
     * Transitions: PENDING → IN_REVIEW
     */
    public void markInReview() {
        if (this.status != CorrectionStatus.PENDING) {
            throw new IllegalStateException(
                    "Can only mark PENDING correction as IN_REVIEW, current status: " + this.status);
        }
        this.status = CorrectionStatus.IN_REVIEW;
    }

    /**
     * Transitions to a terminal state.
     * @throws IllegalStateException if current status is not IN_REVIEW
     */
    public void approve(String resolution, Long reviewedBy, String reviewNote) {
        requireInReview();
        this.status = CorrectionStatus.APPROVED;
        this.resolution = resolution;
        this.reviewNote = reviewNote;
        this.reviewedBy = reviewedBy;
        this.reviewedAt = Instant.now();
    }

    public void reject(String reason, Long reviewedBy, String reviewNote) {
        requireInReview();
        this.status = CorrectionStatus.REJECTED;
        this.resolution = reason;
        this.reviewNote = reviewNote;
        this.reviewedBy = reviewedBy;
        this.reviewedAt = Instant.now();
    }

    public void requestInfo(String message, Long reviewedBy, String reviewNote) {
        requireInReview();
        this.status = CorrectionStatus.INFO_REQUESTED;
        this.resolution = message;
        this.reviewNote = reviewNote;
        this.reviewedBy = reviewedBy;
        this.reviewedAt = Instant.now();
    }

    public void convertToDraft(String draftReference, Long reviewedBy, String reviewNote) {
        requireInReview();
        this.status = CorrectionStatus.CONVERTED_TO_DRAFT;
        this.resolution = draftReference;
        this.reviewNote = reviewNote;
        this.reviewedBy = reviewedBy;
        this.reviewedAt = Instant.now();
    }

    /**
     * Resolves this correction to a terminal state (APPROVED or REJECTED).
     * <p>
     * This is the canonical resolution entry point for Story 9.3 Wave 2.
     * Unlike {@link #approve(String, Long, String)} which requires IN_REVIEW first,
     * this method accepts both PENDING and IN_REVIEW as valid starting states.
     *
     * @param decision    APPROVED or REJECTED
     * @param reviewedBy admin user performing the resolution
     * @param resolutionNote reviewer-provided reason (stored as {@code reviewNote})
     * @throws IllegalStateException if current status is a terminal state
     * @throws IllegalArgumentException if decision is null
     */
    public void resolve(Decision decision, Long reviewedBy, String resolutionNote) {
        if (this.status == CorrectionStatus.APPROVED
                || this.status == CorrectionStatus.REJECTED
                || this.status == CorrectionStatus.INFO_REQUESTED
                || this.status == CorrectionStatus.CONVERTED_TO_DRAFT) {
            throw new IllegalStateException(
                    "Cannot resolve correction " + id + ": already in terminal state " + this.status);
        }
        if (decision == null) {
            throw new IllegalArgumentException("decision is required");
        }
        this.status = decision == Decision.APPROVE
                ? CorrectionStatus.APPROVED
                : CorrectionStatus.REJECTED;
        this.resolution = resolutionNote;
        this.reviewNote = resolutionNote;
        this.reviewedBy = reviewedBy;
        this.reviewedAt = Instant.now();
    }

    /**
     * Back-links this correction to a published {@code DataVersion}.
     * Called by {@code PublishService} after an approved correction's draft is published
     * (Story 9.3 Wave 4).
     *
     * @param resultingVersionId ID of the published DataVersion
     */
    public void linkToPublishedVersion(Long resultingVersionId) {
        this.resultingVersionId = resultingVersionId;
    }

    /**
     * Decision options for {@link #resolve(Decision, Long, String)}.
     */
    public enum Decision {
        APPROVE,
        REJECT
    }

    private void requireInReview() {
        if (this.status != CorrectionStatus.IN_REVIEW) {
            throw new IllegalStateException(
                    "Correction must be IN_REVIEW before terminal transition, current status: " + this.status);
        }
    }

    // ─── Getters and Setters ───────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Long getHoleId() { return holeId; }
    public void setHoleId(Long holeId) { this.holeId = holeId; }

    public Long getReporterId() { return reporterId; }
    public void setReporterId(Long reporterId) { this.reporterId = reporterId; }

    public String getReporterNote() { return reporterNote; }
    public void setReporterNote(String reporterNote) { this.reporterNote = reporterNote; }

    public String getReporterEvidenceUrl() { return reporterEvidenceUrl; }
    public void setReporterEvidenceUrl(String reporterEvidenceUrl) { this.reporterEvidenceUrl = reporterEvidenceUrl; }

    public String getReporterGpsLocation() { return reporterGpsLocation; }

    /**
     * In-memory only — the column is read-only through JPA. Persist the
     * reporter fix with {@code CourseCorrectionRepository.setGeometryColumns}.
     */
    public void setReporterGpsLocation(String reporterGpsLocation) { this.reporterGpsLocation = reporterGpsLocation; }

    public CorrectionType getCorrectionType() { return correctionType; }
    public void setCorrectionType(CorrectionType correctionType) { this.correctionType = correctionType; }

    public CorrectionStatus getStatus() { return status; }
    public void setStatus(CorrectionStatus status) { this.status = status; }

    public BigDecimal getConfidence() { return confidence; }
    public void setConfidence(BigDecimal confidence) { this.confidence = confidence; }

    public GeometryLayer getGeometryLayer() { return geometryLayer; }
    public void setGeometryLayer(GeometryLayer geometryLayer) { this.geometryLayer = geometryLayer; }

    /** @return EWKB hex as stored, not WKT — see the field javadoc. */
    public String getProposedGeometry() { return proposedGeometry; }

    public Double getGpsAccuracyMeters() { return gpsAccuracyMeters; }
    public void setGpsAccuracyMeters(Double gpsAccuracyMeters) { this.gpsAccuracyMeters = gpsAccuracyMeters; }

    public Integer getCorroborationCount() { return corroborationCount; }
    public void setCorroborationCount(Integer corroborationCount) { this.corroborationCount = corroborationCount; }

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

    public Long getResultingVersionId() { return resultingVersionId; }
    public void setResultingVersionId(Long resultingVersionId) { this.resultingVersionId = resultingVersionId; }

    public DataQualityMetadata getMetadata() { return metadata; }
    public void setMetadata(DataQualityMetadata metadata) { this.metadata = metadata; }
}
