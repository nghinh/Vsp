package vnpt.vsp.persistence;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKTReader;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Checks a caller-supplied WKT string before it is bound to a PostGIS
 * {@code geometry} column.
 *
 * <p><strong>Why this exists.</strong> {@link WktGeometryType} hands the text
 * straight to PostgreSQL, which parses it with {@code geometry_in} while
 * planning the statement. Everything it dislikes comes back as a
 * {@link org.springframework.dao.DataIntegrityViolationException} — a 500 with
 * no field name — even though every one of them is the caller's mistake:</p>
 *
 * <pre>
 * ERROR: parse error - invalid geometry
 * ERROR: Geometry type (Polygon) does not match column type (Point)
 * ERROR: Geometry SRID (3857) does not match column SRID (4326)
 * ERROR: Geometry has Z dimension but column does not
 * </pre>
 *
 * <p>Each is rejected here instead, as {@code VSP-ERR-VALIDATION-008} naming the
 * offending field — the same code the golfer-facing geometry-corrections
 * endpoint already answers with for a shape PostGIS would not store.</p>
 *
 * <p><strong>One check PostGIS does not make.</strong> A self-intersecting
 * polygon is stored happily; {@code ST_IsValid} only reports on it afterwards,
 * and every consumer of that shape then computes nonsense. The golfer path
 * rejects those, so this does too — validity is decided by JTS, which
 * implements the same OGC rules as {@code ST_IsValid}, without a round trip to
 * the database.</p>
 *
 * <p>A {@code null} geometry is not an error: the admin update DTOs use null to
 * mean "leave this column alone".</p>
 */
public final class WktGeometryValidator {

    /** EWKT prefix, e.g. {@code SRID=4326;POINT(...)}. */
    private static final Pattern SRID_PREFIX = Pattern.compile("^SRID=(\\d+);", Pattern.CASE_INSENSITIVE);

    private WktGeometryValidator() {
    }

    /**
     * Validates WKT destined for a {@code geometry(Geometry,4326)} column —
     * any shape, as long as it is one PostGIS would store and one that is valid.
     *
     * @param wkt   the caller's WKT, or null when the field was not supplied
     * @param field request field name, reported back so the caller knows which one
     */
    public static void requireValid(String wkt, String field) {
        require(wkt, field, null);
    }

    /**
     * Validates WKT destined for a {@code geometry(Point,4326)} column.
     * A polygon here is rejected by PostgreSQL, so it is rejected here.
     */
    public static void requirePoint(String wkt, String field) {
        require(wkt, field, Point.class);
    }

    private static void require(String wkt, String field, Class<? extends Geometry> expected) {
        if (wkt == null) {
            return;
        }
        String body = wkt.trim();
        if (body.isEmpty()) {
            reject(field, "geometry is blank", expected);
        }

        Matcher srid = SRID_PREFIX.matcher(body);
        if (srid.find()) {
            if (Integer.parseInt(srid.group(1)) != WktGeometryType.SRID) {
                reject(field, "SRID must be " + WktGeometryType.SRID + ", got " + srid.group(1), expected);
            }
            body = body.substring(srid.end()).trim();
        }

        Geometry geometry;
        try {
            geometry = new WKTReader().read(body);
        } catch (ParseException | IllegalArgumentException e) {
            reject(field, "not parseable as WKT", expected);
            return; // unreachable — reject always throws
        }

        if (geometry == null || geometry.isEmpty()) {
            reject(field, "geometry is empty", expected);
        }
        if (hasZ(geometry)) {
            // The columns are 2D; PostgreSQL answers "Geometry has Z dimension
            // but column does not" and drops the whole statement.
            reject(field, "geometry carries a Z ordinate; the column is 2D", expected);
        }
        if (expected != null && !expected.isInstance(geometry)) {
            reject(field, "expected " + expected.getSimpleName().toUpperCase()
                    + ", got " + geometry.getGeometryType().toUpperCase(), expected);
        }
        if (!geometry.isValid()) {
            // Self-intersecting ring, and the like. PostGIS would store it.
            reject(field, "geometry is not valid (e.g. a self-intersecting ring)", expected);
        }
    }

    private static boolean hasZ(Geometry geometry) {
        for (Coordinate c : geometry.getCoordinates()) {
            if (!Double.isNaN(c.getZ())) {
                return true;
            }
        }
        return false;
    }

    private static void reject(String field, String reason, Class<? extends Geometry> expected) {
        throw new VspApiException(
                VspErrorCode.VALIDATION_008,
                VspErrorCode.VALIDATION_008.getDefaultMessage() + " (" + field + "): " + reason,
                field,
                Map.of("reason", reason,
                        "expectedType", expected == null ? "GEOMETRY" : expected.getSimpleName().toUpperCase(),
                        "expectedSrid", WktGeometryType.SRID));
    }
}
