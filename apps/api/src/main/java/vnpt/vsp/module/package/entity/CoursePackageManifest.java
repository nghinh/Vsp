package vnpt.vsp.module.pkg.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * JPA entity for a course package manifest.
 *
 * Represents the offline course package contract (Story 4.1 AC-1).
 * Distinct from the booking/commercial CoursePackage in course.yaml.
 */
@Entity
@Table(name = "course_package_manifest",
    indexes = {
        @Index(name = "idx_manifest_course_version", columnList = "courseId, version", unique = true),
        @Index(name = "idx_manifest_course_effective", columnList = "courseId, effectiveFrom")
    })
public class CoursePackageManifest {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @NotNull
    @Column(nullable = false)
    private Long courseId;

    @NotNull
    private Long dataVersionId;

    @NotBlank
    @Column(nullable = false)
    private String version; // semver

    @NotNull
    @Min(0)
    @Column(nullable = false)
    private Long packageSizeBytes;

    @NotBlank
    @Column(nullable = false)
    private String checksum; // SHA-256 hex

    @NotNull
    @Column(nullable = false)
    private Instant effectiveFrom;

    private Instant expiresAt;

    @NotBlank
    @Column(nullable = false)
    private String minimumClientVersion; // semver

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TilesFormat tilesFormat;

    @NotBlank
    @Column(nullable = false)
    private String tilesUrl;

    @NotBlank
    @Column(nullable = false)
    private String geoJsonUrl;

    private String scorecardUrl;
    private String rulesUrl;
    private String conditionsUrl;
    private String metadataUrl;

    @NotNull
    @Column(nullable = false)
    private Instant generatedAt;

    @NotBlank
    @Column(nullable = false)
    private String generatedBy;

    @Enumerated(EnumType.STRING)
    private AccuracyClass accuracyClass;

    private Double confidence;

    private Instant pinSnapshotDate;
    private Instant conditionsSnapshotDate;
    private Instant weatherSnapshotDate;

    @OneToMany(mappedBy = "manifest", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<PackageFileEntry> files = new ArrayList<>();

    @OneToMany(mappedBy = "manifest", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<PackageLicense> licenses = new ArrayList<>();

    public enum TilesFormat {
        PMTILES, MBTILES, VECTOR_TILES
    }

    public enum AccuracyClass {
        A_RTK_SURVEYED, B_LICENSED_PROVIDER, C_VERIFIED_SATELLITE, D_UNVERIFIED_COMMUNITY
    }

    // JPA-required no-arg constructor
    protected CoursePackageManifest() {}

    public CoursePackageManifest(Long courseId, Long dataVersionId, String version,
            Long packageSizeBytes, String checksum, Instant effectiveFrom,
            String minimumClientVersion, TilesFormat tilesFormat,
            String tilesUrl, String geoJsonUrl, Instant generatedAt, String generatedBy) {
        this.courseId = courseId;
        this.dataVersionId = dataVersionId;
        this.version = version;
        this.packageSizeBytes = packageSizeBytes;
        this.checksum = checksum;
        this.effectiveFrom = effectiveFrom;
        this.minimumClientVersion = minimumClientVersion;
        this.tilesFormat = tilesFormat;
        this.tilesUrl = tilesUrl;
        this.geoJsonUrl = geoJsonUrl;
        this.generatedAt = generatedAt;
        this.generatedBy = generatedBy;
    }

    // Getters
    public UUID getId() { return id; }
    public Long getCourseId() { return courseId; }
    public Long getDataVersionId() { return dataVersionId; }
    public String getVersion() { return version; }
    public Long getPackageSizeBytes() { return packageSizeBytes; }
    public String getChecksum() { return checksum; }
    public Instant getEffectiveFrom() { return effectiveFrom; }
    public Instant getExpiresAt() { return expiresAt; }
    public String getMinimumClientVersion() { return minimumClientVersion; }
    public TilesFormat getTilesFormat() { return tilesFormat; }
    public String getTilesUrl() { return tilesUrl; }
    public String getGeoJsonUrl() { return geoJsonUrl; }
    public String getScorecardUrl() { return scorecardUrl; }
    public String getRulesUrl() { return rulesUrl; }
    public String getConditionsUrl() { return conditionsUrl; }
    public String getMetadataUrl() { return metadataUrl; }
    public Instant getGeneratedAt() { return generatedAt; }
    public String getGeneratedBy() { return generatedBy; }
    public AccuracyClass getAccuracyClass() { return accuracyClass; }
    public Double getConfidence() { return confidence; }
    public Instant getPinSnapshotDate() { return pinSnapshotDate; }
    public Instant getConditionsSnapshotDate() { return conditionsSnapshotDate; }
    public Instant getWeatherSnapshotDate() { return weatherSnapshotDate; }
    public List<PackageFileEntry> getFiles() { return files; }
    public List<PackageLicense> getLicenses() { return licenses; }

    // Setters
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
    public void setScorecardUrl(String scorecardUrl) { this.scorecardUrl = scorecardUrl; }
    public void setRulesUrl(String rulesUrl) { this.rulesUrl = rulesUrl; }
    public void setConditionsUrl(String conditionsUrl) { this.conditionsUrl = conditionsUrl; }
    public void setMetadataUrl(String metadataUrl) { this.metadataUrl = metadataUrl; }
    public void setAccuracyClass(AccuracyClass accuracyClass) { this.accuracyClass = accuracyClass; }
    public void setConfidence(Double confidence) { this.confidence = confidence; }
    public void setPinSnapshotDate(Instant pinSnapshotDate) { this.pinSnapshotDate = pinSnapshotDate; }
    public void setConditionsSnapshotDate(Instant conditionsSnapshotDate) { this.conditionsSnapshotDate = conditionsSnapshotDate; }
    public void setWeatherSnapshotDate(Instant weatherSnapshotDate) { this.weatherSnapshotDate = weatherSnapshotDate; }

    public void addFile(PackageFileEntry file) {
        files.add(file);
        file.setManifest(this);
    }

    public void addLicense(PackageLicense license) {
        licenses.add(license);
        license.setManifest(this);
    }
}
