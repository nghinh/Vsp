package vnpt.vsp.module.correction.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.CorrectionStatus;

import java.util.List;

/**
 * JPA repository for {@link CourseCorrection} persistence and filtered queries.
 *
 * <p>Uses {@link JpaSpecificationExecutor} for the dynamic filter combinations
 * required by the queue list endpoint.</p>
 *
 * Per Story 9.2 AC-1 and Slice Plan §Slice A.
 */
@Repository
public interface CourseCorrectionRepository
        extends JpaRepository<CourseCorrection, Long>,
                JpaSpecificationExecutor<CourseCorrection> {

    /**
     * Find all corrections for a specific course (newest first).
     */
    List<CourseCorrection> findByCourseIdOrderBySubmittedAtDesc(Long courseId);

    /**
     * Find corrections by status (newest first).
     */
    List<CourseCorrection> findByStatusOrderBySubmittedAtDesc(CorrectionStatus status);

    /**
     * Count corrections by status for a given course.
     */
    long countByCourseIdAndStatus(Long courseId, CorrectionStatus status);

    // ─── Geometry columns ────────────────────────────────────────────────────
    //
    // PostGIS geometry columns cannot be written through the JPA mapping: every
    // geometry column in this codebase is mapped as a Java String, and pgjdbc
    // binds a String as `varchar`, which PostgreSQL refuses against a `geometry`
    // column at statement-parse time ("column is of type geometry but expression
    // is of type character varying") — even when the value is NULL. The geometry
    // fields on CourseCorrection are therefore mapped read-only and written here,
    // where the WKT goes through ST_GeomFromText and lands as a real geometry.

    /**
     * Writes the two geometry columns for a correction from WKT.
     *
     * @param id                 correction ID
     * @param proposedWkt        the shape the reporter believes is correct (WKT, SRID 4326)
     * @param reporterLng        reporter's longitude, or null if unknown
     * @param reporterLat        reporter's latitude, or null if unknown
     * @return number of rows updated (1 when the correction exists)
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
        UPDATE course_corrections
           SET proposed_geometry     = ST_GeomFromText(:proposedWkt, 4326),
               reporter_gps_location = CASE
                   WHEN CAST(:reporterLng AS double precision) IS NULL
                     OR CAST(:reporterLat AS double precision) IS NULL THEN NULL
                   ELSE ST_SetSRID(ST_MakePoint(
                            CAST(:reporterLng AS double precision),
                            CAST(:reporterLat AS double precision)), 4326)
               END
         WHERE id = :id
        """, nativeQuery = true)
    int setGeometryColumns(@Param("id") Long id,
                           @Param("proposedWkt") String proposedWkt,
                           @Param("reporterLng") Double reporterLng,
                           @Param("reporterLat") Double reporterLat);

    /**
     * Reads a correction's proposed geometry back as WKT.
     * Reading the mapped String field directly yields EWKB hex, not WKT.
     */
    @Query(value = "SELECT ST_AsText(proposed_geometry) FROM course_corrections WHERE id = :id",
           nativeQuery = true)
    String findProposedGeometryWkt(@Param("id") Long id);

    /**
     * Reads a correction's reporter GPS position back as WKT.
     *
     * <p>Same reason as {@link #findProposedGeometryWkt}: the mapped String
     * field yields the EWKB hex JDBC hands back
     * ({@code 0101000020E6100000…}), which is not what the admin detail
     * response documents or what a reviewer's map can plot.</p>
     */
    @Query(value = "SELECT ST_AsText(reporter_gps_location) FROM course_corrections WHERE id = :id",
           nativeQuery = true)
    String findReporterGpsLocationWkt(@Param("id") Long id);

    // ─── Corroboration (spatial aggregation) ──────────────────────────────────

    /**
     * Counts the reports that corroborate a proposed shape: same hole, same
     * geometry layer, and a representative point within {@code radiusMeters}.
     *
     * <p>This is the DBSCAN core-point test with {@code eps = radiusMeters}, run
     * against the one cluster the new report could possibly join. Distance is
     * measured between representative points (a polygon's centroid) cast to
     * {@code geography}, so the radius is true metres rather than degrees, and a
     * polygon and a standing-position point compare on equal terms. Rejected
     * reports are excluded — a reviewer has already ruled on them, and they must
     * not prop up a cluster.</p>
     */
    @Query(value = """
        SELECT COUNT(*)
          FROM course_corrections c
         WHERE c.hole_id = :holeId
           AND c.geometry_layer = :layer
           AND c.proposed_geometry IS NOT NULL
           AND c.status <> 'REJECTED'
           AND ST_DWithin(
                   CAST(ST_PointOnSurface(c.proposed_geometry) AS geography),
                   CAST(ST_PointOnSurface(ST_GeomFromText(:wkt, 4326)) AS geography),
                   :radiusMeters)
        """, nativeQuery = true)
    long countCorroboratingReports(@Param("holeId") Long holeId,
                                   @Param("layer") String layer,
                                   @Param("wkt") String wkt,
                                   @Param("radiusMeters") double radiusMeters);

    /**
     * Promotes a corroborated cluster so admins see it, and stamps every member
     * with the cluster size.
     *
     * <p>{@code verification_status} moves to PENDING_REVIEW, never to VERIFIED:
     * corroboration means "enough golfers agree that a human should look", not
     * "this is now true". Members already resolved by a reviewer (VERIFIED or
     * REJECTED) keep their status — promotion must not reopen a decision.</p>
     *
     * @return number of cluster members touched
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
        UPDATE course_corrections c
           SET corroboration_count = :clusterSize,
               verification_status = CASE
                   WHEN c.verification_status IN ('VERIFIED', 'REJECTED')
                       THEN c.verification_status
                   ELSE 'PENDING_REVIEW'
               END,
               updated_at = NOW()
         WHERE c.hole_id = :holeId
           AND c.geometry_layer = :layer
           AND c.proposed_geometry IS NOT NULL
           AND c.status <> 'REJECTED'
           AND ST_DWithin(
                   CAST(ST_PointOnSurface(c.proposed_geometry) AS geography),
                   CAST(ST_PointOnSurface(ST_GeomFromText(:wkt, 4326)) AS geography),
                   :radiusMeters)
        """, nativeQuery = true)
    int promoteCorroboratedCluster(@Param("holeId") Long holeId,
                                   @Param("layer") String layer,
                                   @Param("wkt") String wkt,
                                   @Param("radiusMeters") double radiusMeters,
                                   @Param("clusterSize") int clusterSize);
}
