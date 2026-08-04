package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Tee set entity representing a named tee (e.g., Black, White, Gold) on a course.
 * Per Story 3.1 GEO-3: tee set with total par.
 * Per PRD Section 9.1: Tee Set listed as core entity.
 */
@Entity
@Table(name = "tee_sets")
public class TeeSet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Column(nullable = false)
    private String name;

    @Column(name = "total_par")
    private Integer totalPar;

    @OneToMany(mappedBy = "teeSet", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<TeeBox> teeBoxes = new ArrayList<>();

    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "createdAt", column = @Column(name = "created_at", insertable = false, updatable = false)),
            @AttributeOverride(name = "updatedAt", column = @Column(name = "updated_at", insertable = false, updatable = false))
    })
    private DataQualityMetadata dataQuality = new DataQualityMetadata();

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
        initDefaults();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    private void initDefaults() {
        if (dataQuality.getPublisher() == null) dataQuality.setPublisher("SYSTEM");
        if (dataQuality.getEffectiveDate() == null) dataQuality.setEffectiveDate(java.time.LocalDate.now());
        if (dataQuality.getVersion() == null) dataQuality.setVersion(1);
        if (dataQuality.getVerificationStatus() == null) dataQuality.setVerificationStatus(VerificationStatus.UNVERIFIED);
        if (dataQuality.getAccuracyClass() == null) dataQuality.setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Course getCourse() { return course; }
    public void setCourse(Course course) { this.course = course; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public Integer getTotalPar() { return totalPar; }
    public void setTotalPar(Integer totalPar) { this.totalPar = totalPar; }
    public List<TeeBox> getTeeBoxes() { return teeBoxes; }
    public void setTeeBoxes(List<TeeBox> teeBoxes) { this.teeBoxes = teeBoxes; }
    public DataQualityMetadata getDataQuality() { return dataQuality; }
    public void setDataQuality(DataQualityMetadata dataQuality) { this.dataQuality = dataQuality; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
