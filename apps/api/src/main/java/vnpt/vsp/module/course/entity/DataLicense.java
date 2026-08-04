package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.time.LocalDate;

/**
 * DataLicense entity — license tracking per data source for a course data version.
 * Per PRD §9.1: DataLicense listed as core entity.
 * Per PRD §11.2 success metric 18: all data licenses must be valid.
 */
@Entity(name = "CourseDataLicense")
@Table(name = "data_licenses")
@vnpt.vsp.module.course.CourseModule
public class DataLicense {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "data_version_id", nullable = false)
    private DataVersion dataVersion;

    @Column(name = "license_type", nullable = false, length = 100)
    private String licenseType;

    @Column(nullable = false)
    private String licensee;

    @Column(name = "license_key")
    private String licenseKey;

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

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public DataVersion getDataVersion() {
        return dataVersion;
    }

    public void setDataVersion(DataVersion dataVersion) {
        this.dataVersion = dataVersion;
    }

    public String getLicenseType() {
        return licenseType;
    }

    public void setLicenseType(String licenseType) {
        this.licenseType = licenseType;
    }

    public String getLicensee() {
        return licensee;
    }

    public void setLicensee(String licensee) {
        this.licensee = licensee;
    }

    public String getLicenseKey() {
        return licenseKey;
    }

    public void setLicenseKey(String licenseKey) {
        this.licenseKey = licenseKey;
    }

    public LocalDate getEffectiveDate() {
        return effectiveDate;
    }

    public void setEffectiveDate(LocalDate effectiveDate) {
        this.effectiveDate = effectiveDate;
    }

    public LocalDate getExpiryDate() {
        return expiryDate;
    }

    public void setExpiryDate(LocalDate expiryDate) {
        this.expiryDate = expiryDate;
    }

    public DataQualityMetadata getMetadata() {
        return metadata;
    }

    public void setMetadata(DataQualityMetadata metadata) {
        this.metadata = metadata;
    }
}
