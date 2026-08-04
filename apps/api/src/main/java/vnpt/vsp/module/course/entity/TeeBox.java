package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;

/**
 * TeeBox entity — the teeing ground area for a specific hole and tee set.
 * Per PRD §9.1 and Story 3.1 AC-1.
 */
@Entity
@Table(name = "tee_boxes")
@vnpt.vsp.module.course.CourseModule
public class TeeBox {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hole_id", nullable = false)
    private Hole hole;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tee_set_id")
    private TeeSet teeSet;

    @Column(nullable = false, columnDefinition = "geometry(Polygon,4326)")
    private String location;

    @Embedded
    private DataQualityMetadata metadata = new DataQualityMetadata();

    @PrePersist
    protected void onCreate() {
        if (metadata.getCreatedAt() == null) metadata.onCreate();
    }

    @PreUpdate
    protected void onUpdate() {
        metadata.onUpdate();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Hole getHole() { return hole; }
    public void setHole(Hole hole) { this.hole = hole; }
    public TeeSet getTeeSet() { return teeSet; }
    public void setTeeSet(TeeSet teeSet) { this.teeSet = teeSet; }
    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }
    public DataQualityMetadata getMetadata() { return metadata; }
    public void setMetadata(DataQualityMetadata metadata) { this.metadata = metadata; }
}
