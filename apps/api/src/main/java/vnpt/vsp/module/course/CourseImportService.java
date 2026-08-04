package vnpt.vsp.module.course;

import vnpt.vsp.module.course.dto.ImportPreviewDto;
import vnpt.vsp.module.course.dto.ImportResultDto;

/**
 * Service interface for GeoJSON course data import.
 * Per Story 3.4 AC-1, AC-2, AC-3.
 */
public interface CourseImportService {

    /**
     * Preview a GeoJSON import without persisting.
     * Validates all features and returns error summary.
     *
     * @param courseId the course ID
     * @param geoJson the GeoJSON string
     * @param source the data source (e.g., provider name)
     * @param license the data license
     * @param uploaderId the ID of the admin user uploading
     * @return preview with error summary and a preview token
     */
    ImportPreviewDto previewImport(Long courseId, String geoJson, String source, String license, String uploaderId);

    /**
     * Commit a previously validated import.
     * Persists all validated features under a new DRAFT DataVersion.
     *
     * @param courseId the course ID
     * @param previewToken the token from previewImport
     * @param uploaderId the ID of the admin user committing
     * @return result with new DataVersion ID and feature count
     */
    ImportResultDto commitImport(Long courseId, String previewToken, String uploaderId);
}
