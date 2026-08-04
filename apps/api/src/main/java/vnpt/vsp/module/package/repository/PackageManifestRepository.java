package vnpt.vsp.module.pkg.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.pkg.entity.CoursePackageManifest;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for CoursePackageManifest entities.
 *
 * Provides queries for manifest discovery per Story 4.1 PKG-CONTRACT-2.
 */
@Repository
public interface PackageManifestRepository extends JpaRepository<CoursePackageManifest, UUID> {

    /**
     * Find a specific manifest by course and version.
     */
    Optional<CoursePackageManifest> findByCourseIdAndVersion(Long courseId, String version);

    /**
     * Find the currently active manifest for a course (most recent effectiveFrom before now).
     */
    @Query("SELECT m FROM CoursePackageManifest m " +
           "WHERE m.courseId = :courseId " +
           "AND m.effectiveFrom <= :now " +
           "AND (m.expiresAt IS NULL OR m.expiresAt > :now) " +
           "ORDER BY m.effectiveFrom DESC " +
           "LIMIT 1")
    Optional<CoursePackageManifest> findActiveManifest(
        @Param("courseId") Long courseId,
        @Param("now") java.time.Instant now
    );

    /**
     * Get version history for a course (all versions, newest first).
     */
    List<CoursePackageManifest> findByCourseIdOrderByVersionDesc(Long courseId);
}
