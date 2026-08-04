package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Course entity representing a playable 9 or 18-hole layout.
 * Per Story 3.1 AC-1 and PRD §9.1.
 */
@Entity
@Table(name = "courses")
@vnpt.vsp.module.course.CourseModule
public class Course {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "facility_id", nullable = false)
    private GolfFacility facility;

    @Column(nullable = false)
    private String name;

    @Column(name = "holes_count", nullable = false)
    private Integer holesCount;

    @Column(name = "par_total", nullable = false)
    private Integer parTotal;

    /** Course boundary or centroid as SRID 4326 geometry */
    @Column(columnDefinition = "geometry(Geometry,4326)")
    private String location;

    @Embedded
    private DataQualityMetadata metadata = new DataQualityMetadata();

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<Hole> holes = new ArrayList<>();

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<TeeSet> teeSets = new ArrayList<>();

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<CourseCondition> courseConditions = new ArrayList<>();

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<DataVersion> dataVersions = new ArrayList<>();

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

    public GolfFacility getFacility() {
        return facility;
    }

    public void setFacility(GolfFacility facility) {
        this.facility = facility;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Integer getHolesCount() {
        return holesCount;
    }

    public void setHolesCount(Integer holesCount) {
        this.holesCount = holesCount;
    }

    public Integer getParTotal() {
        return parTotal;
    }

    public void setParTotal(Integer parTotal) {
        this.parTotal = parTotal;
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

    public List<Hole> getHoles() {
        return holes;
    }

    public void setHoles(List<Hole> holes) {
        this.holes = holes;
    }

    public List<TeeSet> getTeeSets() {
        return teeSets;
    }

    public void setTeeSets(List<TeeSet> teeSets) {
        this.teeSets = teeSets;
    }

    public List<CourseCondition> getCourseConditions() {
        return courseConditions;
    }

    public void setCourseConditions(List<CourseCondition> courseConditions) {
        this.courseConditions = courseConditions;
    }

    public List<DataVersion> getDataVersions() {
        return dataVersions;
    }

    public void setDataVersions(List<DataVersion> dataVersions) {
        this.dataVersions = dataVersions;
    }

    public void addHole(Hole hole) {
        holes.add(hole);
        hole.setCourse(this);
    }

    public void addTeeSet(TeeSet teeSet) {
        teeSets.add(teeSet);
        teeSet.setCourse(this);
    }

    public void addDataVersion(DataVersion dataVersion) {
        dataVersions.add(dataVersion);
        dataVersion.setCourse(this);
    }
}
