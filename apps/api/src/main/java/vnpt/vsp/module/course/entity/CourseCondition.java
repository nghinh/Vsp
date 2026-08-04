package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;

/**
 * CourseCondition entity — current/historical playing conditions for a course.
 * Per PRD §9.1: CourseCondition listed as core entity.
 * Per PRD §8.11: green speed and course condition management in portal.
 */
@Entity(name = "CourseDataCondition")
@Table(name = "course_conditions")
@vnpt.vsp.module.course.CourseModule
public class CourseCondition {

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

    public enum Severity {
        LOW, MODERATE, HIGH, CRITICAL
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Enumerated(EnumType.STRING)
    @Column(name = "condition_type", nullable = false, length = 50)
    private ConditionType conditionType;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private Severity severity;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "effective_date", nullable = false)
    private LocalDate effectiveDate;

    @Column(name = "expiry_date")
    private LocalDate expiryDate;

    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "effectiveDate", column = @Column(name = "effective_date", insertable = false, updatable = false)),
            @AttributeOverride(name = "expiryDate", column = @Column(name = "expiry_date", insertable = false, updatable = false))
    })
    private DataQualityMetadata metadata = new DataQualityMetadata();

    @PrePersist
    protected void onCreate() {
        if (metadata.getCreatedAt() == null) metadata.onCreate();
    }

    @PreUpdate
    protected void onUpdate() {
        metadata.onUpdate();
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

    public LocalDate getEffectiveDate() {
        return effectiveDate;
    }

    public void setEffectiveDate(LocalDate effectiveDate) {
        this.effectiveDate = effectiveDate;
    }

    public LocalDate getExpiryDate() {
        return expiryDate;
    }

    public void setExpiryDate(LocalDate expiryDate) {
        this.expiryDate = expiryDate;
    }

    public DataQualityMetadata getMetadata() {
        return metadata;
    }

    /** Alias for getMetadata() — expected by CourseServiceImpl. */
    public DataQualityMetadata getDataQuality() {
        return metadata;
    }

    public void setMetadata(DataQualityMetadata metadata) {
        this.metadata = metadata;
    }
}
