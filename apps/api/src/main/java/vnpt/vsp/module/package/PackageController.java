package vnpt.vsp.module.pkg;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.GolfFacilityRepository;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * REST controller for course package manifest endpoints.
 *
 * Exposes:
 * - GET /courses/{courseId}/packages/current — get current active manifest with ETag
 * - GET /courses/{courseId}/packages/{version} — get manifest by version with ETag
 * - GET /courses/{courseId}/packages/{version}/files — list file inventory
 *
 * Implements Story 4.4 INC-BACKEND:
 * - ETag computation: SHA-256(courseId + ";" + version + ";" + generatedAt)
 * - Conditional fetch: If-None-Match header → 304 Not Modified when ETag matches
 * - Per-file metadata endpoint for mobile delta computation
 *
 * NOTE on the "package" vs "pkg" naming (G3): there is exactly one manifest
 * entity, {@link vnpt.vsp.module.pkg.entity.CoursePackageManifest}. Its source
 * lives under the physical directory {@code module/package/} (the word
 * {@code package} is a Java reserved keyword and cannot be a package identifier),
 * while every file inside declares the Java package {@code vnpt.vsp.module.pkg}.
 * The compiler keys off the declared package, so all classes compile to
 * {@code vnpt.vsp.module.pkg.*}. The apparent "module.package.entity vs
 * module.pkg.entity duplication" is a directory-name-vs-package-name artifact,
 * NOT two classes — this controller and the whole module consistently use
 * {@code pkg}.
 */
@RestController
@RequestMapping("/courses/{courseId}/packages")
public class PackageController {

    private final PackageService packageService;
    private final CourseRepository courseRepository;
    private final GolfFacilityRepository facilityRepository;

    public PackageController(PackageService packageService,
                             CourseRepository courseRepository,
                             GolfFacilityRepository facilityRepository) {
        this.packageService = packageService;
        this.courseRepository = courseRepository;
        this.facilityRepository = facilityRepository;
    }

    /**
     * Get the currently active manifest for a course.
     *
     * Supports conditional fetch via If-None-Match header.
     * Returns ETag header computed as SHA-256(courseId + ";" + version + ";" + generatedAt).
     * Returns 304 Not Modified when client already has the latest version.
     */
    @GetMapping("/current")
    public ResponseEntity<CoursePackageManifestDto> getCurrentManifest(
            @PathVariable Long courseId,
            @RequestHeader(value = "If-None-Match", required = false) String ifNoneMatch) {

        Optional<vnpt.vsp.module.pkg.entity.CoursePackageManifest> manifestOpt =
                packageService.getActiveManifest(courseId);

        if (manifestOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        vnpt.vsp.module.pkg.entity.CoursePackageManifest manifest = manifestOpt.get();
        String etag = computeEtag(manifest);

        // Conditional fetch: if client ETag matches current ETag, return 304
        if (ifNoneMatch != null && ifNoneMatch.equals(etag)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).build();
        }

        return ResponseEntity.ok()
                .eTag(etag)
                .body(toDto(manifest));
    }

    /**
     * Get a specific manifest by version.
     *
     * Supports conditional fetch via If-None-Match header.
     */
    @GetMapping("/{version}")
    public ResponseEntity<CoursePackageManifestDto> getManifestByVersion(
            @PathVariable Long courseId,
            @PathVariable String version,
            @RequestHeader(value = "If-None-Match", required = false) String ifNoneMatch) {

        List<vnpt.vsp.module.pkg.entity.CoursePackageManifest> history =
                packageService.getManifestHistory(courseId);

        Optional<vnpt.vsp.module.pkg.entity.CoursePackageManifest> manifestOpt = history.stream()
                .filter(m -> m.getVersion().equals(version))
                .findFirst();

        if (manifestOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        vnpt.vsp.module.pkg.entity.CoursePackageManifest manifest = manifestOpt.get();
        String etag = computeEtag(manifest);

        // Conditional fetch: if client ETag matches current ETag, return 304
        if (ifNoneMatch != null && ifNoneMatch.equals(etag)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).build();
        }

        return ResponseEntity.ok()
                .eTag(etag)
                .body(toDto(manifest));
    }

    /**
     * List all file entries for a package manifest.
     *
     * Returns per-file metadata (path, checksum, sizeBytes, contentType)
     * enabling mobile to diff and compute delta for incremental updates.
     */
    @GetMapping("/{version}/files")
    public ResponseEntity<PackageFilesResponse> listPackageFiles(
            @PathVariable Long courseId,
            @PathVariable String version) {

        List<vnpt.vsp.module.pkg.entity.CoursePackageManifest> history =
                packageService.getManifestHistory(courseId);

        Optional<vnpt.vsp.module.pkg.entity.CoursePackageManifest> manifestOpt = history.stream()
                .filter(m -> m.getVersion().equals(version))
                .findFirst();

        if (manifestOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        vnpt.vsp.module.pkg.entity.CoursePackageManifest manifest = manifestOpt.get();

        List<PackageFileEntryDto> files = manifest.getFiles().stream()
                .map(this::toFileDto)
                .collect(Collectors.toList());

        return ResponseEntity.ok(new PackageFilesResponse(files, manifest.getVersion()));
    }

    // ─── ETag computation ───────────────────────────────────────────────────────

    /**
     * Compute ETag for a manifest.
     *
     * ETag = SHA-256(courseId + ";" + version + ";" + generatedAt.toIso8601String())
     * Stable across requests — only changes when manifest content changes.
     */
    String computeEtag(vnpt.vsp.module.pkg.entity.CoursePackageManifest manifest) {
        String input = manifest.getCourseId() + ";"
                + manifest.getVersion() + ";"
                + manifest.getGeneratedAt().toString();
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            // SHA-256 is always available in Java; fall back to identity hash
            return String.valueOf(input.hashCode());
        }
    }

    // ─── DTOs ─────────────────────────────────────────────────────────────────

    private CoursePackageManifestDto toDto(vnpt.vsp.module.pkg.entity.CoursePackageManifest manifest) {
        // Optional facility/course descriptor fields (G3): populated at request time
        // from the course + facility so offline nearby/hole detection has facility
        // coordinates and human-readable names without persisting them on the manifest.
        String facilityId = null;
        String facilityName = null;
        String facilityAddress = null;
        Double facilityLatitude = null;
        Double facilityLongitude = null;
        String courseName = null;
        Integer holesCount = null;
        Integer parTotal = null;

        Course course = courseRepository.findById(manifest.getCourseId()).orElse(null);
        if (course != null) {
            courseName = course.getName();
            holesCount = course.getHolesCount();
            parTotal = course.getParTotal();
            GolfFacility facility = course.getFacility();
            if (facility != null && facility.getId() != null) {
                Long fid = facility.getId();
                facilityId = fid.toString();
                facilityName = facility.getName();
                facilityAddress = facility.getAddress();
                // Geometry columns are extracted via PostGIS ST_X/ST_Y (WGS84 lng/lat).
                facilityLatitude = facilityRepository.findLatitudeByFacilityId(fid);
                facilityLongitude = facilityRepository.findLongitudeByFacilityId(fid);
            }
        }

        return new CoursePackageManifestDto(
                manifest.getId().toString(),
                manifest.getCourseId().toString(),
                manifest.getVersion(),
                manifest.getEffectiveFrom(),
                manifest.getExpiresAt(),
                manifest.getChecksum(),
                manifest.getPackageSizeBytes(),
                manifest.getTilesFormat().name(),
                manifest.getTilesUrl(),
                manifest.getGeoJsonUrl(),
                manifest.getDataVersionId() != null ? manifest.getDataVersionId().toString() : null,
                manifest.getFiles().stream().map(this::toFileDto).collect(Collectors.toList()),
                manifest.getMinimumClientVersion(),
                manifest.getLicenses().stream().map(this::toLicenseDto).collect(Collectors.toList()),
                manifest.getScorecardUrl(),
                manifest.getRulesUrl(),
                manifest.getConditionsUrl(),
                manifest.getMetadataUrl(),
                manifest.getGeneratedAt(),
                manifest.getGeneratedBy(),
                manifest.getAccuracyClass() != null ? manifest.getAccuracyClass().name() : null,
                manifest.getConfidence(),
                manifest.getPinSnapshotDate(),
                manifest.getWeatherSnapshotDate(),
                facilityId,
                facilityName,
                facilityAddress,
                facilityLatitude,
                facilityLongitude,
                courseName,
                holesCount,
                parTotal
        );
    }

    private PackageFileEntryDto toFileDto(vnpt.vsp.module.pkg.entity.PackageFileEntry file) {
        return new PackageFileEntryDto(
                file.getPath(),
                file.getChecksum(),
                file.getSizeBytes(),
                file.getContentType().name()
        );
    }

    private PackageLicenseDto toLicenseDto(vnpt.vsp.module.pkg.entity.PackageLicense license) {
        return new PackageLicenseDto(
                license.getName(),
                license.getUrl()
        );
    }

    // ─── DTO classes ───────────────────────────────────────────────────────────

    public static class PackageFileEntryDto {
        private String path;
        private String checksum;
        private Long sizeBytes;
        private String contentType;

        public PackageFileEntryDto(String path, String checksum, Long sizeBytes, String contentType) {
            this.path = path;
            this.checksum = checksum;
            this.sizeBytes = sizeBytes;
            this.contentType = contentType;
        }

        public String getPath() { return path; }
        public String getChecksum() { return checksum; }
        public Long getSizeBytes() { return sizeBytes; }
        public String getContentType() { return contentType; }
    }

    public static class PackageLicenseDto {
        private String name;
        private String url;

        public PackageLicenseDto(String name, String url) {
            this.name = name;
            this.url = url;
        }

        public String getName() { return name; }
        public String getUrl() { return url; }
    }

    public static class PackageFilesResponse {
        private List<PackageFileEntryDto> files;
        private String packageVersion;

        public PackageFilesResponse(List<PackageFileEntryDto> files, String packageVersion) {
            this.files = files;
            this.packageVersion = packageVersion;
        }

        public List<PackageFileEntryDto> getFiles() { return files; }
        public String getPackageVersion() { return packageVersion; }
    }

    public static class CoursePackageManifestDto {
        private String packageId;
        private String courseId;
        private String version;
        private Instant effectiveDate;
        private Instant expiresAt;
        private String checksum;
        private Long sizeBytes;
        private String tilesFormat;
        private String tilesUrl;
        private String geoJsonUrl;
        private String dataVersion;
        private List<PackageFileEntryDto> files;
        private String minimumClientVersion;
        private List<PackageLicenseDto> licenses;
        private String scorecardUrl;
        private String rulesUrl;
        private String conditionsUrl;
        private String metadataUrl;
        private Instant generatedAt;
        private String generatedBy;
        private String accuracyClass;
        private Double confidence;
        private Instant pinSnapshotDate;
        private Instant weatherSnapshotDate;
        // Optional facility/course descriptor fields (G3 — offline nearby/hole detection).
        private String facilityId;
        private String facilityName;
        private String facilityAddress;
        private Double facilityLatitude;
        private Double facilityLongitude;
        private String courseName;
        private Integer holesCount;
        private Integer parTotal;

        public CoursePackageManifestDto(String packageId, String courseId, String version,
                Instant effectiveDate, Instant expiresAt, String checksum, Long sizeBytes,
                String tilesFormat, String tilesUrl, String geoJsonUrl, String dataVersion,
                List<PackageFileEntryDto> files, String minimumClientVersion,
                List<PackageLicenseDto> licenses, String scorecardUrl, String rulesUrl,
                String conditionsUrl, String metadataUrl, Instant generatedAt,
                String generatedBy, String accuracyClass, Double confidence,
                Instant pinSnapshotDate, Instant weatherSnapshotDate,
                String facilityId, String facilityName, String facilityAddress,
                Double facilityLatitude, Double facilityLongitude,
                String courseName, Integer holesCount, Integer parTotal) {
            this.packageId = packageId;
            this.courseId = courseId;
            this.version = version;
            this.effectiveDate = effectiveDate;
            this.expiresAt = expiresAt;
            this.checksum = checksum;
            this.sizeBytes = sizeBytes;
            this.tilesFormat = tilesFormat;
            this.tilesUrl = tilesUrl;
            this.geoJsonUrl = geoJsonUrl;
            this.dataVersion = dataVersion;
            this.files = files;
            this.minimumClientVersion = minimumClientVersion;
            this.licenses = licenses;
            this.scorecardUrl = scorecardUrl;
            this.rulesUrl = rulesUrl;
            this.conditionsUrl = conditionsUrl;
            this.metadataUrl = metadataUrl;
            this.generatedAt = generatedAt;
            this.generatedBy = generatedBy;
            this.accuracyClass = accuracyClass;
            this.confidence = confidence;
            this.pinSnapshotDate = pinSnapshotDate;
            this.weatherSnapshotDate = weatherSnapshotDate;
            this.facilityId = facilityId;
            this.facilityName = facilityName;
            this.facilityAddress = facilityAddress;
            this.facilityLatitude = facilityLatitude;
            this.facilityLongitude = facilityLongitude;
            this.courseName = courseName;
            this.holesCount = holesCount;
            this.parTotal = parTotal;
        }

        public String getPackageId() { return packageId; }
        public String getCourseId() { return courseId; }
        public String getVersion() { return version; }
        public Instant getEffectiveDate() { return effectiveDate; }
        public Instant getExpiresAt() { return expiresAt; }
        public String getChecksum() { return checksum; }
        public Long getSizeBytes() { return sizeBytes; }
        public String getTilesFormat() { return tilesFormat; }
        public String getTilesUrl() { return tilesUrl; }
        public String getGeoJsonUrl() { return geoJsonUrl; }
        public String getDataVersion() { return dataVersion; }
        public List<PackageFileEntryDto> getFiles() { return files; }
        public String getMinimumClientVersion() { return minimumClientVersion; }
        public List<PackageLicenseDto> getLicenses() { return licenses; }
        public String getScorecardUrl() { return scorecardUrl; }
        public String getRulesUrl() { return rulesUrl; }
        public String getConditionsUrl() { return conditionsUrl; }
        public String getMetadataUrl() { return metadataUrl; }
        public Instant getGeneratedAt() { return generatedAt; }
        public String getGeneratedBy() { return generatedBy; }
        public String getAccuracyClass() { return accuracyClass; }
        public Double getConfidence() { return confidence; }
        public Instant getPinSnapshotDate() { return pinSnapshotDate; }
        public Instant getWeatherSnapshotDate() { return weatherSnapshotDate; }
        public String getFacilityId() { return facilityId; }
        public String getFacilityName() { return facilityName; }
        public String getFacilityAddress() { return facilityAddress; }
        public Double getFacilityLatitude() { return facilityLatitude; }
        public Double getFacilityLongitude() { return facilityLongitude; }
        public String getCourseName() { return courseName; }
        public Integer getHolesCount() { return holesCount; }
        public Integer getParTotal() { return parTotal; }
    }
}
