package vnpt.vsp.module.dataquality.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.Course;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

/**
 * Repository for data quality metric computations.
 * Per Story 9.4 Wave 1 and Slice Plan.
 */
@Repository
public interface DataQualityRepository extends JpaRepository<Course, Long> {

    // ─── Geometry Completeness ───────────────────────────────────────────────

    /**
     * Count holes with all required geometry layers.
     * Required layers per hole: teeingGroundLocation, greenLocation,
     * ≥1 fairway segment, ≥1 green, ≥1 bunker, ≥1 water/penalty area.
     * If facilityId is non-null, restrict to that facility.
     * If courseId is non-null, restrict to that course.
     */
    @Query(value = """
        SELECT COUNT(DISTINCT h.id)
        FROM holes h
        LEFT JOIN fairway_segments fs ON fs.hole_id = h.id
        LEFT JOIN greens g ON g.hole_id = h.id
        LEFT JOIN bunkers b ON b.hole_id = h.id
        LEFT JOIN water_hazards wh ON wh.hole_id = h.id
        LEFT JOIN penalty_areas pa ON pa.hole_id = h.id
        JOIN courses c ON c.id = h.course_id
        WHERE h.teeing_ground_location IS NOT NULL
          AND h.green_location IS NOT NULL
          AND fs.id IS NOT NULL
          AND g.id IS NOT NULL
          AND b.id IS NOT NULL
          AND (wh.id IS NOT NULL OR pa.id IS NOT NULL)
          AND (:facilityId IS NULL OR c.facility_id = :facilityId)
          AND (:courseId IS NULL OR h.course_id = :courseId)
        """, nativeQuery = true)
    long countHolesWithCompleteLayers(
            @Param("facilityId") Long facilityId,
            @Param("courseId") Long courseId);

    /**
     * Count total holes. If facilityId/courseId filters are provided, they apply
     * through the same join path as countHolesWithCompleteLayers.
     */
    @Query(value = """
        SELECT COUNT(h.id)
        FROM holes h
        JOIN courses c ON c.id = h.course_id
        WHERE (:facilityId IS NULL OR c.facility_id = :facilityId)
          AND (:courseId IS NULL OR h.course_id = :courseId)
        """, nativeQuery = true)
    long countTotalHoles(
            @Param("facilityId") Long facilityId,
            @Param("courseId") Long courseId);

    // ─── Verified Courses ───────────────────────────────────────────────────

    /**
     * Count published+verified courses.
     * A course is verified when its latest published DataVersion has
     * verificationStatus = 'VERIFIED'.
     */
    @Query(value = """
        SELECT COUNT(DISTINCT c.id)
        FROM courses c
        JOIN (
            SELECT dv.course_id, dv.version_number
            FROM data_versions dv
            WHERE dv.status = 'PUBLISHED'
              AND dv.version_number = (
                  SELECT MAX(dv2.version_number)
                  FROM data_versions dv2
                  WHERE dv2.course_id = dv.course_id
                    AND dv2.status = 'PUBLISHED'
              )
        ) latest ON latest.course_id = c.id
        JOIN data_versions dv ON dv.course_id = c.id
            AND dv.version_number = latest.version_number
        WHERE dv.verification_status = 'VERIFIED'
          AND (:facilityId IS NULL OR c.facility_id = :facilityId)
        """, nativeQuery = true)
    long countVerifiedCourses(@Param("facilityId") Long facilityId);

    /**
     * Count total courses. If facilityId is provided, restrict to that facility.
     */
    @Query(value = """
        SELECT COUNT(c.id)
        FROM courses c
        WHERE (:facilityId IS NULL OR c.facility_id = :facilityId)
        """, nativeQuery = true)
    long countTotalCourses(@Param("facilityId") Long facilityId);

    // ─── Class A/B Coverage ─────────────────────────────────────────────────

    /**
     * Count courses with accuracy class A or B.
     * Accuracy class is stored in the data_versions table (per latest published version).
     */
    @Query(value = """
        SELECT COUNT(DISTINCT c.id)
        FROM courses c
        JOIN (
            SELECT dv.course_id, dv.version_number
            FROM data_versions dv
            WHERE dv.status = 'PUBLISHED'
              AND dv.version_number = (
                  SELECT MAX(dv2.version_number)
                  FROM data_versions dv2
                  WHERE dv2.course_id = dv.course_id
                    AND dv2.status = 'PUBLISHED'
              )
        ) latest ON latest.course_id = c.id
        JOIN data_versions dv ON dv.course_id = c.id
            AND dv.version_number = latest.version_number
        WHERE dv.accuracy_class IN ('A_RTK_SURVEYED', 'B_LICENSED_PROVIDER')
          AND (:facilityId IS NULL OR c.facility_id = :facilityId)
        """, nativeQuery = true)
    long countClassABCourses(@Param("facilityId") Long facilityId);

    // ─── Correction Volume ──────────────────────────────────────────────────

    /**
     * Count corrections created within a date range.
     * If courseId is provided, restrict to that course.
     * If facilityId is provided, restrict to courses in that facility.
     */
    // The table is course_corrections and the timestamp is submitted_at.
    // These three queries named `corrections` and `reported_at`, neither of
    // which exists, so every load of the data-quality dashboard 500'd on the
    // first metric — native SQL, so nothing caught it until it ran.
    @Query(value = """
        SELECT COUNT(corr.id)
        FROM course_corrections corr
        JOIN courses c ON c.id = corr.course_id
        WHERE corr.submitted_at >= :fromInstant
          AND corr.submitted_at <= :toInstant
          AND (:courseId IS NULL OR corr.course_id = :courseId)
          AND (:facilityId IS NULL OR c.facility_id = :facilityId)
        """, nativeQuery = true)
    long countCorrectionsInRange(
            @Param("fromInstant") Instant fromInstant,
            @Param("toInstant") Instant toInstant,
            @Param("courseId") Long courseId,
            @Param("facilityId") Long facilityId);

    // ─── Resolution Time ────────────────────────────────────────────────────

    /**
     * Average resolution time in seconds for resolved corrections
     * (reviewedAt - reportedAt) within the date range.
     */
    @Query(value = """
        SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (corr.reviewed_at - corr.submitted_at))), 0)
        FROM course_corrections corr
        JOIN courses c ON c.id = corr.course_id
        WHERE corr.reviewed_at IS NOT NULL
          AND corr.submitted_at >= :fromInstant
          AND corr.submitted_at <= :toInstant
          AND (:courseId IS NULL OR corr.course_id = :courseId)
          AND (:facilityId IS NULL OR c.facility_id = :facilityId)
        """, nativeQuery = true)
    double avgResolutionTimeSeconds(
            @Param("fromInstant") Instant fromInstant,
            @Param("toInstant") Instant toInstant,
            @Param("courseId") Long courseId,
            @Param("facilityId") Long facilityId);

    /**
     * List of resolution times in seconds for resolved corrections
     * (used to compute median).
     */
    @Query(value = """
        SELECT EXTRACT(EPOCH FROM (corr.reviewed_at - corr.submitted_at))
        FROM course_corrections corr
        JOIN courses c ON c.id = corr.course_id
        WHERE corr.reviewed_at IS NOT NULL
          AND corr.submitted_at >= :fromInstant
          AND corr.submitted_at <= :toInstant
          AND (:courseId IS NULL OR corr.course_id = :courseId)
          AND (:facilityId IS NULL OR c.facility_id = :facilityId)
        ORDER BY 1
        """, nativeQuery = true)
    List<Double> resolutionTimesSeconds(
            @Param("fromInstant") Instant fromInstant,
            @Param("toInstant") Instant toInstant,
            @Param("courseId") Long courseId,
            @Param("facilityId") Long facilityId);
}
