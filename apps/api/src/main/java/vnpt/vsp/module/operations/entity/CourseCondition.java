package vnpt.vsp.module.operations.entity;

import jakarta.persistence.*;
import java.time.Instant;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.operations.OperationsModule;

/**
 * CourseCondition entity — course-wide operational conditions for the operations portal.
  * Per Story 8.5 AC-2: course status, maintenance, and alert management.
  * Per Architecture §7.3: effective and expiration timestamps for temporal queries.
  *
  * <p>Stores course-level conditions (overall status, maintenance, alerts) with
  * temporal validity windows. Active conditions are queried as:
  * now() BETWEEN effectiveFrom AND expiresAt (or expiresAt IS NULL for indefinite).</p>
 */
@Entity(name = "OperationsCourseCondition")
@Table(name = "course_conditions_ops")
@OperationsModule
public class CourseCondition {

    /** Condition type enum matching ConditionDto.conditionType */
    public enum ConditionType {
        GREEN_SPEED,
        GREEN_FIRMNESS,
        FAIRWAY_FIRMNESS,
        ROUGH_DENSITY,
        BUNKER_CONDITION,
        COURSE_MOISTURE,
        COURSE_OVERALL,
        WEATHER_IMPACT,
        OTHER
    }

    /** Condition severity level */
    public enum Severity {
        LOW, MODERATE, HIGH, CRITICAL
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Course this condition applies to */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    /** Type of condition */
    @Enumerated(EnumType.STRING)
    @Column(name = "condition_type", nullable = false, length = 50)
    private ConditionType conditionType;

    /** Condition severity */
    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private Severity severity;

    /** Human-readable condition description */
    @Column(columnDefinition = "TEXT")
    private String description;

    /** When this condition becomes active (inclusive) */
    @Column(name = "effective_from", nullable = false)
    private Instant effectiveFrom;

    /** When this condition expires (NULL = never expires) */
    @Column(name = "expires_at")
    private Instant expiresAt;

    /** User who published this condition */
    @Column(name = "published_by", nullable = false)
    private String publishedBy;

    /** Shared data quality metadata — source, license, accuracy, verification */
    @Embedded
    private DataQualityMetadata metadata = new DataQualityMetadata();

    @PrePersist
    protected void onCreate() {
        // JPA cascades @PrePersist to @Embedded; metadata timestamps set automatically
    }

    @PreUpdate
    protected void onUpdate() {
        // JPA cascades @PreUpdate to @Embedded; metadata timestamps set automatically
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Course getCourse() {
        return course;
    }

    public void setCourse(Course course) {
        this.course = course;
    }

    public ConditionType getConditionType() {
        return conditionType;
    }

    public void setConditionType(ConditionType conditionType) {
        this.conditionType = conditionType;
    }

    public Severity getSeverity() {
        return severity;
    }

    public void setSeverity(Severity severity) {
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

    public DataQualityMetadata getMetadata() {
        return metadata;
    }

    /** Alias for getMetadata() — consistent with other entities */
    public DataQualityMetadata getDataQuality() {
        return metadata;
    }

    public void setMetadata(DataQualityMetadata metadata) {
        this.metadata = metadata;
    }
}
