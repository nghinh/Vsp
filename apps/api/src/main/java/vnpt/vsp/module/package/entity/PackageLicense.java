package vnpt.vsp.module.pkg.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import java.util.UUID;

/**
 * A license entry associated with a course package manifest.
 *
 * Tracks data licensing information as required by Story 4.1 AC-1.
 */
@Entity
@Table(name = "package_license")
public class PackageLicense {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manifest_id", nullable = false)
    private CoursePackageManifest manifest;

    @NotBlank
    @Column(nullable = false)
    private String name;

    private String url;

    private String spdxId;

    // JPA-required no-arg constructor
    protected PackageLicense() {}

    public PackageLicense(String name, String url, String spdxId) {
        this.name = name;
        this.url = url;
        this.spdxId = spdxId;
    }

    // Getters
    public UUID getId() { return id; }
    public CoursePackageManifest getManifest() { return manifest; }
    public String getName() { return name; }
    public String getUrl() { return url; }
    public String getSpdxId() { return spdxId; }

    // Setters
    public void setManifest(CoursePackageManifest manifest) { this.manifest = manifest; }
}
