package vnpt.vsp.module.dataquality.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.dataquality.dto.StalePinProjection;
import vnpt.vsp.module.dataquality.dto.StaleGreenConditionProjection;
import vnpt.vsp.module.dataquality.dto.StaleCourseConditionProjection;
import vnpt.vsp.module.course.entity.PinPosition;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * Repository for stale record queries.
 * Per Story 9.4 AC3 and Slice Plan Wave 1.
 * Uses cache TTL (5 min) via StaleRecordService — see staleRecordService.cacheTtlMinutes.
 *
 * <p>Note: this repository aggregates queries across operations entities
 * (PinPosition, GreenCondition, CourseCondition) and course entities.
 * Spring Data JPA projection interfaces are used for result mapping.</p>
 */
@Repository
public interface StaleRecordRepository extends JpaRepository<PinPosition, Long> {

    // ─── Stale Pin Positions ────────────────────────────────────────────────

    /**
     * Find expired pin positions as of now.
     * Joins through Hole → Course → GolfFacility to allow facility/course filtering.
     */
    @Query("""
        SELECT p.id as recordId, h.id as holeId, h.holeNumber as holeNumber,
               c.id as courseId, c.name as courseName, f.id as facilityId, f.name as facilityName,
               p.expiryDate as expiredAt
        FROM CoursePinPosition p
        JOIN p.hole h
        JOIN h.course c
        JOIN c.facility f
        WHERE p.expiryDate IS NOT NULL AND p.expiryDate < :now
        AND (:facilityId IS NULL OR f.id = :facilityId)
        AND (:courseId IS NULL OR c.id = :courseId)
        ORDER BY p.expiryDate ASC
        """)
    List<StalePinProjection> findStalePinPositions(
            @Param("now") LocalDate now,
            @Param("facilityId") Long facilityId,
            @Param("courseId") Long courseId);

    // ─── Stale Green Conditions ─────────────────────────────────────────────

    /**
     * Find expired green conditions as of now.
     */
    @Query("""
        SELECT g.id as recordId, h.id as holeId, h.holeNumber as holeNumber,
               c.id as courseId, c.name as courseName, f.id as facilityId, f.name as facilityName,
               g.expiresAt as expiredAt
        FROM GreenCondition g
        JOIN g.hole h
        JOIN h.course c
        JOIN c.facility f
        WHERE g.expiresAt IS NOT NULL AND g.expiresAt < :now
        AND (:facilityId IS NULL OR f.id = :facilityId)
        AND (:courseId IS NULL OR c.id = :courseId)
        ORDER BY g.expiresAt ASC
        """)
    List<StaleGreenConditionProjection> findStaleGreenConditions(
            @Param("now") Instant now,
            @Param("facilityId") Long facilityId,
            @Param("courseId") Long courseId);

    // ─── Stale Course Conditions ────────────────────────────────────────────

    /**
     * Find expired course conditions as of now.
     */
    @Query("""
        SELECT cc.id as recordId, c.id as courseId, c.name as courseName,
               f.id as facilityId, f.name as facilityName,
               cc.expiryDate as expiredAt, cc.severity as severity
        FROM CourseDataCondition cc
        JOIN cc.course c
        JOIN c.facility f
        WHERE cc.expiryDate IS NOT NULL AND cc.expiryDate < :now
        AND (:facilityId IS NULL OR f.id = :facilityId)
        AND (:courseId IS NULL OR c.id = :courseId)
        ORDER BY cc.expiryDate ASC
        """)
    List<StaleCourseConditionProjection> findStaleCourseConditions(
            @Param("now") LocalDate now,
            @Param("facilityId") Long facilityId,
            @Param("courseId") Long courseId);
}
