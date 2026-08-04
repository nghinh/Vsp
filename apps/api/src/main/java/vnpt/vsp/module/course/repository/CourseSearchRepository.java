package vnpt.vsp.module.course.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.Course;

import java.util.List;

/**
 * Course search repository — text search and nearby (PostGIS ST_DWithin) queries.
 * Per Story 3.2 SD-BACK-1: AC-1 (text + geographic filters), AC-2 (GIST-indexed ST_DWithin).
 *
 * <p>Text search via JPQL across facility name, course name, and facility address.
 * Nearby search via native PostGIS query using ST_DWithin with GIST-indexed location column.</p>
 */
@Repository
public interface CourseSearchRepository extends JpaRepository<Course, Long> {

    // ─── Text Search ────────────────────────────────────────────────────────

    /**
     * Text search across facility name, course name, and facility address.
     * Case-insensitive partial match on all fields.
     * Per Story 3.2 AC-1.
     */
    @Query("""
        SELECT c FROM Course c
        JOIN FETCH c.facility f
        WHERE LOWER(f.name) LIKE LOWER(CONCAT('%', :query, '%'))
           OR LOWER(c.name) LIKE LOWER(CONCAT('%', :query, '%'))
           OR LOWER(f.address) LIKE LOWER(CONCAT('%', :query, '%'))
        """)
    Page<Course> searchByText(@Param("query") String query, Pageable pageable);

    // ─── Nearby Search ──────────────────────────────────────────────────────

    /**
     * Find course IDs and distances within a radius using PostGIS ST_DWithin.
     * Uses the GIST spatial index on golf_facilities.location.
     * Returns Object[]: [courseId (Long), distanceMeters (BigDecimal)].
     * Per Story 3.2 AC-2: GIST-indexed ST_DWithin.
     *
     * <p>ST_DWithin with geography cast gives accurate meter-based distance filtering.
     * Results ordered by distance ASC.</p>
     */
    @Query(value = """
        SELECT c.id AS course_id,
               ST_Distance(
                   f.location::geometry,
                   ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
               ) AS distance_meters
        FROM courses c
        JOIN golf_facilities f ON c.facility_id = f.id
        WHERE ST_DWithin(
            f.location::geometry,
            ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
            :radiusMeters
        )
        ORDER BY distance_meters ASC
        """, nativeQuery = true)
    List<Object[]> findNearbyCourseIdsAndDistances(
        @Param("lat") double lat,
        @Param("lng") double lng,
        @Param("radiusMeters") double radiusMeters,
        Pageable pageable
    );

    // ─── Combined Search ───────────────────────────────────────────────────

    /**
     * Combined text + nearby search — returns course IDs and distances.
     * Applies both text filter and geographic filter in a single query.
     * Returns Object[]: [courseId (Long), distanceMeters (BigDecimal)].
     * Per Story 3.2 AC-1.
     */
    @Query(value = """
        SELECT c.id AS course_id,
               ST_Distance(
                   f.location::geometry,
                   ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
               ) AS distance_meters
        FROM courses c
        JOIN golf_facilities f ON c.facility_id = f.id
        WHERE ST_DWithin(
            f.location::geometry,
            ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
            :radiusMeters
        )
        AND (
            LOWER(f.name) LIKE LOWER(CONCAT('%', :textQuery, '%'))
            OR LOWER(c.name) LIKE LOWER(CONCAT('%', :textQuery, '%'))
            OR LOWER(f.address) LIKE LOWER(CONCAT('%', :textQuery, '%'))
        )
        ORDER BY distance_meters ASC
        """, nativeQuery = true)
    List<Object[]> findNearbyCourseIdsAndDistancesWithText(
        @Param("lat") double lat,
        @Param("lng") double lng,
        @Param("radiusMeters") double radiusMeters,
        @Param("textQuery") String textQuery,
        Pageable pageable
    );
}
