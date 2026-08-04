package vnpt.vsp.module.pkg.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.UUID;

/**
 * A single file entry within a course package manifest.
 *
 * Represents the file inventory defined in Story 4.1 AC-1 and AC-2.
 */
@Entity
@Table(name = "package_file_entry",
    uniqueConstraints = @UniqueConstraint(columnNames = {"manifest_id", "path"}))
public class PackageFileEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manifest_id", nullable = false)
    private CoursePackageManifest manifest;

    @NotBlank
    @Column(nullable = false)
    private String path;

    @NotBlank
    @Column(nullable = false)
    private String checksum; // SHA-256 hex

    @NotNull
    @Min(0)
    @Column(nullable = false)
    private Long sizeBytes;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ContentType contentType;

    public enum ContentType {
        METADATA, GEOMETRY, TILES, SCORECARD, RULES, CONDITIONS, WEATHER, SATELLITE
    }

    // JPA-required no-arg constructor
    protected PackageFileEntry() {}

    public PackageFileEntry(String path, String checksum, Long sizeBytes, ContentType contentType) {
        this.path = path;
        this.checksum = checksum;
        this.sizeBytes = sizeBytes;
        this.contentType = contentType;
    }

    // Getters
    public UUID getId() { return id; }
    public CoursePackageManifest getManifest() { return manifest; }
    public String getPath() { return path; }
    public String getChecksum() { return checksum; }
    public Long getSizeBytes() { return sizeBytes; }
    public ContentType getContentType() { return contentType; }

    // Setters
    public void setManifest(CoursePackageManifest manifest) { this.manifest = manifest; }
}
