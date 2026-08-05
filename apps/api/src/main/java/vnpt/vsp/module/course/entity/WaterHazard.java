package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Type;
import vnpt.vsp.persistence.WktGeometryType;

/**
 * WaterHazard entity — water hazard (pond, stream, lake) affecting a hole.
 * Per PRD §9.1 and Story 3.1 AC-1.
 */
@Entity
@Table(name = "water_hazards")
@vnpt.vsp.module.course.CourseModule
public class WaterHazard {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hole_id", nullable = false)
    private Hole hole;

    @Type(WktGeometryType.class)
    @Column(nullable = false, columnDefinition = "geometry(Geometry,4326)")
    private String location;

    @Column(name = "hazard_type", length = 50)
    private String hazardType = "WATER";

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
    public String getHazardType() { return hazardType; }
    public void setHazardType(String hazardType) { this.hazardType = hazardType; }
    public DataQualityMetadata getMetadata() { return metadata; }
    public void setMetadata(DataQualityMetadata metadata) { this.metadata = metadata; }
}
