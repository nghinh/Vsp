package vnpt.vsp.api.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.course.CourseImportService;
import vnpt.vsp.module.course.dto.ImportPreviewDto;
import vnpt.vsp.module.course.dto.ImportResultDto;

/**
 * REST controller for GeoJSON course data import.
 * Per Story 3.4 AC-1, AC-2, AC-3.
 *
 * <p>Importing replaces a course's geometry wholesale, so it takes the same
 * roles as the rest of course editing. This class carried no authorization
 * check of any kind until the {@code /admin/**} chain was repaired, which had
 * been hiding that.</p>
 */
@RestController
@RequestMapping("/admin/courses")
@PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
public class CourseImportController {

    private static final Logger log = LoggerFactory.getLogger(CourseImportController.class);

    private final CourseImportService courseImportService;

    public CourseImportController(CourseImportService courseImportService) {
        this.courseImportService = courseImportService;
    }

    /**
     * Preview a GeoJSON import without persisting.
     * Validates all features and returns actionable errors per feature.
     *
     * @param courseId the course ID
     * @param geoJson the GeoJSON string
     * @param source the data source
     * @param license the data license
     * @param userDetails authenticated admin user
     * @return preview with error summary and preview token
     */
    @PostMapping("/{courseId}/import/preview")
    public ResponseEntity<ImportPreviewDto> previewImport(
            @PathVariable Long courseId,
            @RequestBody GeoJsonImportRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        String uploaderId = userDetails != null ? userDetails.getUsername() : "system";

        log.info("action=PREVIEW_IMPORT courseId={} uploaderId={}", courseId, uploaderId);

        ImportPreviewDto preview = courseImportService.previewImport(
            courseId,
            request.getGeoJson(),
            request.getSource(),
            request.getLicense(),
            uploaderId
        );

        return ResponseEntity.ok(preview);
    }

    /**
     * Commit a previously validated import.
     * Persists all validated features under a new DRAFT DataVersion.
     *
     * @param courseId the course ID
     * @param request the commit request containing previewToken
     * @param userDetails authenticated admin user
     * @return result with new DataVersion ID and feature count
     */
    @PostMapping("/{courseId}/import/commit")
    public ResponseEntity<ImportResultDto> commitImport(
            @PathVariable Long courseId,
            @RequestBody ImportCommitRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        String uploaderId = userDetails != null ? userDetails.getUsername() : "system";

        log.info("action=COMMIT_IMPORT courseId={} previewToken={} uploaderId={}",
            courseId, request.getPreviewToken(), uploaderId);

        ImportResultDto result = courseImportService.commitImport(
            courseId,
            request.getPreviewToken(),
            uploaderId
        );

        return ResponseEntity.ok(result);
    }

    /**
     * Request body for GeoJSON import preview.
     */
    public static class GeoJsonImportRequest {
        private String geoJson;
        private String source;
        private String license;

        public String getGeoJson() { return geoJson; }
        public void setGeoJson(String geoJson) { this.geoJson = geoJson; }
        public String getSource() { return source; }
        public void setSource(String source) { this.source = source; }
        public String getLicense() { return license; }
        public void setLicense(String license) { this.license = license; }
    }

    /**
     * Request body for importing commit.
     */
    public static class ImportCommitRequest {
        private String previewToken;

        public String getPreviewToken() { return previewToken; }
        public void setPreviewToken(String previewToken) { this.previewToken = previewToken; }
    }
}
