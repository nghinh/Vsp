package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Type;
import vnpt.vsp.persistence.WktGeometryType;
import java.time.Instant;

/**
 * Golf facility entity representing a golf club or resort.
 * Per Story 3.1 AC-1 and PRD §9.1.
 */
@Entity
@Table(name = "golf_facilities")
@vnpt.vsp.module.course.CourseModule
public class GolfFacility {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(length = 500)
    private String address;

    @Column(length = 50)
    private String phone;

    private String website;

    /** Centroid location as SRID 4326 POINT (stored as Geometry in Hibernate Spatial) */
    @Type(WktGeometryType.class)
    @Column(columnDefinition = "geometry(Point,4326)")
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

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getWebsite() {
        return website;
    }

    public void setWebsite(String website) {
        this.website = website;
    }

    public String getLocation() {
        return location;
    }

    public void setLocation(String location) {
        this.location = location;
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

    /** Alias for setMetadata() — expected by CourseServiceImpl. */
    public void setDataQuality(DataQualityMetadata dataQuality) {
        this.metadata = dataQuality;
    }
}
