package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * DataVersion entity — append-versioned course data version record.
 * Per Architecture §7.3: draft → published → archived lifecycle.
 * Per PRD §8.11: version history, publish, rollback.
 * Per Story 3.1 AC-3: DataVersion carries data quality metadata.
 */
@Entity
@Table(name = "data_versions",
    uniqueConstraints = @UniqueConstraint(name = "chk_dv_version_number_unique",
        columnNames = {"course_id", "version_number"}))
@vnpt.vsp.module.course.CourseModule
public class DataVersion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Column(name = "version_number", nullable = false)
    private Integer versionNumber;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private DataVersionStatus status = DataVersionStatus.DRAFT;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Column(name = "published_by")
    private String publishedBy;

    @Column(name = "publish_note", columnDefinition = "TEXT")
    private String publishNote;

    /**
     * Records the rollback note when this version was re-activated via rollback.
     * Set by {@link #rollbackTo(String, String)}.
     */
    @Column(name = "rollback_note", columnDefinition = "TEXT")
    private String rollbackNote;

    /**
     * Nullable FK to the {@code CourseCorrection} that originated this draft version.
     * Populated when an approved correction produces a draft change (Story 9.3 Wave 2).
     * Used by {@code PublishService} to back-link {@code Correction.resultingVersionId}
     * after DRAFT → PUBLISHED transition (Story 9.3 Wave 4).
     */
    @Column(name = "correction_id")
    private Long correctionId;

    @Embedded
    private DataQualityMetadata metadata = new DataQualityMetadata();

    @OneToMany(mappedBy = "dataVersion", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<DataLicense> dataLicenses = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        if (metadata.getCreatedAt() == null) metadata.onCreate();
    }

    @PreUpdate
    protected void onUpdate() {
        metadata.onUpdate();
    }

    // ─── State transition helpers ──────────────────────────────────────────

    /**
     * Publish this version. Sets status to PUBLISHED, records timestamp and publisher.
     */
    public void publish(String publishedBy, String publishNote) {
        this.status = DataVersionStatus.PUBLISHED;
        this.publishedAt = Instant.now();
        this.publishedBy = publishedBy;
        this.publishNote = publishNote;
    }

    /**
     * Archive this version.
     */
    public void archive() {
        this.status = DataVersionStatus.ARCHIVED;
    }

    /**
     * Re-activate this version as the current published version (rollback).
     * Sets status to PUBLISHED, updates publishedAt/publishedBy, and records the rollback note.
     * Per Architecture §7.3 and PRD §8.11: rollback creates a new published version referencing prior data.
     *
     * @param actor the user performing the rollback
     * @param rollbackNote the reason for the rollback
     */
    public void rollbackTo(String actor, String rollbackNote) {
        this.status = DataVersionStatus.PUBLISHED;
        this.publishedAt = Instant.now();
        this.publishedBy = actor;
        this.rollbackNote = rollbackNote;
    }

    /**
     * Increment version number for a new draft based on this version.
     * @return the new version number
     */
    public int nextVersionNumber() {
        return this.versionNumber + 1;
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

    public Integer getVersionNumber() {
        return versionNumber;
    }

    public void setVersionNumber(Integer versionNumber) {
        this.versionNumber = versionNumber;
    }

    public DataVersionStatus getStatus() {
        return status;
    }

    public void setStatus(DataVersionStatus status) {
        this.status = status;
    }

    public Instant getPublishedAt() {
        return publishedAt;
    }

    public void setPublishedAt(Instant publishedAt) {
        this.publishedAt = publishedAt;
    }

    public String getPublishedBy() {
        return publishedBy;
    }

    public void setPublishedBy(String publishedBy) {
        this.publishedBy = publishedBy;
    }

    public String getPublishNote() {
        return publishNote;
    }

    public void setPublishNote(String publishNote) {
        this.publishNote = publishNote;
    }

    public DataQualityMetadata getMetadata() {
        return metadata;
    }

    public void setMetadata(DataQualityMetadata metadata) {
        this.metadata = metadata;
    }

    public List<DataLicense> getDataLicenses() {
        return dataLicenses;
    }

    public void setDataLicenses(List<DataLicense> dataLicenses) {
        this.dataLicenses = dataLicenses;
    }

    public void addDataLicense(DataLicense license) {
        dataLicenses.add(license);
        license.setDataVersion(this);
    }

    public String getRollbackNote() {
        return rollbackNote;
    }

    public void setRollbackNote(String rollbackNote) {
        this.rollbackNote = rollbackNote;
    }

    public Long getCorrectionId() {
        return correctionId;
    }

    public void setCorrectionId(Long correctionId) {
        this.correctionId = correctionId;
    }
}
