package vnpt.vsp.persistence;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Unit tests for {@link WktGeometryValidator}.
 *
 * <p>Each rejection here corresponds to something PostgreSQL would answer with
 * mid-statement — the errors probed against the real database are quoted in the
 * class javadoc — plus the one case PostGIS accepts and should not: an invalid
 * ring. {@link vnpt.vsp.module.course.CourseServiceImplTest} covers the wiring
 * into the admin write paths.</p>
 */
class WktGeometryValidatorTest {

    private static VspApiException rejectsPoint(String wkt) {
        return assertThrows(VspApiException.class,
                () -> WktGeometryValidator.requirePoint(wkt, "greenLocation"));
    }

    private static VspApiException rejects(String wkt) {
        return assertThrows(VspApiException.class,
                () -> WktGeometryValidator.requireValid(wkt, "location"));
    }

    @Test
    @DisplayName("null means the field was not supplied, not that it is wrong")
    void nullIsNotAnError() {
        assertDoesNotThrow(() -> WktGeometryValidator.requireValid(null, "location"));
        assertDoesNotThrow(() -> WktGeometryValidator.requirePoint(null, "greenLocation"));
    }

    @Test
    @DisplayName("well-formed WKT passes, with or without the SRID prefix the mapping also accepts")
    void validGeometriesPass() {
        assertDoesNotThrow(() -> WktGeometryValidator.requirePoint("POINT(106.7 10.8)", "greenLocation"));
        assertDoesNotThrow(() -> WktGeometryValidator.requirePoint("SRID=4326;POINT(106.7 10.8)", "greenLocation"));
        assertDoesNotThrow(() -> WktGeometryValidator.requireValid(
                "POLYGON((106 10,106.001 10,106.001 10.001,106 10.001,106 10))", "location"));
        assertDoesNotThrow(() -> WktGeometryValidator.requireValid(
                "LINESTRING(106 10,106.001 10.001)", "location"));
    }

    @Test
    @DisplayName("every rejection carries VALIDATION-008 and names the field")
    void rejectionsAreReportedConsistently() {
        VspApiException ex = rejectsPoint("not-wkt");
        assertEquals(VspErrorCode.VALIDATION_008, ex.getErrorCode());
        assertEquals("greenLocation", ex.getField());
        assertTrue(ex.getMessage().contains("greenLocation"), ex.getMessage());
        assertEquals("POINT", ex.getDetails().get("expectedType"));
        assertEquals(4326, ex.getDetails().get("expectedSrid"));
    }

    @Test
    @DisplayName("unparseable text is rejected — PostGIS answers 'parse error - invalid geometry'")
    void unparseableIsRejected() {
        rejects("not-wkt");
        rejects("POINT(1 2 3 4 5)");
        rejects("POLYGON((0 0,1 0))");
        rejects("   ");
    }

    @Test
    @DisplayName("the wrong shape for a Point column is rejected here, not by the column")
    void shapeMustMatchTheColumn() {
        VspApiException ex = rejectsPoint("POLYGON((0 0,1 0,1 1,0 1,0 0))");
        assertTrue(ex.getMessage().contains("POINT"), ex.getMessage());
        rejectsPoint("MULTIPOINT((0 0),(1 1))");

        // …while the course boundary column is geometry(Geometry,4326) and takes any of them.
        assertDoesNotThrow(() -> WktGeometryValidator.requireValid(
                "POLYGON((0 0,1 0,1 1,0 1,0 0))", "location"));
    }

    @Test
    @DisplayName("a foreign SRID is rejected — every geometry column in this schema is 4326")
    void foreignSridIsRejected() {
        VspApiException ex = rejects("SRID=3857;POINT(0 0)");
        assertTrue(ex.getMessage().contains("4326"), ex.getMessage());
    }

    @Test
    @DisplayName("a Z ordinate is rejected — the columns are 2D and PostgreSQL drops the statement")
    void zOrdinateIsRejected() {
        rejectsPoint("POINT Z (1 2 3)");
        rejectsPoint("POINT(1 2 3)");
    }

    @Test
    @DisplayName("an empty geometry is rejected — PostGIS would store POINT EMPTY as a usable-looking nothing")
    void emptyGeometryIsRejected() {
        rejects("POINT EMPTY");
        rejects("POLYGON EMPTY");
    }

    @Test
    @DisplayName("a self-intersecting ring is rejected, which PostGIS itself would not do")
    void selfIntersectingPolygonIsRejected() {
        VspApiException ex = rejects("POLYGON((0 0,1 1,1 0,0 1,0 0))");
        assertEquals(VspErrorCode.VALIDATION_008, ex.getErrorCode());
    }
}
