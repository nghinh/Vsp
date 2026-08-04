package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;

/**
 * Bunker entity — sand trap hazard.
 * Per PRD §9.1 and Story 3.1 AC-1.
 */
@Entity
@Table(name = "bunkers")
@vnpt.vsp.module.course.CourseModule
public class Bunker {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hole_id", nullable = false)
    private Hole hole;

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
    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }
    public DataQualityMetadata getMetadata() { return metadata; }
    public void setMetadata(DataQualityMetadata metadata) { this.metadata = metadata; }
}
