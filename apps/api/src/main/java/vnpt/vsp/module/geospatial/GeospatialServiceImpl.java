package vnpt.vsp.module.geospatial;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.prep.PreparedGeometry;
import org.locationtech.jts.geom.prep.PreparedGeometryFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.geospatial.dto.DistanceResult;
import vnpt.vsp.module.geospatial.dto.FeatureDistanceResult;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Implementation of {@link GeospatialService}.
 * Per Story 3.1 GEO-5: PostGIS geometry operations.
 * Uses SRID 4326 (WGS84) for all geometries.
 * PostGIS functions used: ST_IsValid, ST_DWithin, ST_Distance, ST_Within, ST_Contains.
 */
@Service
@GeospatialModule
public class GeospatialServiceImpl implements GeospatialService {

    private static final Logger log = LoggerFactory.getLogger(GeospatialServiceImpl.class);
    private static final int SRID_4326 = 4326;

    private final EntityManager entityManager;

    public GeospatialServiceImpl(EntityManager entityManager) {
        this.entityManager = entityManager;
    }

    /**
     * Validates a geometry using PostGIS ST_IsValid.
     * Per Story 3.1 AC-1/AC-2: all geometries must be valid SRID 4326.
     *
     * <p>The geometry crosses into SQL as WKT rather than as the JTS object.
     * There is no hibernate-spatial on this classpath, so a bound
     * {@code Geometry} arrives as {@code bytea} and
     * {@code ST_SetSRID(bytea, integer)} matches both the geometry and the
     * geography overload — the statement fails with "function is not unique",
     * the {@code catch} below reports it as an invalid geometry, and every
     * geometry in the system is invalid. That is what a course import kept
     * hitting: every feature failed validation, so no import could ever be
     * committed.</p>
     *
     * @param geometry the geometry to validate
     * @return true if valid, false if invalid
     */
    @Override
    public boolean validateGeometry(Geometry geometry) {
        if (geometry == null) {
            return false;
        }
        try {
            // Ensure SRID is set to 4326
            if (geometry.getSRID() != SRID_4326) {
                geometry.setSRID(SRID_4326);
            }
            String sql = "SELECT ST_IsValid(" + geomParam("wkt") + ")";
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("wkt", geometry.toText());
            query.setParameter("srid", SRID_4326);
            Object result = query.getSingleResult();
            return ((Boolean) result);
        } catch (Exception e) {
            log.warn("Geometry validation error: {}", e.getMessage(), e);
            return false;
        }
    }

    /**
     * Validates geometry and throws if invalid.
     * Used by CourseServiceImpl before persisting geometry columns.
     *
     * <p>Thrown through the four-argument constructor deliberately. The
     * two-argument {@code VspApiException(VspErrorCode, String)} takes that
     * string as the <em>field</em> name, not as the message — it calls
     * {@code super(errorCode.getDefaultMessage())} and drops what it was given
     * into {@code field}. So this reason, the one sentence that tells the admin
     * what is wrong with the shape they uploaded, was being filed as a field
     * name and the caller was shown the generic "Request validation failed".
     */
    @Override
    public void assertGeometryValid(Geometry geometry) {
        if (!validateGeometry(geometry)) {
            throw new VspApiException(VspErrorCode.VALIDATION_001,
                    "Geometry is not valid SRID 4326: " + getValidityReason(geometry),
                    null, null);
        }
    }

    /**
     * Calculates the distance between two geometries using PostGIS ST_Distance.
     * Uses geography cast for meter-based results on SRID 4326.
     * Per Story 3.1 AC-2: SRID 4326 distance calculation.
     *
     * @param g1 first geometry
     * @param g2 second geometry
     * @param unit "meters" or "degrees" (defaults to meters via geography cast)
     * @return distance in the requested unit, or null if calculation fails
     */
    @Override
    public BigDecimal calculateDistance(Geometry g1, Geometry g2, String unit) {
        if (g1 == null || g2 == null) {
            return null;
        }
        try {
            ensureSRID(g1);
            ensureSRID(g2);

            String sql;
            if ("degrees".equalsIgnoreCase(unit)) {
                sql = "SELECT ST_Distance(" + geomParam("g1") + ", " + geomParam("g2") + ")";
            } else {
                // Use geography cast for meter-based distance on WGS84
                sql = "SELECT ST_Distance(CAST(" + geomParam("g1") + " AS geography), CAST("
                        + geomParam("g2") + " AS geography))";
            }
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("g1", g1.toText());
            query.setParameter("g2", g2.toText());
            query.setParameter("srid", SRID_4326);
            Object result = query.getSingleResult();
            if (result instanceof BigDecimal) {
                return (BigDecimal) result;
            } else if (result instanceof Double) {
                return BigDecimal.valueOf((Double) result);
            } else if (result instanceof Number) {
                return BigDecimal.valueOf(((Number) result).doubleValue());
            }
            return null;
        } catch (Exception e) {
            log.warn("Distance calculation error between {} and {}: {}", g1.getGeometryType(), g2.getGeometryType(), e.getMessage(), e);
            return null;
        }
    }

    /**
     * Finds features of a given type within a radius of a point using PostGIS ST_DWithin.
     * Per Story 3.1 AC-2: GIST-indexed ST_DWithin query.
     *
     * <p>The table and column are resolved through {@link SpatialFeature} before
     * any SQL is built. They cannot be bound as parameters — no database binds
     * identifiers — so they are concatenated, and concatenating a caller's
     * string into a statement is an injection whatever the caller currently
     * happens to pass. A pair that is not whitelisted is refused here rather
     * than reaching PostgreSQL.
     *
     * @param point center point (must be SRID 4326)
     * @param radiusMeters search radius in meters
     * @param featureType SQL table name to search (e.g., 'greens', 'bunkers', 'water_hazards')
     * @param geometryColumn column name holding the geometry
     * @return list of feature IDs and distances within radius
     * @throws VspApiException if the table and column are not a whitelisted pair
     */
    @Override
    @SuppressWarnings("unchecked")
    public List<FeatureDistanceResult> findFeaturesWithinRadius(
            Point point, double radiusMeters, String featureType, String geometryColumn) {
        SpatialFeature feature = requireWhitelisted(featureType, geometryColumn);
        if (point == null || radiusMeters <= 0) {
            return List.of();
        }
        ensureSRID(point);
        try {
            String probe = "CAST(" + geomParam("point") + " AS geography)";
            String sql = String.format("""
                SELECT id, ST_Distance(CAST(%s AS geography), %s) AS distance
                FROM %s
                WHERE ST_DWithin(CAST(%s AS geography), %s, :radius)
                ORDER BY distance ASC
                """, feature.geometryColumn(), probe, feature.table(),
                    feature.geometryColumn(), probe);

            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("point", point.toText());
            query.setParameter("srid", SRID_4326);
            query.setParameter("radius", radiusMeters);

            List<Object[]> results = query.getResultList();
            return results.stream()
                    .map(row -> new FeatureDistanceResult(
                            ((Number) row[0]).longValue(),
                            row[1] != null ? new BigDecimal(row[1].toString()) : null))
                    .collect(Collectors.toList());
        } catch (Exception e) {
            log.warn("ST_DWithin query error on {}: {}", featureType, e.getMessage(), e);
            return List.of();
        }
    }

    /**
     * Checks if a geometry is fully within another using PostGIS ST_Within.
     * Per Story 3.1 AC-2: ST_Within for containment checks.
     *
     * @param inner geometry to check
     * @param outer containing geometry
     * @return true if inner is completely within outer
     */
    @Override
    public boolean isWithin(Geometry inner, Geometry outer) {
        if (inner == null || outer == null) {
            return false;
        }
        try {
            ensureSRID(inner);
            ensureSRID(outer);
            String sql = "SELECT ST_Within(" + geomParam("inner") + ", " + geomParam("outer") + ")";
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("inner", inner.toText());
            query.setParameter("outer", outer.toText());
            query.setParameter("srid", SRID_4326);
            return ((Boolean) query.getSingleResult());
        } catch (Exception e) {
            log.warn("ST_Within check error: {}", e.getMessage(), e);
            return false;
        }
    }

    /**
     * Checks if a geometry contains another using PostGIS ST_Contains.
     * Per Story 3.1 AC-2: ST_Contains for containment checks.
     *
     * @param outer containing geometry
     * @param inner geometry to check
     * @return true if outer contains inner
     */
    @Override
    public boolean contains(Geometry outer, Geometry inner) {
        if (outer == null || inner == null) {
            return false;
        }
        try {
            ensureSRID(outer);
            ensureSRID(inner);
            String sql = "SELECT ST_Contains(" + geomParam("outer") + ", " + geomParam("inner") + ")";
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("outer", outer.toText());
            query.setParameter("inner", inner.toText());
            query.setParameter("srid", SRID_4326);
            return ((Boolean) query.getSingleResult());
        } catch (Exception e) {
            log.warn("ST_Contains check error: {}", e.getMessage(), e);
            return false;
        }
    }

    /**
     * Finds the nearest feature of a given type to a point.
     * Uses ST_DWithin ordering approach for efficient nearest-neighbor via GIST index.
     * Per Story 3.1 AC-2: GIST-indexed nearest neighbor.
     *
     * <p>Whitelisted the same way as {@link #findFeaturesWithinRadius}: the
     * table and column are resolved through {@link SpatialFeature} before any
     * SQL exists, because they are concatenated and no database will bind an
     * identifier as a parameter.
     *
     * @param point center point (SRID 4326)
     * @param featureType SQL table name
     * @param geometryColumn geometry column name
     * @return nearest feature ID and distance, or null if none found
     * @throws VspApiException if the table and column are not a whitelisted pair
     */
    @Override
    @SuppressWarnings("unchecked")
    public FeatureDistanceResult findNearestFeature(Point point, String featureType, String geometryColumn) {
        SpatialFeature feature = requireWhitelisted(featureType, geometryColumn);
        if (point == null) {
            return null;
        }
        ensureSRID(point);
        try {
            // Use LATERAL with ORDER BY distance for efficient nearest-neighbor via GIST
            String sql = String.format("""
                SELECT id, dist.distance
                FROM %s
                CROSS JOIN LATERAL (
                    SELECT ST_Distance(CAST(%s AS geography), CAST(%s AS geography)) AS distance
                ) AS dist
                ORDER BY dist.distance ASC
                LIMIT 1
                """, feature.table(), feature.geometryColumn(), geomParam("point"));

            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("point", point.toText());
            query.setParameter("srid", SRID_4326);
            List<Object[]> results = query.getResultList();
            if (results.isEmpty()) {
                return null;
            }
            Object[] row = results.get(0);
            return new FeatureDistanceResult(
                    ((Number) row[0]).longValue(),
                    row[1] != null ? new BigDecimal(row[1].toString()) : null);
        } catch (Exception e) {
            log.warn("Nearest feature query error on {}: {}", featureType, e.getMessage(), e);
            return null;
        }
    }

    // ─── Private helpers ───────────────────────────────────────────────────

    /**
     * Resolves a caller's table and column to a whitelisted {@link SpatialFeature},
     * or refuses.
     *
     * <p>Deliberately outside the {@code try} in both callers. Those blocks turn
     * a failed query into an empty result and a warning, which is the right
     * answer for a database that is briefly unhappy and the wrong one for a
     * caller naming a table this service will not query: silently returning
     * "no features" would let a wired-up request parameter look like it worked.
     * A refusal is loud, and it is a 400 rather than a 500 because the caller
     * asked for something that does not exist.
     */
    private static SpatialFeature requireWhitelisted(String featureType, String geometryColumn) {
        return SpatialFeature.of(featureType, geometryColumn)
                .orElseThrow(() -> {
                    log.warn("Refused spatial query for non-whitelisted identifiers: {}.{}",
                            featureType, geometryColumn);
                    return new VspApiException(VspErrorCode.VALIDATION_001,
                            "Not a spatial feature this service queries: "
                                    + featureType + "." + geometryColumn,
                            "featureType", null);
                });
    }

    /**
     * The SQL fragment that turns a bound parameter into a PostGIS geometry.
     *
     * <p>Every geometry in this class reaches SQL through here, as WKT text, and
     * the matching {@code setParameter} binds {@code geometry.toText()}. Binding
     * the JTS object instead is the defect this class was built around: with no
     * hibernate-spatial on the classpath Hibernate has no idea the parameter is a
     * geometry and sends {@code bytea}, and {@code ST_SetSRID(bytea, integer)}
     * matches both the geometry and the geography overload through implicit
     * casts, so PostgreSQL refuses the statement outright — "function
     * st_setsrid(bytea, integer) is not unique". {@code ST_GeomFromText(text,
     * integer)} has no such ambiguity.
     *
     * <p>The {@code CAST(... AS text)} is not decoration: without it the driver
     * can send the parameter as {@code bytea} again and reintroduce exactly the
     * ambiguity this exists to avoid.
     */
    private static String geomParam(String name) {
        return "ST_GeomFromText(CAST(:" + name + " AS text), :srid)";
    }

    private void ensureSRID(Geometry geometry) {
        if (geometry != null && geometry.getSRID() != SRID_4326) {
            geometry.setSRID(SRID_4326);
        }
    }

    /**
     * The human-readable reason a geometry is invalid, e.g. "Self-intersection".
     *
     * <p>Only ever reached from {@link #assertGeometryValid}, i.e. only when a
     * geometry has already been rejected — so while this bound the geometry the
     * broken way, the admin whose import failed was shown "unknown: " followed by
     * the driver's complaint about parameter types, in a message whose whole
     * purpose is to tell them what is wrong with the shape they supplied.
     */
    private String getValidityReason(Geometry geometry) {
        if (geometry == null) return "null geometry";
        try {
            ensureSRID(geometry);
            String sql = "SELECT ST_IsValidReason(" + geomParam("geom") + ")";
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("geom", geometry.toText());
            query.setParameter("srid", SRID_4326);
            return (String) query.getSingleResult();
        } catch (Exception e) {
            log.warn("ST_IsValidReason lookup failed: {}", e.getMessage(), e);
            return "unknown: " + e.getMessage();
        }
    }
}
