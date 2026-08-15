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
     * Text search across facility name, course name and address.
     *
     * <h2>Diacritics</h2>
     *
     * <p>This matched {@code LOWER(name) LIKE '%query%'}, so "Long Biên" found
     * the club and "Long Bien" found nothing at all. On a phone most people
     * type without diacritics or get half of them, which is why the same club
     * appeared and disappeared depending on how it was typed. Both sides are
     * folded through {@code unaccent} now, which handles đ → d as well.
     *
     * <h2>Word by word, in any order</h2>
     *
     * <p>The old query needed the whole phrase as one substring, so "golf long
     * bien" and "bien long" both found nothing while "long bien" worked. Every
     * word must now appear somewhere in the club's name, the course's name or
     * the address — and where is not important, which is what makes "long bien
     * golf" and "golf long bien" the same search.
     *
     * <h2>Best match first</h2>
     *
     * <p>A club whose name starts with what was typed comes before one that
     * merely contains it, which comes before a match on the course name, which
     * comes before a match only in the address. Without this, searching a
     * province returned its clubs in id order and the one being looked for was
     * as likely to be last as first.
     *
     * <h2>One row per club</h2>
     *
     * <p>Nobody types "Đường A" into a search box: they type the club and
     * choose the đường when the round starts. Searching "Long Biên" returned
     * three cards reading "Đường A", "Đường B" and "Đường C" — a search that
     * had worked and looked exactly like one that had failed.
     *
     * <p>Each club is represented by its longest course, so a resort shows its
     * championship eighteen rather than whichever nine happens to sort first,
     * and {@code courseCount} tells the app whether tapping goes straight into
     * a course or has to ask which đường.
     *
     * <p>An empty query matches everything, which is what the app asks for when
     * it opens the list.
     *
     * <p>No SQL comments in the query below. Spring Data parses the string for
     * parameters before it ever reaches the database, and an apostrophe inside
     * a {@code --} comment reads to that parser as an unterminated string
     * literal — which took the whole application down at startup, not the
     * query at runtime.
     */
    @Query(value = """
        SELECT c.* FROM courses c
        JOIN golf_facilities f ON f.id = c.facility_id
        WHERE EXISTS (SELECT 1 FROM holes h WHERE h.course_id = c.id)
          AND (c.expiry_date IS NULL OR c.expiry_date > CURRENT_DATE)
          AND NOT EXISTS (
                SELECT 1 FROM unnest(
                    string_to_array(unaccent(lower(trim(CAST(:query AS text)))), ' ')) AS token
                WHERE token <> ''
                  AND unaccent(lower(f.name || ' '
                          || coalesce((SELECT string_agg(c3.name, ' ')
                                       FROM courses c3 WHERE c3.facility_id = f.id), '')
                          || ' ' || coalesce(f.address, '')))
                      NOT LIKE '%' || token || '%'
              )
          AND c.id = (
                SELECT c2.id FROM courses c2
                WHERE c2.facility_id = f.id
                  AND EXISTS (SELECT 1 FROM holes h2 WHERE h2.course_id = c2.id)
                  AND (c2.expiry_date IS NULL OR c2.expiry_date > CURRENT_DATE)
                ORDER BY c2.holes_count DESC NULLS LAST, c2.name
                LIMIT 1)
        ORDER BY
          CASE
            WHEN unaccent(lower(f.name)) LIKE unaccent(lower(CAST(:query AS text))) || '%' THEN 0
            WHEN unaccent(lower(f.name)) LIKE '%' || unaccent(lower(CAST(:query AS text))) || '%' THEN 1
            ELSE 2
          END,
          f.name
        """,
        countQuery = """
        SELECT count(*) FROM courses c
        JOIN golf_facilities f ON f.id = c.facility_id
        WHERE EXISTS (SELECT 1 FROM holes h WHERE h.course_id = c.id)
          AND (c.expiry_date IS NULL OR c.expiry_date > CURRENT_DATE)
          AND NOT EXISTS (
                SELECT 1 FROM unnest(
                    string_to_array(unaccent(lower(trim(CAST(:query AS text)))), ' ')) AS token
                WHERE token <> ''
                  AND unaccent(lower(f.name || ' '
                          || coalesce((SELECT string_agg(c3.name, ' ')
                                       FROM courses c3 WHERE c3.facility_id = f.id), '')
                          || ' ' || coalesce(f.address, '')))
                      NOT LIKE '%' || token || '%'
              )
          AND c.id = (
                SELECT c2.id FROM courses c2
                WHERE c2.facility_id = f.id
                  AND EXISTS (SELECT 1 FROM holes h2 WHERE h2.course_id = c2.id)
                  AND (c2.expiry_date IS NULL OR c2.expiry_date > CURRENT_DATE)
                ORDER BY c2.holes_count DESC NULLS LAST, c2.name
                LIMIT 1)
        """,
        nativeQuery = true)
    Page<Course> searchByText(@Param("query") String query, Pageable pageable);

    /**
     * How many playable courses each of these clubs has.
     *
     * <p>Search returns the club, and the app needs to know whether tapping it
     * opens a course or has to ask which đường first. Fetched for the whole
     * page at once rather than per row — a query per result is the shape that
     * makes a list of twenty clubs twenty-one round trips.
     *
     * @return rows of [facilityId, count]
     */
    @Query(value = """
            SELECT c.facility_id, count(*)
            FROM courses c
            WHERE c.facility_id IN (:facilityIds)
              AND EXISTS (SELECT 1 FROM holes h WHERE h.course_id = c.id)
              AND (c.expiry_date IS NULL OR c.expiry_date > CURRENT_DATE)
            GROUP BY c.facility_id
            """, nativeQuery = true)
    List<Object[]> countPlayableByFacility(@Param("facilityIds") List<Long> facilityIds);

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
