package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Type;
import vnpt.vsp.persistence.WktGeometryType;
import java.time.LocalDate;

/**
 * PinPosition entity — individual pin location with pin scheduling.
 * Per PRD §8.11 pin position management and Architecture §7.3 effective/expiry dates.
 */
@Entity(name = "CoursePinPosition")
@Table(name = "pin_positions")
@vnpt.vsp.module.course.CourseModule
public class PinPosition {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hole_id", nullable = false)
    private Hole hole;

    @Type(WktGeometryType.class)
    @Column(nullable = false, columnDefinition = "geometry(Point,4326)")
    private String location;

    @Column(name = "pin_position_type", length = 20)
    private String pinPositionType = "CURRENT";

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

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Hole getHole() { return hole; }
    public void setHole(Hole hole) { this.hole = hole; }
    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }
    public String getPinPositionType() { return pinPositionType; }
    public void setPinPositionType(String pinPositionType) { this.pinPositionType = pinPositionType; }
    public LocalDate getEffectiveDate() { return effectiveDate; }
    public void setEffectiveDate(LocalDate effectiveDate) { this.effectiveDate = effectiveDate; }
    public LocalDate getExpiryDate() { return expiryDate; }
    public void setExpiryDate(LocalDate expiryDate) { this.expiryDate = expiryDate; }
    public DataQualityMetadata getMetadata() { return metadata; }
    /** Alias for getMetadata() — expected by CourseServiceImpl. */
    public DataQualityMetadata getDataQuality() { return metadata; }
    public void setMetadata(DataQualityMetadata metadata) { this.metadata = metadata; }
}
