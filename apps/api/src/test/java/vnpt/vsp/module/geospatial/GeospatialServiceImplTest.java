package vnpt.vsp.module.geospatial;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.geospatial.dto.FeatureDistanceResult;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.math.BigDecimal;
import java.util.List;

import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.AdditionalMatchers.and;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link GeospatialServiceImpl}.
 * Per Story 3.1 GEO-5: PostGIS geometry operations.
 * Tests: ST_IsValid, ST_DWithin, ST_Distance, ST_Within, ST_Contains.
 */
@ExtendWith(MockitoExtension.class)
class GeospatialServiceImplTest {

    private static final GeometryFactory GF = new GeometryFactory();
    private static final int SRID = 4326;

    @Mock
    private EntityManager entityManager;

    @Mock
    private Query query;

    private GeospatialServiceImpl geospatialService;

    @BeforeEach
    void setUp() {
        geospatialService = new GeospatialServiceImpl(entityManager);
    }

    // ─── Geometry validity tests ────────────────────────────────────────

    @Test
    void validateGeometry_returnsTrue_forValidPoint() {
        Point point = GF.createPoint(new Coordinate(106.660172, 10.762915));
        point.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(true);

        boolean result = geospatialService.validateGeometry(point);

        assertTrue(result);
    }

    @Test
    void validateGeometry_returnsFalse_forNullGeometry() {
        assertFalse(geospatialService.validateGeometry(null));
    }

    /**
     * The geometry reaches PostGIS as WKT, never as the JTS object.
     *
     * <p>There is no hibernate-spatial on this classpath, so a bound
     * {@code Geometry} arrives at Postgres as {@code bytea} and
     * {@code ST_SetSRID(bytea, integer)} matches two overloads: the statement
     * fails with "function is not unique", {@code validateGeometry} catches it
     * and answers "invalid", and every geometry in the system is invalid. A
     * course import then reports every feature as a topology error and can
     * never be committed. Nothing failed here because the query is mocked —
     * which is why this asserts on what is bound rather than on the answer.</p>
     */
    @Test
    void validateGeometry_bindsTheGeometryAsText_notAsAJtsObject() {
        Point point = GF.createPoint(new Coordinate(106.660172, 10.762915));
        point.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(true);

        geospatialService.validateGeometry(point);

        org.mockito.ArgumentCaptor<Object> bound = org.mockito.ArgumentCaptor.forClass(Object.class);
        verify(query, org.mockito.Mockito.atLeastOnce())
                .setParameter(anyString(), bound.capture());

        assertTrue(bound.getAllValues().stream()
                        .noneMatch(value -> value instanceof org.locationtech.jts.geom.Geometry),
                "a bound JTS geometry becomes bytea and makes the PostGIS call ambiguous");
        assertTrue(bound.getAllValues().contains(point.toText()),
                "the geometry should be bound as WKT: " + bound.getAllValues());
    }

    @Test
    void validateGeometry_setsSRID_whenMissing() {
        Point point = GF.createPoint(new Coordinate(106.660172, 10.762915));
        // SRID defaults to 0 when not set

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(true);

        boolean result = geospatialService.validateGeometry(point);

        assertTrue(result);
        assertEquals(SRID, point.getSRID());
    }

    @Test
    void assertGeometryValid_throws_forInvalidGeometry() {
        Point invalid = GF.createPoint(new Coordinate(0, 0));
        invalid.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        // First call: validateGeometry returns false (caught exception or false result)
        // For this test, we just verify the exception is thrown when validateGeometry returns false
        // We can't easily mock getValidityReason as it makes a second query
        // So test the negative case: validateGeometry returns false directly
        when(query.getSingleResult()).thenThrow(new RuntimeException("Invalid geometry"));

        VspApiException ex = assertThrows(VspApiException.class,
                () -> geospatialService.assertGeometryValid(invalid));

        assertNotNull(ex);
    }

    @Test
    void assertGeometryValid_passes_forValidGeometry() {
        Point valid = GF.createPoint(new Coordinate(106.660172, 10.762915));
        valid.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(true);

        assertDoesNotThrow(() -> geospatialService.assertGeometryValid(valid));
    }

    // ─── Distance calculation tests ────────────────────────────────────

    @Test
    void calculateDistance_returnsNull_forNullInput() {
        Point p = GF.createPoint(new Coordinate(106.660172, 10.762915));
        assertNull(geospatialService.calculateDistance(null, p, "meters"));
        assertNull(geospatialService.calculateDistance(p, null, "meters"));
    }

    @Test
    void calculateDistance_usesGeographyCast_forMeterUnits() {
        Point p1 = GF.createPoint(new Coordinate(106.660172, 10.762915));
        Point p2 = GF.createPoint(new Coordinate(106.700000, 10.800000));
        p1.setSRID(SRID);
        p2.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(BigDecimal.valueOf(5200.50));

        BigDecimal result = geospatialService.calculateDistance(p1, p2, "meters");

        assertEquals(BigDecimal.valueOf(5200.50), result);
    }

    @Test
    void calculateDistance_usesDegrees_forNonMeterUnits() {
        Point p1 = GF.createPoint(new Coordinate(106.660172, 10.762915));
        Point p2 = GF.createPoint(new Coordinate(106.700000, 10.800000));
        p1.setSRID(SRID);
        p2.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(BigDecimal.valueOf(0.05));

        BigDecimal result = geospatialService.calculateDistance(p1, p2, "degrees");

        assertEquals(BigDecimal.valueOf(0.05), result);
    }

    @Test
    void calculateDistance_handlesDoubleResult() {
        Point p1 = GF.createPoint(new Coordinate(106.660172, 10.762915));
        Point p2 = GF.createPoint(new Coordinate(106.700000, 10.800000));
        p1.setSRID(SRID);
        p2.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(Double.valueOf(1234.5));

        BigDecimal result = geospatialService.calculateDistance(p1, p2, "meters");

        assertEquals(BigDecimal.valueOf(1234.5), result);
    }

    // ─── ST_DWithin tests ───────────────────────────────────────────────

    @Test
    void findFeaturesWithinRadius_returnsEmpty_forNullPoint() {
        List<FeatureDistanceResult> result = geospatialService.findFeaturesWithinRadius(null, 1000, "greens", "location");
        assertTrue(result.isEmpty());
    }

    @Test
    void findFeaturesWithinRadius_returnsEmpty_forNegativeRadius() {
        Point p = GF.createPoint(new Coordinate(106.660172, 10.762915));
        List<FeatureDistanceResult> result = geospatialService.findFeaturesWithinRadius(p, -100, "greens", "location");
        assertTrue(result.isEmpty());
    }

    @Test
    void findFeaturesWithinRadius_returnsFeatureIdsAndDistances() {
        Point p = GF.createPoint(new Coordinate(106.660172, 10.762915));
        p.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getResultList()).thenReturn(List.of(
                new Object[]{1L, BigDecimal.valueOf(150.0)},
                new Object[]{2L, BigDecimal.valueOf(320.0)}
        ));

        List<FeatureDistanceResult> result = geospatialService.findFeaturesWithinRadius(p, 500, "greens", "location");

        assertEquals(2, result.size());
        assertEquals(1L, result.get(0).getFeatureId());
        assertEquals(BigDecimal.valueOf(150.0), result.get(0).getDistanceMeters());
        assertEquals(2L, result.get(1).getFeatureId());
    }

    @Test
    void findFeaturesWithinRadius_returnsEmpty_onQueryError() {
        Point p = GF.createPoint(new Coordinate(106.660172, 10.762915));
        p.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getResultList()).thenThrow(new RuntimeException("DB error"));

        List<FeatureDistanceResult> result = geospatialService.findFeaturesWithinRadius(p, 500, "greens", "location");

        assertTrue(result.isEmpty());
    }

    // ─── ST_Within tests ─────────────────────────────────────────────────

    @Test
    void isWithin_returnsTrue_whenInnerInsideOuter() {
        Polygon outer = GF.createPolygon(new Coordinate[]{
                new Coordinate(106.65, 10.75),
                new Coordinate(106.70, 10.75),
                new Coordinate(106.70, 10.80),
                new Coordinate(106.65, 10.80),
                new Coordinate(106.65, 10.75)
        });
        Point inner = GF.createPoint(new Coordinate(106.67, 10.77));
        outer.setSRID(SRID);
        inner.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(true);

        assertTrue(geospatialService.isWithin(inner, outer));
    }

    @Test
    void isWithin_returnsFalse_whenOuterIsNull() {
        Point inner = GF.createPoint(new Coordinate(106.67, 10.77));
        assertFalse(geospatialService.isWithin(inner, null));
    }

    // ─── ST_Contains tests ──────────────────────────────────────────────

    @Test
    void contains_returnsTrue_whenOuterContainsInner() {
        Polygon outer = GF.createPolygon(new Coordinate[]{
                new Coordinate(106.65, 10.75),
                new Coordinate(106.70, 10.75),
                new Coordinate(106.70, 10.80),
                new Coordinate(106.65, 10.80),
                new Coordinate(106.65, 10.75)
        });
        Point inner = GF.createPoint(new Coordinate(106.67, 10.77));
        outer.setSRID(SRID);
        inner.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(true);

        assertTrue(geospatialService.contains(outer, inner));
    }

    @Test
    void contains_returnsFalse_whenOuterIsNull() {
        Point inner = GF.createPoint(new Coordinate(106.67, 10.77));
        assertFalse(geospatialService.contains(null, inner));
    }

    // ─── Nearest feature tests ─────────────────────────────────────────

    @Test
    void findNearestFeature_returnsNull_forNullPoint() {
        assertNull(geospatialService.findNearestFeature(null, "greens", "location"));
    }

    // Note: findNearestFeature_returnsNearestFeature is complex to mock due to
    // CROSS JOIN LATERAL SQL and Hibernate parameter binding.
    // The implementation is verified via integration tests.

    @Test
    void findNearestFeature_returnsNull_whenNoFeatures() {
        Point p = GF.createPoint(new Coordinate(106.660172, 10.762915));
        p.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getResultList()).thenReturn(List.of());

        assertNull(geospatialService.findNearestFeature(p, "greens", "location"));
    }

    @Test
    void findNearestFeature_returnsNull_onQueryError() {
        Point p = GF.createPoint(new Coordinate(106.660172, 10.762915));
        p.setSRID(SRID);

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getResultList()).thenThrow(new RuntimeException("DB error"));

        assertNull(geospatialService.findNearestFeature(p, "greens", "location"));
    }

    // ─── Every geometry crosses into SQL as WKT ──────────────────────────────

    /**
     * The same assertion as {@code validateGeometry_bindsTheGeometryAsText}, for
     * the five remaining sites that bound the JTS object directly.
     *
     * <p>{@link GeospatialServicePostgisTest} is what actually proved these
     * broken — against a real PostGIS, every one of them failed with "function
     * st_setsrid(bytea, integer) is not unique". These mocked tests exist because
     * that one is skipped wherever no database is reachable, and because the
     * failure is invisible from the return value: each of these methods catches
     * broadly and answers {@code null}, {@code false}, or an empty list, so a
     * test asserting on the answer passes just as happily when the statement
     * never ran. Assert on what is bound instead.
     */
    private void assertNoJtsGeometryBound(String site, Object... expectedWkt) {
        org.mockito.ArgumentCaptor<Object> bound = org.mockito.ArgumentCaptor.forClass(Object.class);
        verify(query, org.mockito.Mockito.atLeastOnce()).setParameter(anyString(), bound.capture());

        assertTrue(bound.getAllValues().stream()
                        .noneMatch(v -> v instanceof org.locationtech.jts.geom.Geometry),
                site + ": a bound JTS geometry becomes bytea and makes the PostGIS call ambiguous");
        for (Object wkt : expectedWkt) {
            assertTrue(bound.getAllValues().contains(wkt),
                    site + ": expected WKT " + wkt + " among " + bound.getAllValues());
        }
    }

    /** ST_SetSRID must not appear anywhere: it is the overload-ambiguous call. */
    private void assertSqlUsesGeomFromText(String site) {
        org.mockito.ArgumentCaptor<String> sql = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(entityManager, org.mockito.Mockito.atLeastOnce()).createNativeQuery(sql.capture());

        String statement = sql.getValue();
        assertTrue(statement.contains("ST_GeomFromText"), site + ": " + statement);
        assertFalse(statement.contains("ST_SetSRID"),
                site + ": ST_SetSRID on a bound parameter is the ambiguity itself: " + statement);
    }

    @Test
    void calculateDistance_bindsBothGeometriesAsText_inMeters() {
        Point a = GF.createPoint(new Coordinate(105, 21));
        Point b = GF.createPoint(new Coordinate(105, 22));

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(110723.60868296);

        geospatialService.calculateDistance(a, b, "meters");

        assertNoJtsGeometryBound("calculateDistance/meters", a.toText(), b.toText());
        assertSqlUsesGeomFromText("calculateDistance/meters");
    }

    @Test
    void calculateDistance_bindsBothGeometriesAsText_inDegrees() {
        Point a = GF.createPoint(new Coordinate(105, 21));
        Point b = GF.createPoint(new Coordinate(105, 22));

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(1.0);

        geospatialService.calculateDistance(a, b, "degrees");

        assertNoJtsGeometryBound("calculateDistance/degrees", a.toText(), b.toText());
        assertSqlUsesGeomFromText("calculateDistance/degrees");
    }

    @Test
    void findFeaturesWithinRadius_bindsThePointAsText() {
        Point p = GF.createPoint(new Coordinate(106.660172, 10.762915));

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getResultList()).thenReturn(List.of());

        geospatialService.findFeaturesWithinRadius(p, 500, "greens", "location");

        assertNoJtsGeometryBound("findFeaturesWithinRadius", p.toText());
        assertSqlUsesGeomFromText("findFeaturesWithinRadius");
    }

    @Test
    void findNearestFeature_bindsThePointAsText() {
        Point p = GF.createPoint(new Coordinate(106.660172, 10.762915));

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getResultList()).thenReturn(List.of());

        geospatialService.findNearestFeature(p, "greens", "location");

        assertNoJtsGeometryBound("findNearestFeature", p.toText());
        assertSqlUsesGeomFromText("findNearestFeature");
    }

    @Test
    void isWithin_bindsBothGeometriesAsText() {
        Point inner = GF.createPoint(new Coordinate(105.5, 21.5));
        Polygon outer = squarePolygon();

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(true);

        geospatialService.isWithin(inner, outer);

        assertNoJtsGeometryBound("isWithin", inner.toText(), outer.toText());
        assertSqlUsesGeomFromText("isWithin");
    }

    @Test
    void contains_bindsBothGeometriesAsText() {
        Point inner = GF.createPoint(new Coordinate(105.5, 21.5));
        Polygon outer = squarePolygon();

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.getSingleResult()).thenReturn(true);

        geospatialService.contains(outer, inner);

        assertNoJtsGeometryBound("contains", inner.toText(), outer.toText());
        assertSqlUsesGeomFromText("contains");
    }

    /**
     * The reason lookup is reached only from the throw, and it bound a geometry
     * the same way — so the admin was shown "unknown: " and the driver's
     * complaint about parameter types in place of what was wrong with their data.
     */
    @Test
    void assertGeometryValid_bindsTheReasonLookupGeometryAsText_andCarriesTheReasonAsTheMessage() {
        Polygon invalid = squarePolygon();

        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        // validateGeometry answers false, then getValidityReason answers the reason.
        when(query.getSingleResult()).thenReturn(false, "Self-intersection[105 21]");

        VspApiException ex = assertThrows(VspApiException.class,
                () -> geospatialService.assertGeometryValid(invalid));

        assertNoJtsGeometryBound("getValidityReason", invalid.toText());

        // The two-argument VspApiException constructor takes its String as the
        // *field*, not the message, so this reason used to be filed as a field
        // name and the caller saw only the generic default text.
        assertTrue(ex.getMessage().contains("Self-intersection"),
                "the reason must reach the caller as the message: " + ex.getMessage());
        assertNull(ex.getField(), "this is not a field-level error");
    }

    private static Polygon squarePolygon() {
        return GF.createPolygon(GF.createLinearRing(new Coordinate[]{
                new Coordinate(105, 21), new Coordinate(106, 21),
                new Coordinate(106, 22), new Coordinate(105, 22),
                new Coordinate(105, 21)}));
    }
}
