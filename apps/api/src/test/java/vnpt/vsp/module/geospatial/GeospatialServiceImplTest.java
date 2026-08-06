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
}
