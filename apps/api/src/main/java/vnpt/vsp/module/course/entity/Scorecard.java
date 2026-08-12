package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * A card as the club prints it, for one pairing of đường.
 *
 * <p>Par could live on the hole, and does. Stroke index cannot: a club with
 * đường A, B and C prints a card per pairing and the index on it runs 1..18
 * across the two nines it was printed for. Hole 3 of đường A is index 7 on the
 * A+B card and something else on A+C, so an index column on {@code holes}
 * would be storing one card's numbers and claiming they belong to the hole.
 *
 * <p>A club with a single eighteen has one card with one segment. Nothing
 * about that case is special, which is the point.
 */
@Entity
@Table(name = "scorecards")
public class Scorecard {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "facility_id", nullable = false)
    private Long facilityId;

    /** What the club calls this card: "A + B", "King's Course". */
    @Column(nullable = false)
    private String name;

    @Column(name = "holes_count", nullable = false)
    private Integer holesCount;

    @Column(name = "par_total")
    private Integer parTotal;

    @Column(name = "source")
    private String source;

    @Column(name = "publisher", nullable = false)
    private String publisher;

    @Column(name = "license")
    private String license;

    @Column(name = "accuracy_class", length = 30)
    private String accuracyClass;

    @Column(name = "verification_status", length = 20)
    private String verificationStatus;

    @Column(name = "effective_date", nullable = false)
    private LocalDate effectiveDate = LocalDate.now();

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @OneToMany(mappedBy = "scorecard", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<ScorecardSegment> segments = new ArrayList<>();

    @OneToMany(mappedBy = "scorecard", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<ScorecardHole> holes = new ArrayList<>();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getFacilityId() { return facilityId; }
    public void setFacilityId(Long facilityId) { this.facilityId = facilityId; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public Integer getHolesCount() { return holesCount; }
    public void setHolesCount(Integer holesCount) { this.holesCount = holesCount; }
    public Integer getParTotal() { return parTotal; }
    public void setParTotal(Integer parTotal) { this.parTotal = parTotal; }
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    public String getPublisher() { return publisher; }
    public void setPublisher(String publisher) { this.publisher = publisher; }
    public String getLicense() { return license; }
    public void setLicense(String license) { this.license = license; }
    public String getAccuracyClass() { return accuracyClass; }
    public void setAccuracyClass(String accuracyClass) { this.accuracyClass = accuracyClass; }
    public String getVerificationStatus() { return verificationStatus; }
    public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }
    public LocalDate getEffectiveDate() { return effectiveDate; }
    public void setEffectiveDate(LocalDate effectiveDate) { this.effectiveDate = effectiveDate; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
    public List<ScorecardSegment> getSegments() { return segments; }
    public void setSegments(List<ScorecardSegment> segments) { this.segments = segments; }
    public List<ScorecardHole> getHoles() { return holes; }
    public void setHoles(List<ScorecardHole> holes) { this.holes = holes; }
}
