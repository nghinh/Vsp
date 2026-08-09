package vnpt.vsp.persistence;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryCollection;
import org.locationtech.jts.geom.LineString;
import org.locationtech.jts.geom.MultiLineString;
import org.locationtech.jts.geom.MultiPoint;
import org.locationtech.jts.geom.MultiPolygon;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;
import org.locationtech.jts.io.WKBReader;
import org.locationtech.jts.io.WKTReader;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Reads the geometry an entity carries and renders it as GeoJSON.
 *
 * <p><strong>Why this is not just a WKT parse.</strong> Every geometry column in
 * this schema is mapped through {@link WktGeometryType}, whose contract is
 * asymmetric on purpose: a value <em>written</em> is WKT, but a value
 * <em>read back</em> is whatever JDBC returns, and for PostGIS that is hex
 * EWKB — {@code 0101000020E6100000...}, not {@code POINT(...)}. A caller that
 * assumes WKT works against a freshly-set in-memory entity and returns nothing
 * for every row actually loaded from the database, which is the silent-empty
 * failure mode this class exists to prevent.</p>
 *
 * <p>So both encodings are accepted, along with the {@code SRID=4326;} prefix
 * {@link WktGeometryType} adds on write. Anything unparseable yields
 * {@link Optional#empty()} rather than an exception: one malformed row must not
 * abort a whole course package build, and an absent feature is honest where a
 * guessed one is not.</p>
 */
public final class StoredGeometry {

    private StoredGeometry() {}

    /**
     * Renders stored geometry as a GeoJSON geometry object.
     *
     * @return the GeoJSON {@code {"type":…, "coordinates":…}} map, or empty when
     *         the value is null, blank, or cannot be parsed.
     */
    public static Optional<Map<String, Object>> toGeoJson(String stored) {
        return parse(stored).flatMap(StoredGeometry::render);
    }

    /** Parses stored geometry into JTS, accepting hex EWKB or (E)WKT. */
    public static Optional<Geometry> parse(String stored) {
        if (stored == null || stored.isBlank()) {
            return Optional.empty();
        }
        String value = stored.trim();
        try {
            if (isHex(value)) {
                return Optional.ofNullable(new WKBReader().read(WKBReader.hexToBytes(value)));
            }
            return Optional.ofNullable(new WKTReader().read(stripSrid(value)));
        } catch (Exception exception) {
            return Optional.empty();
        }
    }

    /**
     * Hex EWKB is an even-length run of hex digits. WKT always contains a
     * letter outside {@code A-F} (or a bracket), so the two cannot be confused.
     */
    private static boolean isHex(String value) {
        if (value.length() < 2 || value.length() % 2 != 0) {
            return false;
        }
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            boolean hexDigit = (c >= '0' && c <= '9')
                    || (c >= 'a' && c <= 'f')
                    || (c >= 'A' && c <= 'F');
            if (!hexDigit) {
                return false;
            }
        }
        return true;
    }

    /** {@code SRID=4326;POINT(...)} → {@code POINT(...)}. */
    private static String stripSrid(String value) {
        if (value.regionMatches(true, 0, "SRID=", 0, 5)) {
            int semicolon = value.indexOf(';');
            if (semicolon >= 0) {
                return value.substring(semicolon + 1).trim();
            }
        }
        return value;
    }

    private static Optional<Map<String, Object>> render(Geometry geometry) {
        if (geometry.isEmpty()) {
            return Optional.empty();
        }
        if (geometry instanceof Point point) {
            return Optional.of(geoJson("Point", coordinate(point.getCoordinate())));
        }
        if (geometry instanceof LineString line) {
            return Optional.of(geoJson("LineString", coordinates(line.getCoordinates())));
        }
        if (geometry instanceof Polygon polygon) {
            return Optional.of(geoJson("Polygon", rings(polygon)));
        }
        if (geometry instanceof MultiPoint multiPoint) {
            return Optional.of(geoJson("MultiPoint", coordinates(multiPoint.getCoordinates())));
        }
        if (geometry instanceof MultiLineString multiLine) {
            List<Object> lines = new ArrayList<>();
            for (int i = 0; i < multiLine.getNumGeometries(); i++) {
                lines.add(coordinates(multiLine.getGeometryN(i).getCoordinates()));
            }
            return Optional.of(geoJson("MultiLineString", lines));
        }
        if (geometry instanceof MultiPolygon multiPolygon) {
            List<Object> polygons = new ArrayList<>();
            for (int i = 0; i < multiPolygon.getNumGeometries(); i++) {
                polygons.add(rings((Polygon) multiPolygon.getGeometryN(i)));
            }
            return Optional.of(geoJson("MultiPolygon", polygons));
        }
        if (geometry instanceof GeometryCollection collection) {
            List<Object> members = new ArrayList<>();
            for (int i = 0; i < collection.getNumGeometries(); i++) {
                render(collection.getGeometryN(i)).ifPresent(members::add);
            }
            if (members.isEmpty()) {
                return Optional.empty();
            }
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("type", "GeometryCollection");
            result.put("geometries", members);
            return Optional.of(result);
        }
        return Optional.empty();
    }

    private static Map<String, Object> geoJson(String type, Object coordinates) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("type", type);
        result.put("coordinates", coordinates);
        return result;
    }

    private static List<Object> rings(Polygon polygon) {
        List<Object> rings = new ArrayList<>();
        rings.add(coordinates(polygon.getExteriorRing().getCoordinates()));
        for (int i = 0; i < polygon.getNumInteriorRing(); i++) {
            rings.add(coordinates(polygon.getInteriorRingN(i).getCoordinates()));
        }
        return rings;
    }

    private static List<Object> coordinates(Coordinate[] coordinates) {
        List<Object> points = new ArrayList<>(coordinates.length);
        for (Coordinate coordinate : coordinates) {
            points.add(coordinate(coordinate));
        }
        return points;
    }

    /** GeoJSON orders coordinates longitude-first. */
    private static List<Double> coordinate(Coordinate coordinate) {
        return List.of(coordinate.getX(), coordinate.getY());
    }
}
