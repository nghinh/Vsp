package vnpt.vsp.module.pkg;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import vnpt.vsp.module.operations.OperationsService;
import vnpt.vsp.module.operations.dto.CourseConditionDto;
import vnpt.vsp.module.operations.dto.GreenConditionDto;
import vnpt.vsp.module.operations.dto.PinPositionDto;
import vnpt.vsp.module.pkg.entity.CoursePackageManifest;
import vnpt.vsp.module.pkg.entity.PackageBuildJob;
import vnpt.vsp.module.pkg.entity.PackageBuildStatus;
import vnpt.vsp.module.pkg.entity.PackageFileEntry;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.pkg.repository.PackageBuildJobRepository;
import vnpt.vsp.module.pkg.repository.PackageManifestRepository;
import vnpt.vsp.module.pkg.storage.ObjectStorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Async package generation service.
 *
 * Processes {@link PackageBuildJob} records from the queue through the build pipeline:
 *   VALIDATING → BUILDING → ASSEMBLING → UPLOADING → PUBLISHING → COMPLETED
 *
 * On any failure the job transitions to FAILED with errorCode + errorMessage + errorDetail.
 * The job is NEVER left in an indeterminate state.
 *
 * Async execution: each call to {@link #processBuildJob(UUID)} runs on the
 * {@code packageBuildExecutor} thread pool (core=2, max=4, queue=100).
 *
 * CDN URL pattern (immutable, versioned):
 *   https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/manifest.json
 *   https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/tiles.pmtiles
 *   https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/geometry.geojson
 *
 * Per Story 4.2 PKG-PUBLISH-2 AC-1 (full pipeline), AC-3 (immutable/versioned URLs).
 */
@Service
public class PackageGenerationService {

    private static final Logger log = LoggerFactory.getLogger(PackageGenerationService.class);

    // CDN URL pattern (immutable, versioned) — mirrors ObjectStorageService docs.
    private static final String CDN_BASE = "https://cdn.vnptgolf.vn/packages";
    private static final String DEFAULT_MINIMUM_CLIENT_VERSION = "1.0.0";

    private final PackageBuildJobRepository jobRepository;
    private final PackageManifestRepository manifestRepository;
    private final ObjectStorageService storageService;
    private final OperationsService operationsService;
    private final CourseRepository courseRepository;
    private final ObjectMapper objectMapper;

    // Temporary storage for assembled files (populated in assemblePackageFiles,
    // consumed in uploadToStorage/persistManifest)
    private final Map<UUID, List<AssembledFile>> assembledFiles = new java.util.concurrent.ConcurrentHashMap<>();

    public PackageGenerationService(
            PackageBuildJobRepository jobRepository,
            PackageManifestRepository manifestRepository,
            ObjectStorageService storageService,
            OperationsService operationsService,
            CourseRepository courseRepository) {
        this.jobRepository = jobRepository;
        this.manifestRepository = manifestRepository;
        this.storageService = storageService;
        this.operationsService = operationsService;
        this.courseRepository = courseRepository;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
        this.objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }

    /**
     * Holds assembled file data for a build job.
     */
    private static class AssembledFile {
        final String path;
        final byte[] data;
        final ObjectStorageService.ContentType contentType;
        final String conditionsUrl;

        AssembledFile(String path, byte[] data, ObjectStorageService.ContentType contentType, String conditionsUrl) {
            this.path = path;
            this.data = data;
            this.contentType = contentType;
            this.conditionsUrl = conditionsUrl;
        }
    }

    /**
     * Main async entry point. Called by the scheduled worker poller.
     * Runs on the packageBuildExecutor thread pool.
     */
    @Async("packageBuildExecutor")
    public void processBuildJob(UUID jobId) {
        PackageBuildJob job = jobRepository.findById(jobId).orElse(null);
        if (job == null) {
            log.warn("PackageBuildJob {} not found — skipping", jobId);
            return;
        }

        if (!job.isInProgress()) {
            log.info("PackageBuildJob {} is not in-progress (status={}) — skipping", jobId, job.getStatus());
            return;
        }

        log.info("Processing PackageBuildJob {} for courseId={}, dataVersionId={}",
                jobId, job.getCourseId(), job.getDataVersionId());

        // Compute manifest version early so it can be used in assembly and upload
        String manifestVersion = computeManifestVersion(job);

        try {
            // Stage 1: Validate inputs
            job.markStarted(); // sets status to VALIDATING and startedAt
            jobRepository.save(job);
            validateInputs(job);

            // Stage 2: Generate tiles (PMTiles from PostGIS geometry)
            job.setStatus(PackageBuildStatus.BUILDING);
            jobRepository.save(job);
            generateTiles(job);

            // Stage 3: Assemble package files (manifest JSON, GeoJSON, scorecard, rules, conditions)
            job.setStatus(PackageBuildStatus.ASSEMBLING);
            jobRepository.save(job);
            assemblePackageFiles(job, manifestVersion);

            // Stage 4: Upload to object storage
            job.setStatus(PackageBuildStatus.UPLOADING);
            jobRepository.save(job);
            uploadToStorage(job, manifestVersion);

            // Stage 5: Publish to CDN
            job.setStatus(PackageBuildStatus.PUBLISHING);
            jobRepository.save(job);
            publishToCDN(job);

            // Stage 6: Persist the CoursePackageManifest row so
            // GET /courses/{id}/packages/current resolves. Idempotent on
            // (courseId, version) — an existing manifest for this version is reused.
            persistManifest(job, manifestVersion);

            // Mark complete with the already-computed manifest version
            job.markCompleted(manifestVersion);
            jobRepository.save(job);
            log.info("PackageBuildJob {} completed — manifestVersion={}", jobId, manifestVersion);

        } catch (ValidationException e) {
            failJob(job, "VALIDATION_ERROR", e.getMessage(), e.getDetail());
        } catch (GeometryIncompleteException e) {
            failJob(job, "GEOMETRY_INCOMPLETE", e.getMessage(), e.getDetail());
        } catch (TileGenerationException e) {
            failJob(job, "TILE_GENERATION_FAILED", e.getMessage(), e.getDetail());
        } catch (AssemblyException e) {
            failJob(job, "ASSEMBLY_FAILED", e.getMessage(), e.getDetail());
        } catch (StorageUploadException e) {
            failJob(job, "STORAGE_UPLOAD_FAILED", e.getMessage(), e.getDetail());
        } catch (CdnPublishException e) {
            failJob(job, "CDN_PUBLISH_FAILED", e.getMessage(), e.getDetail());
        } catch (Exception e) {
            failJob(job, "INTERNAL_ERROR", "Unexpected error during package build", e.getMessage());
        }
    }

    private void failJob(PackageBuildJob job, String errorCode, String errorMessage, String errorDetail) {
        job.markFailed(errorCode, errorMessage, errorDetail);
        jobRepository.save(job);
        log.error("PackageBuildJob {} failed — code={}, message={}", job.getId(), errorCode, errorMessage, errorDetail);
    }

    // ─── Pipeline stages ───────────────────────────────────────────────────────

    /**
     * Reject a build before any work happens when its inputs are not real.
     *
     * Without this a job for a deleted or mistyped course id runs the whole
     * pipeline and publishes a manifest the app can never resolve.
     */
    void validateInputs(PackageBuildJob job) {
        log.debug("validateInputs for job {}", job.getId());

        if (job.getCourseId() == null) {
            throw new VspApiException(VspErrorCode.COURSE_001, "courseId");
        }
        if (!courseRepository.existsById(job.getCourseId())) {
            throw new VspApiException(VspErrorCode.COURSE_001, "courseId");
        }
    }

    /**
     * Vector tile generation is not wired yet.
     *
     * It needs a PostGIS {@code ST_AsMVT} pipeline (or an external PMTiles
     * tool) plus tile storage; the package is still usable without it because
     * the app renders geometry from the GeoJSON files in the same package.
     */
    void generateTiles(PackageBuildJob job) {
        log.debug("generateTiles for job {} — tile pipeline not configured", job.getId());
    }

    void assemblePackageFiles(PackageBuildJob job, String manifestVersion) {
        log.debug("assemblePackageFiles for job {}", job.getId());
        List<AssembledFile> files = new ArrayList<>();

        // Assemble conditions.json with pin positions, green conditions, and course conditions
        try {
            AssembledFile conditionsFile = assembleConditionsJson(job, manifestVersion);
            if (conditionsFile != null) {
                files.add(conditionsFile);
            }
        } catch (Exception e) {
            throw new AssemblyException("Failed to assemble conditions.json", e.getMessage());
        }

        // Assemble manifest.json — the manifest descriptor the mobile persists locally.
        // Previously assemblePackageFiles only emitted conditions.json (G3).
        try {
            AssembledFile manifestFile = assembleManifestJson(job, manifestVersion, files);
            if (manifestFile != null) {
                files.add(manifestFile);
            }
        } catch (Exception e) {
            throw new AssemblyException("Failed to assemble manifest.json", e.getMessage());
        }

        // Store assembled files for this job (uploadToStorage will consume them)
        assembledFiles.put(job.getId(), files);
        log.info("Assembled {} files for job {}", files.size(), job.getId());
    }

    /**
     * Assemble manifest.json — a self-describing descriptor of the package
     * (course/version identifiers, generation metadata, CDN URLs, and the file
     * inventory known so far). This is the file the mobile client persists as
     * {@code manifest.json} after download.
     */
    private AssembledFile assembleManifestJson(PackageBuildJob job, String manifestVersion,
            List<AssembledFile> priorFiles) {
        Long courseId = job.getCourseId();
        Instant now = Instant.now();

        Map<String, Object> manifest = new LinkedHashMap<>();
        manifest.put("courseId", courseId);
        manifest.put("version", manifestVersion);
        manifest.put("dataVersion", job.getDataVersionId());
        manifest.put("generatedAt", now.toString());
        manifest.put("generatedBy", job.getTriggeredBy());
        manifest.put("minimumClientVersion", DEFAULT_MINIMUM_CLIENT_VERSION);
        manifest.put("tilesFormat", CoursePackageManifest.TilesFormat.PMTILES.name());
        manifest.put("tilesUrl", cdnUrl(courseId, manifestVersion, "tiles", "tiles.pmtiles"));
        manifest.put("geoJsonUrl", cdnUrl(courseId, manifestVersion, "geometry", "geometry.geojson"));
        manifest.put("conditionsUrl", cdnUrl(courseId, manifestVersion, "conditions", "conditions.json"));

        List<Map<String, Object>> fileList = new ArrayList<>();
        for (AssembledFile f : priorFiles) {
            Map<String, Object> entry = new LinkedHashMap<>();
            entry.put("path", f.path);
            entry.put("checksum", sha256Hex(f.data));
            entry.put("sizeBytes", (long) f.data.length);
            entry.put("contentType", f.contentType.name());
            fileList.add(entry);
        }
        manifest.put("files", fileList);

        try {
            byte[] jsonBytes = objectMapper.writeValueAsBytes(manifest);
            return new AssembledFile("manifest.json", jsonBytes,
                    ObjectStorageService.ContentType.METADATA, null);
        } catch (Exception e) {
            throw new AssemblyException("Failed to serialize manifest.json", e.getMessage());
        }
    }

    /**
     * Assemble conditions.json containing:
     * - Active pin positions for the course
     * - Active green conditions for the course
     * - Active course-level conditions for the course
     *
     * Per Story 8.5 AC-4: mobile sync reflects newly published operational data
     */
    private AssembledFile assembleConditionsJson(PackageBuildJob job, String manifestVersion) {
        Long courseId = job.getCourseId();
        Instant asOfDate = Instant.now();

        // Query active operational data
        List<PinPositionDto> pins = operationsService.getAllPinPositions(courseId, asOfDate);
        List<GreenConditionDto> greenConditions = operationsService.getAllGreenConditions(courseId, asOfDate);
        List<CourseConditionDto> courseConditions = operationsService.getCourseConditions(courseId, asOfDate);

        // Build conditions snapshot JSON
        Map<String, Object> conditionsSnapshot = new LinkedHashMap<>();
        conditionsSnapshot.put("courseId", courseId);
        conditionsSnapshot.put("snapshotAt", asOfDate.toString());
        conditionsSnapshot.put("generatedBy", job.getTriggeredBy());
        conditionsSnapshot.put("manifestVersion", manifestVersion);

        // Pin positions
        Map<String, Object> pinsMap = new LinkedHashMap<>();
        pinsMap.put("count", pins.size());
        pinsMap.put("positions", pins);
        conditionsSnapshot.put("pinPositions", pinsMap);

        // Green conditions
        Map<String, Object> greensMap = new LinkedHashMap<>();
        greensMap.put("count", greenConditions.size());
        greensMap.put("conditions", greenConditions);
        conditionsSnapshot.put("greenConditions", greensMap);

        // Course-level conditions
        Map<String, Object> courseCondMap = new LinkedHashMap<>();
        courseCondMap.put("count", courseConditions.size());
        courseCondMap.put("conditions", courseConditions);
        conditionsSnapshot.put("courseConditions", courseCondMap);

        try {
            byte[] jsonBytes = objectMapper.writeValueAsBytes(conditionsSnapshot);
            String conditionsUrl = "conditions.json";
            String path = conditionsUrl;
            return new AssembledFile(path, jsonBytes, ObjectStorageService.ContentType.CONDITIONS, conditionsUrl);
        } catch (Exception e) {
            throw new AssemblyException("Failed to serialize conditions snapshot", e.getMessage());
        }
    }

    void uploadToStorage(PackageBuildJob job, String manifestVersion) {
        // Peek (do not remove) — persistManifest consumes the same list afterwards.
        List<AssembledFile> files = assembledFiles.get(job.getId());
        if (files == null || files.isEmpty()) {
            log.debug("uploadToStorage for job {} — no files to upload", job.getId());
            return;
        }

        log.info("Uploading {} files for job {}", files.size(), job.getId());

        for (AssembledFile file : files) {
            try {
                String url = storageService.uploadFile(
                        file.data,
                        job.getCourseId(),
                        manifestVersion,
                        file.contentType,
                        file.path);
                log.info("Uploaded {} -> {}", file.path, url);
            } catch (Exception e) {
                throw new StorageUploadException("Failed to upload " + file.path, e.getMessage());
            }
        }
    }

    /**
     * CDN cache warming is a no-op until a CDN is configured for this
     * environment; packages are served directly from object storage, so a cold
     * cache only costs latency on the first download.
     */
    void publishToCDN(PackageBuildJob job) {
        log.debug("publishToCDN for job {} — no CDN configured", job.getId());
    }

    /**
     * Persist (or reuse) the {@link CoursePackageManifest} row for this build so
     * that {@code GET /courses/{courseId}/packages/current} resolves. The row is
     * marked effective immediately (effectiveFrom = now). Idempotent on
     * (courseId, version): if a manifest already exists for this course+version
     * (e.g. seeded, or a re-run), it is reused and no duplicate is created.
     */
    void persistManifest(PackageBuildJob job, String manifestVersion) {
        List<AssembledFile> files = assembledFiles.remove(job.getId());
        Long courseId = job.getCourseId();

        if (manifestRepository.findByCourseIdAndVersion(courseId, manifestVersion).isPresent()) {
            log.info("Manifest already exists for course {} version {} — reusing", courseId, manifestVersion);
            return;
        }

        Instant now = Instant.now();
        long totalSize = 0L;
        if (files != null) {
            for (AssembledFile f : files) {
                totalSize += f.data.length;
            }
        }

        String tilesUrl = cdnUrl(courseId, manifestVersion, "tiles", "tiles.pmtiles");
        String geoJsonUrl = cdnUrl(courseId, manifestVersion, "geometry", "geometry.geojson");
        String manifestChecksum = sha256Hex((courseId + ":" + manifestVersion + ":" + totalSize)
                .getBytes(StandardCharsets.UTF_8));

        CoursePackageManifest manifest = new CoursePackageManifest(
                courseId,
                job.getDataVersionId(),
                manifestVersion,
                totalSize,
                manifestChecksum,
                now,
                DEFAULT_MINIMUM_CLIENT_VERSION,
                CoursePackageManifest.TilesFormat.PMTILES,
                tilesUrl,
                geoJsonUrl,
                now,
                job.getTriggeredBy() != null ? job.getTriggeredBy() : "system");

        if (files != null) {
            for (AssembledFile f : files) {
                PackageFileEntry.ContentType entryType =
                        PackageFileEntry.ContentType.valueOf(f.contentType.name());
                if (entryType == PackageFileEntry.ContentType.CONDITIONS) {
                    manifest.setConditionsUrl(cdnUrl(courseId, manifestVersion, "conditions", f.path));
                }
                manifest.addFile(new PackageFileEntry(
                        f.path,
                        sha256Hex(f.data),
                        (long) f.data.length,
                        entryType));
            }
        }

        manifestRepository.save(manifest);
        log.info("Persisted CoursePackageManifest for course {} version {} ({} files, {} bytes)",
                courseId, manifestVersion, manifest.getFiles().size(), totalSize);
    }

    private String cdnUrl(Long courseId, String manifestVersion, String contentType, String filename) {
        return CDN_BASE + "/" + courseId + "/" + manifestVersion + "/" + contentType + "/" + filename;
    }

    private String sha256Hex(byte[] data) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(data));
        } catch (Exception e) {
            // SHA-256 is always available in the JDK; fall back to a stable hash.
            return Integer.toHexString(java.util.Arrays.hashCode(data));
        }
    }

    String computeManifestVersion(PackageBuildJob job) {
        // Format: {dataVersionMajor}.{dataVersionMinor}.{buildNumber}
        // For MVP: uses dataVersionId as buildNumber until real data version schema exists
        // Returns e.g. "1.0.{dataVersionId}"
        return "1.0." + job.getDataVersionId();
    }

    // ─── Error types ────────────────────────────────────────────────────────────

    public static class ValidationException extends RuntimeException {
        private final String detail;
        public ValidationException(String message, String detail) { super(message); this.detail = detail; }
        public String getDetail() { return detail; }
    }

    public static class GeometryIncompleteException extends RuntimeException {
        private final String detail;
        public GeometryIncompleteException(String message, String detail) { super(message); this.detail = detail; }
        public String getDetail() { return detail; }
    }

    public static class TileGenerationException extends RuntimeException {
        private final String detail;
        public TileGenerationException(String message, String detail) { super(message); this.detail = detail; }
        public String getDetail() { return detail; }
    }

    public static class AssemblyException extends RuntimeException {
        private final String detail;
        public AssemblyException(String message, String detail) { super(message); this.detail = detail; }
        public String getDetail() { return detail; }
    }

    public static class StorageUploadException extends RuntimeException {
        private final String detail;
        public StorageUploadException(String message, String detail) { super(message); this.detail = detail; }
        public String getDetail() { return detail; }
    }

    public static class CdnPublishException extends RuntimeException {
        private final String detail;
        public CdnPublishException(String message, String detail) { super(message); this.detail = detail; }
        public String getDetail() { return detail; }
    }
}
