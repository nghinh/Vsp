package vnpt.vsp.module.correction.repository;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CorrectionType;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.GeometryLayer;
import vnpt.vsp.module.course.entity.VerificationStatus;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.time.Instant;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Verifies against real PostGIS that a correction's geometry survives a JPA
 * write and that the corroboration SQL clusters what it claims to.
 *
 * <p>Both geometry columns are written through {@link
 * vnpt.vsp.persistence.WktGeometryType} like every other geometry column in the
 * schema. H2 accepts that binding too, so an H2 test would pass whether or not
 * PostgreSQL would — which is the whole reason this class exists and is skipped
 * rather than substituted when no PostgreSQL answers.</p>
 *
 * <p>The corroboration queries are native, and a native query is the one kind
 * the compiler cannot check: a wrong column name, or a radius that is silently
 * degrees rather than metres, only shows up when it runs against PostGIS.</p>
 */
@DataJpaTest(properties = {
        "spring.datasource.url=jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DB:vsp}",
        "spring.datasource.username=${POSTGRES_USER:vsp}",
        "spring.datasource.password=${POSTGRES_PASSWORD:vsp_dev_password}",
        "spring.datasource.driver-class-name=org.postgresql.Driver",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.flyway.enabled=false",
        "spring.sql.init.mode=never"
})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@EnabledIf("postgisAvailable")
class CourseCorrectionGeometryPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    private static final String PROPOSED_WKT = "POINT(106.7205 10.8506)";
    private static final double REPORTER_LNG = 106.7211;
    private static final double REPORTER_LAT = 10.8511;

    /** Cluster radius the service runs with (vsp.corrections.cluster-radius-meters). */
    private static final double RADIUS_M = 15.0;

    /** ~5.5 m at this latitude, so three of these span ~11 m — inside the radius. */
    private static final double NEAR_STEP_DEG = 0.00005;

    /** ~220 m — a different green, and it must not join the cluster. */
    private static final double FAR_STEP_DEG = 0.002;

    /** Each test gets its own hole so a cluster query can only see its own rows. */
    private static final AtomicLong HOLE_IDS = new AtomicLong(900_000L);

    @Autowired
    private CourseCorrectionRepository repository;

    @Autowired
    private EntityManager em;

    private CourseCorrection saved(Double lng, Double lat) {
        return save(1L, GeometryLayer.GREEN, PROPOSED_WKT, CorrectionStatus.PENDING, lng, lat);
    }

    private CourseCorrection save(long holeId, GeometryLayer layer, String proposedWkt,
                                  CorrectionStatus status, Double lng, Double lat) {
        CourseCorrection c = new CourseCorrection();
        c.setCourseId(1L);
        c.setHoleId(holeId);
        c.setReporterId(1L);
        c.setCorrectionType(CorrectionType.GEOMETRY);
        c.setStatus(status);
        c.setGeometryLayer(layer);
        c.setSubmittedAt(Instant.now());
        c.setProposedGeometry(proposedWkt);
        c.setReporterGpsLocation(lng != null && lat != null ? "POINT(" + lng + " " + lat + ")" : null);
        c.getMetadata().setPublisher("correction-geometry-test");
        c.getMetadata().setVerificationStatus(VerificationStatus.UNVERIFIED);
        return repository.saveAndFlush(c);
    }

    /** A point {@code steps} × the step north of the proposed shape. */
    private static String pointNorthOf(double steps, double stepDeg) {
        return "POINT(106.7205 " + (10.8506 + steps * stepDeg) + ")";
    }

    // ─── Write path ───────────────────────────────────────────────────────────

    @Test
    @DisplayName("reporter GPS reads back as WKT, while the mapped field is EWKB hex")
    void reporterGpsReadsBackAsWkt() {
        CourseCorrection c = saved(REPORTER_LNG, REPORTER_LAT);

        assertEquals("POINT(" + REPORTER_LNG + " " + REPORTER_LAT + ")",
                repository.findReporterGpsLocationWkt(c.getId()));

        em.clear();
        String asMapped = em.find(CourseCorrection.class, c.getId()).getReporterGpsLocation();
        assertTrue(asMapped != null && asMapped.matches("(?i)[0-9a-f]+"),
                "expected EWKB hex from the mapped field but got: " + asMapped);
    }

    @Test
    @DisplayName("proposed geometry reads back as WKT")
    void proposedGeometryReadsBackAsWkt() {
        CourseCorrection c = saved(REPORTER_LNG, REPORTER_LAT);

        assertEquals(PROPOSED_WKT, repository.findProposedGeometryWkt(c.getId()));
    }

    @Test
    @DisplayName("a correction with no reported position reads back null, not an empty geometry")
    void missingReporterGpsIsNull() {
        CourseCorrection c = saved(null, null);

        assertNull(repository.findReporterGpsLocationWkt(c.getId()));
    }

    @Test
    @DisplayName("the EWKB hex a read produced still round-trips back through an UPDATE")
    void loadedHexRoundTripsThroughAnUpdate() {
        CourseCorrection c = saved(REPORTER_LNG, REPORTER_LAT);
        Long id = c.getId();
        em.clear();

        // A reviewer opening the correction loads it, changes a field, and saves;
        // the geometry columns go back down as the hex that came up.
        CourseCorrection reloaded = repository.findById(id).orElseThrow();
        reloaded.setReviewNote("round-trip probe");
        repository.saveAndFlush(reloaded);

        assertEquals(PROPOSED_WKT, repository.findProposedGeometryWkt(id));
        assertEquals("POINT(" + REPORTER_LNG + " " + REPORTER_LAT + ")",
                repository.findReporterGpsLocationWkt(id));
    }

    // ─── Corroboration ────────────────────────────────────────────────────────

    @Test
    @DisplayName("three reports within 15 m of each other promote the cluster to PENDING_REVIEW, stamped with its size")
    void threeNearbyReportsPromoteTheCluster() {
        long holeId = HOLE_IDS.incrementAndGet();
        CourseCorrection first = save(holeId, GeometryLayer.GREEN, pointNorthOf(0, NEAR_STEP_DEG),
                CorrectionStatus.PENDING, null, null);
        CourseCorrection second = save(holeId, GeometryLayer.GREEN, pointNorthOf(1, NEAR_STEP_DEG),
                CorrectionStatus.PENDING, null, null);
        CourseCorrection third = save(holeId, GeometryLayer.GREEN, pointNorthOf(2, NEAR_STEP_DEG),
                CorrectionStatus.PENDING, null, null);

        String newest = pointNorthOf(2, NEAR_STEP_DEG);
        assertEquals(3, repository.countCorroboratingReports(holeId, "GREEN", newest, RADIUS_M));
        assertEquals(3, repository.promoteCorroboratedCluster(holeId, "GREEN", newest, RADIUS_M, 3));

        for (CourseCorrection member : new CourseCorrection[]{first, second, third}) {
            CourseCorrection reloaded = repository.findById(member.getId()).orElseThrow();
            assertEquals(3, reloaded.getCorroborationCount(),
                    "cluster size stamped on correction " + member.getId());
            assertEquals(VerificationStatus.PENDING_REVIEW,
                    reloaded.getMetadata().getVerificationStatus(),
                    "verification status on correction " + member.getId());
        }
    }

    @Test
    @DisplayName("the radius is metres, not degrees — a report 220 m away is a different cluster")
    void reportsBeyondTheRadiusAreADifferentCluster() {
        long holeId = HOLE_IDS.incrementAndGet();
        save(holeId, GeometryLayer.GREEN, pointNorthOf(0, NEAR_STEP_DEG), CorrectionStatus.PENDING, null, null);
        CourseCorrection far = save(holeId, GeometryLayer.GREEN, pointNorthOf(1, FAR_STEP_DEG),
                CorrectionStatus.PENDING, null, null);

        String near = pointNorthOf(0, NEAR_STEP_DEG);
        assertEquals(1, repository.countCorroboratingReports(holeId, "GREEN", near, RADIUS_M));
        assertEquals(1, repository.promoteCorroboratedCluster(holeId, "GREEN", near, RADIUS_M, 1));

        CourseCorrection reloaded = repository.findById(far.getId()).orElseThrow();
        assertEquals(1, reloaded.getCorroborationCount());
        assertEquals(VerificationStatus.UNVERIFIED, reloaded.getMetadata().getVerificationStatus());
    }

    @Test
    @DisplayName("a report about another layer at the same spot is a different cluster")
    void otherLayersAreADifferentCluster() {
        long holeId = HOLE_IDS.incrementAndGet();
        save(holeId, GeometryLayer.GREEN, pointNorthOf(0, NEAR_STEP_DEG), CorrectionStatus.PENDING, null, null);
        save(holeId, GeometryLayer.BUNKER, pointNorthOf(0, NEAR_STEP_DEG), CorrectionStatus.PENDING, null, null);

        assertEquals(1, repository.countCorroboratingReports(
                holeId, "GREEN", pointNorthOf(0, NEAR_STEP_DEG), RADIUS_M));
    }

    @Test
    @DisplayName("a rejected report neither props up a cluster nor is reopened by one")
    void rejectedReportsAreExcluded() {
        long holeId = HOLE_IDS.incrementAndGet();
        CourseCorrection rejected = save(holeId, GeometryLayer.GREEN, pointNorthOf(0, NEAR_STEP_DEG),
                CorrectionStatus.REJECTED, null, null);
        save(holeId, GeometryLayer.GREEN, pointNorthOf(1, NEAR_STEP_DEG), CorrectionStatus.PENDING, null, null);
        save(holeId, GeometryLayer.GREEN, pointNorthOf(2, NEAR_STEP_DEG), CorrectionStatus.PENDING, null, null);

        String newest = pointNorthOf(2, NEAR_STEP_DEG);
        assertEquals(2, repository.countCorroboratingReports(holeId, "GREEN", newest, RADIUS_M));
        assertEquals(2, repository.promoteCorroboratedCluster(holeId, "GREEN", newest, RADIUS_M, 2));

        CourseCorrection reloaded = repository.findById(rejected.getId()).orElseThrow();
        assertEquals(1, reloaded.getCorroborationCount());
        assertEquals(VerificationStatus.UNVERIFIED, reloaded.getMetadata().getVerificationStatus());
    }
}
