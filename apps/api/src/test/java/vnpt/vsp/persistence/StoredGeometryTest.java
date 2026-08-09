package vnpt.vsp.persistence;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for reading geometry back out of an entity.
 *
 * <p>The case that matters is the hex one. {@link WktGeometryType} writes WKT
 * and reads back whatever JDBC hands over, which for PostGIS is hex EWKB — so
 * a parser that only understands WKT works perfectly against entities built in
 * a test and returns nothing for every row loaded from the database. That
 * failure is silent: no exception, just an empty package, which is exactly how
 * the build pipeline came to ship courses with no holes in them.</p>
 *
 * <p>The hex fixtures below were produced by the running PostGIS instance with
 * {@code ST_AsEWKB}, not by hand, so they encode what the driver actually
 * returns rather than what this code hopes it returns.</p>
 */
class StoredGeometryTest {

    /** SRID=4326;POINT(106.9 10.8), as PostGIS returns it. */
    private static final String POINT_EWKB_HEX =
            "0101000020e61000009a99999999b95a409a99999999992540";

    /** SRID=4326;POLYGON((106.9 10.8, 106.91 10.8, 106.91 10.81, 106.9 10.81, 106.9 10.8)). */
    private static final String POLYGON_EWKB_HEX =
            "0103000020e610000001000000050000009a99999999b95a409a999999999925400ad7a3703dba5a40"
            + "9a999999999925400ad7a3703dba5a401f85eb51b89e25409a99999999b95a401f85eb51b89e2540"
            + "9a99999999b95a409a99999999992540";

    @Test
    void readsTheHexEwkbAPostgisColumnActuallyReturns() {
        Map<String, Object> geoJson = StoredGeometry.toGeoJson(POINT_EWKB_HEX).orElseThrow();

        assertThat(geoJson).containsEntry("type", "Point");
        @SuppressWarnings("unchecked")
        List<Double> coordinates = (List<Double>) geoJson.get("coordinates");
        // GeoJSON is longitude-first. Swapping these puts a Vietnamese golf
        // course in the Indian Ocean, and every distance drawn from it is wrong
        // by thousands of kilometres while still looking like a number.
        assertThat(coordinates.get(0)).isCloseTo(106.9, org.assertj.core.data.Offset.offset(1e-9));
        assertThat(coordinates.get(1)).isCloseTo(10.8, org.assertj.core.data.Offset.offset(1e-9));
    }

    @Test
    void readsAPolygonAsARingOfCoordinates() {
        Map<String, Object> geoJson = StoredGeometry.toGeoJson(POLYGON_EWKB_HEX).orElseThrow();

        assertThat(geoJson).containsEntry("type", "Polygon");
        @SuppressWarnings("unchecked")
        List<List<List<Double>>> rings = (List<List<List<Double>>>) geoJson.get("coordinates");
        assertThat(rings).hasSize(1);
        assertThat(rings.get(0)).hasSize(5);
        assertThat(rings.get(0).get(0)).containsExactly(106.9, 10.8);
    }

    @Test
    void alsoReadsTheWktAnUnsavedEntityStillHolds() {
        // An entity built in memory, or loaded on H2, carries WKT rather than
        // hex. Both have to work or the packaging code passes its unit tests
        // and produces nothing in production.
        Map<String, Object> geoJson = StoredGeometry.toGeoJson("POINT(106.9 10.8)").orElseThrow();

        assertThat(geoJson).containsEntry("type", "Point");
    }

    @Test
    void acceptsTheSridPrefixTheWriteSideAdds() {
        Map<String, Object> geoJson =
                StoredGeometry.toGeoJson("SRID=4326;POINT(106.9 10.8)").orElseThrow();

        assertThat(geoJson).containsEntry("type", "Point");
    }

    @Test
    void aMalformedValueIsAbsentRatherThanFatal() {
        // One bad row must not abort a course package build. Absent is honest;
        // a substituted coordinate would not be.
        assertThat(StoredGeometry.toGeoJson("not geometry at all")).isEmpty();
        assertThat(StoredGeometry.toGeoJson("0101000020FFFF")).isEmpty();
    }

    @Test
    void nothingStoredIsNothingReturned() {
        assertThat(StoredGeometry.toGeoJson(null)).isEmpty();
        assertThat(StoredGeometry.toGeoJson("   ")).isEmpty();
        assertThat(StoredGeometry.toGeoJson("POINT EMPTY")).isEmpty();
    }
}
