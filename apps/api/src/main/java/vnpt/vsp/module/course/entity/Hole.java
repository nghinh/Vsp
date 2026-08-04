package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * Hole entity representing an individual golf hole.
 * Per Story 3.1 AC-1 and PRD §9.1.
 */
@Entity
@Table(name = "holes", uniqueConstraints = {
    @UniqueConstraint(name = "chk_hole_number_unique", columnNames = {"course_id", "hole_number"})
})
@vnpt.vsp.module.course.CourseModule
public class Hole {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Column(name = "hole_number", nullable = false)
    private Integer holeNumber;

    @Column(nullable = false)
    private Integer par;

    @Column(name = "teeing_ground_location", columnDefinition = "geometry(Point,4326)")
    private String teeingGroundLocation;

    @Column(name = "green_location", columnDefinition = "geometry(Point,4326)")
    private String greenLocation;

    @Column(name = "playing_length_meters", precision = 7, scale = 2)
    private BigDecimal playingLengthMeters;

    @Embedded
    private DataQualityMetadata metadata = new DataQualityMetadata();

    @OneToMany(mappedBy = "hole", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<TeeBox> teeBoxes = new ArrayList<>();

    @OneToMany(mappedBy = "hole", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<PinPosition> pinPositions = new ArrayList<>();

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

    public Integer getHoleNumber() {
        return holeNumber;
    }

    public void setHoleNumber(Integer holeNumber) {
        this.holeNumber = holeNumber;
    }

    public Integer getPar() {
        return par;
    }

    public void setPar(Integer par) {
        this.par = par;
    }

    public String getTeeingGroundLocation() {
        return teeingGroundLocation;
    }

    public void setTeeingGroundLocation(String teeingGroundLocation) {
        this.teeingGroundLocation = teeingGroundLocation;
    }

    public String getGreenLocation() {
        return greenLocation;
    }

    public void setGreenLocation(String greenLocation) {
        this.greenLocation = greenLocation;
    }

    public BigDecimal getPlayingLengthMeters() {
        return playingLengthMeters;
    }

    public void setPlayingLengthMeters(BigDecimal playingLengthMeters) {
        this.playingLengthMeters = playingLengthMeters;
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

    public List<TeeBox> getTeeBoxes() {
        return teeBoxes;
    }

    public void setTeeBoxes(List<TeeBox> teeBoxes) {
        this.teeBoxes = teeBoxes;
    }

    public List<PinPosition> getPinPositions() {
        return pinPositions;
    }

    public void setPinPositions(List<PinPosition> pinPositions) {
        this.pinPositions = pinPositions;
    }
}
