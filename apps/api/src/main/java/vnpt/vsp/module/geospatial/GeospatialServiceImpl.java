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
            String sql = "SELECT ST_IsValid(ST_GeomFromText(CAST(:wkt AS text), :srid))";
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
     */
    @Override
    public void assertGeometryValid(Geometry geometry) {
        if (!validateGeometry(geometry)) {
            throw new VspApiException(VspErrorCode.VALIDATION_001,
                    "Geometry is not valid SRID 4326: " + getValidityReason(geometry));
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
                sql = "SELECT ST_Distance(ST_SetSRID(:g1, :srid), ST_SetSRID(:g2, :srid))";
            } else {
                // Use geography cast for meter-based distance on WGS84
                sql = "SELECT ST_Distance(CAST(ST_SetSRID(:g1, :srid) AS geography), CAST(ST_SetSRID(:g2, :srid) AS geography))";
            }
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("g1", g1);
            query.setParameter("g2", g2);
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
            log.warn("Distance calculation error between {} and {}: {}", g1.getGeometryType(), g2.getGeometryType(), e.getMessage());
            return null;
        }
    }

    /**
     * Finds features of a given type within a radius of a point using PostGIS ST_DWithin.
     * Per Story 3.1 AC-2: GIST-indexed ST_DWithin query.
     *
     * @param point center point (must be SRID 4326)
     * @param radiusMeters search radius in meters
     * @param featureType SQL table name to search (e.g., 'greens', 'bunkers', 'water_hazards')
     * @param geometryColumn column name holding the geometry
     * @return list of feature IDs and distances within radius
     */
    @Override
    @SuppressWarnings("unchecked")
    public List<FeatureDistanceResult> findFeaturesWithinRadius(
            Point point, double radiusMeters, String featureType, String geometryColumn) {
        if (point == null || radiusMeters <= 0) {
            return List.of();
        }
        ensureSRID(point);
        try {
            String sql = String.format("""
                SELECT id, ST_Distance(CAST(%s AS geography), CAST(ST_SetSRID(:point, :srid) AS geography)) AS distance
                FROM %s
                WHERE ST_DWithin(CAST(%s AS geography), CAST(ST_SetSRID(:point, :srid) AS geography), :radius)
                ORDER BY distance ASC
                """, geometryColumn, featureType, geometryColumn);

            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("point", point);
            query.setParameter("srid", SRID_4326);
            query.setParameter("radius", radiusMeters);

            List<Object[]> results = query.getResultList();
            return results.stream()
                    .map(row -> new FeatureDistanceResult(
                            ((Number) row[0]).longValue(),
                            row[1] != null ? new BigDecimal(row[1].toString()) : null))
                    .collect(Collectors.toList());
        } catch (Exception e) {
            log.warn("ST_DWithin query error on {}: {}", featureType, e.getMessage());
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
            String sql = "SELECT ST_Within(ST_SetSRID(:inner, :srid), ST_SetSRID(:outer, :srid))";
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("inner", inner);
            query.setParameter("outer", outer);
            query.setParameter("srid", SRID_4326);
            return ((Boolean) query.getSingleResult());
        } catch (Exception e) {
            log.warn("ST_Within check error: {}", e.getMessage());
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
            String sql = "SELECT ST_Contains(ST_SetSRID(:outer, :srid), ST_SetSRID(:inner, :srid))";
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("outer", outer);
            query.setParameter("inner", inner);
            query.setParameter("srid", SRID_4326);
            return ((Boolean) query.getSingleResult());
        } catch (Exception e) {
            log.warn("ST_Contains check error: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Finds the nearest feature of a given type to a point.
     * Uses ST_DWithin ordering approach for efficient nearest-neighbor via GIST index.
     * Per Story 3.1 AC-2: GIST-indexed nearest neighbor.
     *
     * @param point center point (SRID 4326)
     * @param featureType SQL table name
     * @param geometryColumn geometry column name
     * @return nearest feature ID and distance, or null if none found
     */
    @Override
    @SuppressWarnings("unchecked")
    public FeatureDistanceResult findNearestFeature(Point point, String featureType, String geometryColumn) {
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
                    SELECT ST_Distance(CAST(%s AS geography), CAST(ST_SetSRID(:point, :srid) AS geography)) AS distance
                ) AS dist
                ORDER BY dist.distance ASC
                LIMIT 1
                """, featureType, geometryColumn);

            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("point", point);
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
            log.warn("Nearest feature query error on {}: {}", featureType, e.getMessage());
            return null;
        }
    }

    // ─── Private helpers ───────────────────────────────────────────────────

    private void ensureSRID(Geometry geometry) {
        if (geometry != null && geometry.getSRID() != SRID_4326) {
            geometry.setSRID(SRID_4326);
        }
    }

    private String getValidityReason(Geometry geometry) {
        if (geometry == null) return "null geometry";
        try {
            String sql = "SELECT ST_IsValidReason(ST_SetSRID(:geom, :srid))";
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("geom", geometry);
            query.setParameter("srid", SRID_4326);
            return (String) query.getSingleResult();
        } catch (Exception e) {
            return "unknown: " + e.getMessage();
        }
    }
}
