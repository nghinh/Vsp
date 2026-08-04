package vnpt.vsp.module.course;

import vnpt.vsp.module.course.dto.VersionDiff;

/**
 * Service for generating diffs between draft and published course data versions.
 *
 * Compares entities by type (tees, fairways, greens, bunkers, water, OB, landmarks, pins, conditions)
 * and tracks field-level changes (geometry, metadata, effective dates).
 * Per Story 8.3 AC-2.
 */
public interface VersionDiffService {

    /**
     * Generate a diff between a draft version and the latest published version for the same course.
     *
     * @param draftVersionId the draft DataVersion ID
     * @return VersionDiff with added, removed, and changed entries
     */
    VersionDiff generateDiff(Long draftVersionId);
}
