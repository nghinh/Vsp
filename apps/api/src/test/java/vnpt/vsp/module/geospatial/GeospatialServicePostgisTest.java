package vnpt.vsp.module.geospatial;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.LinearRing;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.TestPropertySource;

import jakarta.persistence.EntityManager;
import java.math.BigDecimal;
import java.sql.DriverManager;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Runs {@link GeospatialServiceImpl} against a real PostGIS, because the rest of
 * the suite cannot.
 *
 * <p>{@link GeospatialServiceImplTest} mocks the {@link EntityManager} and
 * {@code application-test.yml} is H2, so no test in this repository has ever sent
 * one of these statements to PostGIS. That is precisely how
 * {@code ST_SetSRID(:geom, :srid)} survived: with no hibernate-spatial on the
 * classpath a bound JTS {@code Geometry} arrives as {@code bytea},
 * {@code ST_SetSRID(bytea, integer)} matches both the geometry and the geography
 * overload, and PostgreSQL refuses the statement — while every one of these
 * methods catches broadly and answers {@code null} / {@code false} / an empty
 * list, so the caller is told "no result", never "the query could not run".
 *
 * <p>Every expectation below is a value computed independently in psql against
 * the same database, not a value read back from the code under test — asserting
 * on what the method returns is exactly what passed while this was broken.
 *
 * <p>Skipped, not failed, when no PostGIS is reachable: the condition is
 * evaluated before the Spring context is built, so an ordinary
 * {@code mvn -o clean test} on a machine with no database is unaffected.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@TestPropertySource(properties = {
        "spring.datasource.url=jdbc:postgresql://localhost:5432/vsp",
        "spring.datasource.username=vsp",
        "spring.datasource.password=vsp_dev_password",
        "spring.datasource.driver-class-name=org.postgresql.Driver",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.jpa.properties.hibernate.hbm2ddl.auto=none",
        "spring.flyway.enabled=false",
        "spring.sql.init.mode=never"
})
@EnabledIf("postgisIsReachable")
class GeospatialServicePostgisTest {

    private static final GeometryFactory GF = new GeometryFactory();
    private static final int SRID = 4326;

    /** Evaluated by JUnit before Spring builds a context, so an absent database skips rather than errors. */
    static boolean postgisIsReachable() {
        try (var c = DriverManager.getConnection(
                "jdbc:postgresql://localhost:5432/vsp?connectTimeout=2", "vsp", "vsp_dev_password");
             var st = c.createStatement()) {
            st.execute("SELECT postgis_version()");
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @org.springframework.beans.factory.annotation.Autowired
    private EntityManager entityManager;

    private GeospatialServiceImpl geospatialService;

    @BeforeEach
    void setUp() {
        geospatialService = new GeospatialServiceImpl(entityManager);
    }

    /// A probe sitting exactly on some real green's centroid.
    ///
    /// Read from the database rather than pasted in, because the greens table
    /// is rebuilt whenever the OSM pipeline runs and the primary keys move with
    /// it. What these tests are about is the geometry, not which row happens to
    /// hold it today.
    private Point probeOnAGreenCentroid() {
        Object[] row = (Object[]) entityManager
                .createNativeQuery(
                        "SELECT ST_X(ST_Centroid(location)), ST_Y(ST_Centroid(location)) "
                                + "FROM greens ORDER BY id LIMIT 1")
                .getSingleResult();
        return point(
                ((Number) row[0]).doubleValue(),
                ((Number) row[1]).doubleValue());
    }

    private static Point point(double lon, double lat) {
        Point p = GF.createPoint(new Coordinate(lon, lat));
        p.setSRID(SRID);
        return p;
    }

    /** The 1°x1° box whose corners are (105,21) and (106,22). */
    private static Polygon box() {
        LinearRing ring = GF.createLinearRing(new Coordinate[]{
                new Coordinate(105, 21), new Coordinate(106, 21),
                new Coordinate(106, 22), new Coordinate(105, 22),
                new Coordinate(105, 21)});
        Polygon p = GF.createPolygon(ring);
        p.setSRID(SRID);
        return p;
    }

    // ─── Site 0: validateGeometry (fixed in d6a3c42; guards the regression) ──

    @Test
    void validateGeometry_acceptsAValidPolygon_andRejectsASelfIntersectingOne() {
        assertTrue(geospatialService.validateGeometry(box()));

        // A bow-tie: the classic self-intersection. ST_IsValid says false, and so
        // must we — a "false" that means "invalid" and not "the query blew up".
        LinearRing bowTie = GF.createLinearRing(new Coordinate[]{
                new Coordinate(105, 21), new Coordinate(106, 22),
                new Coordinate(106, 21), new Coordinate(105, 22),
                new Coordinate(105, 21)});
        Polygon invalid = GF.createPolygon(bowTie);
        invalid.setSRID(SRID);
        assertFalse(geospatialService.validateGeometry(invalid));
    }

    // ─── Site 1 + 2: calculateDistance, meters and degrees ───────────────────

    /**
     * psql, independently:
     * {@code SELECT ST_Distance(ST_GeomFromText('POINT(105 21)',4326)::geography,
     * ST_GeomFromText('POINT(105 22)',4326)::geography);} → 110723.60868296
     */
    @Test
    void calculateDistance_inMeters_matchesTheWgs84SpheroidalDistance() {
        BigDecimal meters = geospatialService.calculateDistance(point(105, 21), point(105, 22), "meters");

        assertNotNull(meters, "null here is the broken shape: the statement did not run");
        assertEquals(110723.60868296, meters.doubleValue(), 0.01);
    }

    /**
     * The same pair in degrees is exactly 1.0 — a planar answer, and a different
     * number from the metric one, so this also proves the two branches are not
     * silently returning each other's result.
     */
    @Test
    void calculateDistance_inDegrees_isThePlanarDegreeSeparation() {
        BigDecimal degrees = geospatialService.calculateDistance(point(105, 21), point(105, 22), "degrees");

        assertNotNull(degrees, "null here is the broken shape: the statement did not run");
        assertEquals(1.0, degrees.doubleValue(), 1e-9);
    }

    @Test
    void calculateDistance_ofAPointWithItself_isZeroAndNotNull() {
        BigDecimal meters = geospatialService.calculateDistance(point(105, 21), point(105, 21), "meters");

        // Zero and null are the same answer to a caller that only null-checks;
        // they are not the same answer to anyone measuring a distance.
        assertNotNull(meters);
        assertEquals(0.0, meters.doubleValue(), 1e-9);
    }

    // ─── Site 3: findFeaturesWithinRadius ────────────────────────────────────

    /**
     * The probe sits on the centroid of a real green, chosen from the database
     * rather than named.
     *
     * <p>These assertions used to hard-code the ids the query came back with —
     * 13116, 13185, 13169 and so on — read out of the live database once and
     * pasted in. The greens table is rebuilt every time the OSM pipeline runs
     * (it deletes the rows it owns and re-imports them), so those ids rotate,
     * and the test failed the first time anyone refreshed the course data. It
     * was asserting a snapshot of primary keys, not the behaviour it is named
     * for.</p>
     *
     * <p>What the behaviour actually is: a radius query returns the features
     * inside the radius, nearest first, with real distances. That is asserted
     * below against whatever greens the database currently holds.</p>
     */
    @Test
    void findFeaturesWithinRadius_returnsTheNearbyGreensInDistanceOrder() {
        Point probe = probeOnAGreenCentroid();

        List<vnpt.vsp.module.geospatial.dto.FeatureDistanceResult> found =
                geospatialService.findFeaturesWithinRadius(probe, 500, "greens", "location");

        // An empty list is the broken shape, and the one that lies loudest: it
        // reads as "nothing is near this point" rather than "the query failed".
        assertFalse(found.isEmpty(), "931 greens exist and the probe sits on one");

        // The probe is the centroid of a green, so that green is first at ~0 m.
        assertEquals(0.0, found.get(0).getDistanceMeters().doubleValue(), 1.0);

        // Nearest first, and every distance inside the radius asked for.
        for (int i = 0; i < found.size(); i++) {
            double d = found.get(i).getDistanceMeters().doubleValue();
            assertTrue(d <= 500.0, "feature " + found.get(i).getFeatureId() + " is outside the radius");
            if (i > 0) {
                assertTrue(d >= found.get(i - 1).getDistanceMeters().doubleValue(),
                        "results are not in distance order at index " + i);
            }
        }
    }

    @Test
    void findFeaturesWithinRadius_withATightRadius_excludesTheNeighbours() {
        Point probe = probeOnAGreenCentroid();

        List<vnpt.vsp.module.geospatial.dto.FeatureDistanceResult> wide =
                geospatialService.findFeaturesWithinRadius(probe, 500, "greens", "location");
        List<vnpt.vsp.module.geospatial.dto.FeatureDistanceResult> tight =
                geospatialService.findFeaturesWithinRadius(probe, 5, "greens", "location");

        // A tighter radius reaches the green the probe sits on and no more —
        // the point of ST_DWithin is that it excludes, not that it answers.
        assertFalse(tight.isEmpty());
        assertTrue(tight.size() < wide.size(),
                "a 5 m radius returned as much as a 500 m one");
        assertEquals(0.0, tight.get(0).getDistanceMeters().doubleValue(), 1.0);
    }

    @Test
    void findFeaturesWithinRadius_farFromAnyGreen_isGenuinelyEmpty() {
        // Mid-Pacific. Empty because nothing is there, which is only a meaningful
        // assertion now that an empty list is no longer the failure mode too.
        List<vnpt.vsp.module.geospatial.dto.FeatureDistanceResult> found =
                geospatialService.findFeaturesWithinRadius(point(-140, 0), 1000, "greens", "location");

        assertTrue(found.isEmpty());
    }

    // ─── Site 4: findNearestFeature ──────────────────────────────────────────

    @Test
    void findNearestFeature_findsTheGreenTheProbeSitsOn() {
        Point probe = probeOnAGreenCentroid();

        var nearest = geospatialService.findNearestFeature(probe, "greens", "location");

        assertNotNull(nearest, "null here is the broken shape: 931 greens exist");
        // Named by position rather than by id: which green carries which
        // primary key changes every time the course data is re-imported.
        assertEquals(0.0, nearest.getDistanceMeters().doubleValue(), 1.0);
    }

    @Test
    void findNearestFeature_fromFarAway_stillNamesAGreenRatherThanNull() {
        // Every green is in Vietnam; from the mid-Pacific the nearest is still one
        // of them, at a large but finite distance.
        var nearest = geospatialService.findNearestFeature(point(-140, 0), "greens", "location");

        assertNotNull(nearest);
        assertTrue(nearest.getDistanceMeters().doubleValue() > 1_000_000,
                "expected a very distant green, got " + nearest.getDistanceMeters());
    }

    // ─── Site 5: isWithin ────────────────────────────────────────────────────

    @Test
    void isWithin_isTrueForAnInteriorPoint_andFalseForAnExteriorOne() {
        assertTrue(geospatialService.isWithin(point(105.5, 21.5), box()));

        // Just outside the eastern edge. A "false" that means false, rather than
        // the "false" this method returned for every input.
        assertFalse(geospatialService.isWithin(point(106.5, 21.5), box()));
    }

    // ─── Site 6: contains ────────────────────────────────────────────────────

    @Test
    void contains_isTrueForAnInteriorPoint_andFalseForAnExteriorOne() {
        assertTrue(geospatialService.contains(box(), point(105.5, 21.5)));
        assertFalse(geospatialService.contains(box(), point(106.5, 21.5)));
    }

    // ─── Site 7: getValidityReason, via assertGeometryValid ──────────────────

    /**
     * The reason is a private helper reached only when a geometry is rejected, so
     * it is exercised through the throw. It bound a geometry the same way, and
     * the {@code catch} returned "unknown: " + the driver's complaint — so the
     * message an admin was shown described the binding failure, not their data.
     */
    @Test
    void assertGeometryValid_reportsPostgisOwnReason_notADriverError() {
        LinearRing bowTie = GF.createLinearRing(new Coordinate[]{
                new Coordinate(105, 21), new Coordinate(106, 22),
                new Coordinate(106, 21), new Coordinate(105, 22),
                new Coordinate(105, 21)});
        Polygon invalid = GF.createPolygon(bowTie);
        invalid.setSRID(SRID);

        var ex = assertThrows(vnpt.vsp.api.error.VspApiException.class,
                () -> geospatialService.assertGeometryValid(invalid));

        String message = ex.getMessage();
        assertTrue(message.contains("Self-intersection"),
                "expected PostGIS's own ST_IsValidReason, got: " + message);
        assertFalse(message.contains("unknown:"), "reason lookup itself failed: " + message);
        assertFalse(message.contains("not unique"), "the bytea ambiguity is back: " + message);
    }
}
