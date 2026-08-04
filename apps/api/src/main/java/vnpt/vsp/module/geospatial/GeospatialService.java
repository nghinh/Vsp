package vnpt.vsp.module.geospatial;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import vnpt.vsp.module.geospatial.dto.FeatureDistanceResult;

import java.math.BigDecimal;
import java.util.List;

/**
 * Geospatial module public service interface.
 * Exposes PostGIS geometry and spatial query operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 * Per Story 3.1 GEO-5: ST_IsValid, ST_DWithin, ST_Distance, ST_Within, ST_Contains.
 */
public interface GeospatialService {

    /**
     * Validates a geometry using PostGIS ST_IsValid.
     * Per Story 3.1 AC-1/AC-2: all geometries must be valid SRID 4326.
     *
     * @param geometry the geometry to validate
     * @return true if valid, false if invalid or null
     */
    boolean validateGeometry(Geometry geometry);

    /**
     * Validates geometry and throws VspApiException if invalid.
     * Used by CourseServiceImpl before persisting geometry columns.
     */
    void assertGeometryValid(Geometry geometry);

    /**
     * Calculates the distance between two geometries using PostGIS ST_Distance.
     * Uses geography cast for meter-based results on SRID 4326.
     * Per Story 3.1 AC-2: SRID 4326 distance calculation.
     *
     * @param g1 first geometry
     * @param g2 second geometry
     * @param unit "meters" or "degrees" (defaults to meters via geography cast)
     * @return distance in meters, or null if calculation fails
     */
    BigDecimal calculateDistance(Geometry g1, Geometry g2, String unit);

    /**
     * Finds features of a given type within a radius of a point using PostGIS ST_DWithin.
     * Per Story 3.1 AC-2: GIST-indexed ST_DWithin query.
     *
     * @param point center point (SRID 4326)
     * @param radiusMeters search radius in meters
     * @param featureType SQL table name to search
     * @param geometryColumn column name holding the geometry
     * @return list of feature IDs and distances within radius
     */
    List<FeatureDistanceResult> findFeaturesWithinRadius(
            Point point, double radiusMeters, String featureType, String geometryColumn);

    /**
     * Checks if a geometry is fully within another using PostGIS ST_Within.
     *
     * @param inner geometry to check
     * @param outer containing geometry
     * @return true if inner is completely within outer
     */
    boolean isWithin(Geometry inner, Geometry outer);

    /**
     * Checks if a geometry contains another using PostGIS ST_Contains.
     *
     * @param outer containing geometry
     * @param inner geometry to check
     * @return true if outer contains inner
     */
    boolean contains(Geometry outer, Geometry inner);

    /**
     * Finds the nearest feature of a given type to a point using GIST-indexed LATERAL query.
     * Per Story 3.1 AC-2: GIST-indexed nearest neighbor.
     *
     * @param point center point (SRID 4326)
     * @param featureType SQL table name
     * @param geometryColumn geometry column name
     * @return nearest feature ID and distance, or null if none found
     */
    FeatureDistanceResult findNearestFeature(Point point, String featureType, String geometryColumn);
}
