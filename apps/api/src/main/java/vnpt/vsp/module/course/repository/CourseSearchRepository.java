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
 *
 * <p>All three queries require the course to have hole rows. A course can exist
 * without them: splitting a facility into the sân or đường it really has writes
 * the names a club signs and no holes, because a hole needs a par and a par
 * nobody read off the club's card is invented. Search is where a golfer goes
 * looking for something to play, and a result that cannot be played is worse
 * than no result — its {@code holesCount} says 9 or 18 like every other, since
 * the club does have that many, so nothing on the card they are shown warns
 * them. They arrive at an empty scorecard.</p>
 *
 * <p>A course that has been retired — the seed's invented "— Championship"
 * where the club's real đường are now loaded — carries an expiry date and is
 * excluded here too. Retiring by date rather than by deleting its holes is
 * deliberate: those rows hold measured OpenStreetMap coordinates that exist on
 * no other course, and an earlier retirement that deleted them would have
 * thrown 46 surveyed points away to hide a course.</p>
 *
 * <p>Those courses are still reachable, by design: the course detail of a
 * sibling carries the whole facility's list, marked with what is playable, and
 * the scorecard screen reads it so a golfer can attach the card in their hand
 * to the đường it was printed for. That is the path that fills the holes in.</p>
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
        WHERE EXISTS (SELECT 1 FROM Hole h WHERE h.course.id = c.id)
          AND (c.metadata.expiryDate IS NULL OR c.metadata.expiryDate > CURRENT_DATE)
          AND (
            LOWER(f.name) LIKE LOWER(CONCAT('%', :query, '%'))
            OR LOWER(c.name) LIKE LOWER(CONCAT('%', :query, '%'))
            OR LOWER(f.address) LIKE LOWER(CONCAT('%', :query, '%'))
          )
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
                   CAST(f.location AS geography),
                   CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography)
               ) AS distance_meters
        FROM courses c
        JOIN golf_facilities f ON c.facility_id = f.id
        WHERE EXISTS (SELECT 1 FROM holes h WHERE h.course_id = c.id)
        AND (c.expiry_date IS NULL OR c.expiry_date > CURRENT_DATE)
        AND ST_DWithin(
            CAST(f.location AS geography),
            CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
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
                   CAST(f.location AS geography),
                   CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography)
               ) AS distance_meters
        FROM courses c
        JOIN golf_facilities f ON c.facility_id = f.id
        WHERE EXISTS (SELECT 1 FROM holes h WHERE h.course_id = c.id)
        AND (c.expiry_date IS NULL OR c.expiry_date > CURRENT_DATE)
        AND ST_DWithin(
            CAST(f.location AS geography),
            CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
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
