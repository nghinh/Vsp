package vnpt.vsp.module.course;

import vnpt.vsp.module.course.dto.ValidationResponse;

/**
 * Pre-publish validation service for course data versions.
 *
 * Validates a draft DataVersion before it can be published:
 * - Geometry validity via PostGIS ST_IsValid
 * - Required metadata fields (source, license) present on all entities
 * - Data quality class >= D (per PRD §9.4)
 *
 * Per Story 8.3 AC-1.
 */
public interface ValidationService {

    /**
     * Validate a draft DataVersion for publish eligibility.
     *
     * Checks performed:
     * 1. Geometry validity (ST_IsValid) on all geometry entities for the course
     * 2. Required metadata fields (source, license) are non-null on all entities
     * 3. Data quality class >= D (per PRD §9.4; D is the minimum allowed)
     *
     * @param versionId the DataVersion ID to validate
     * @return ValidationResponse with overall result, blocking errors, and non-blocking warnings
     */
    ValidationResponse validateForPublish(Long versionId);
}
