package vnpt.vsp.module.course.imports;

import org.springframework.stereotype.Component;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.util.Map;
import java.util.Set;

/**
 * Maps GeoJSON geometry type + properties to target entity type and required FK lookups.
 * Per Story 3.4 AC-1: geometry type to entity mapping for 10 feature types.
 *
 * <p>Geometry type → entity mapping:</p>
 * <ul>
 *   <li>Point + landmark_type → Landmark</li>
 *   <li>Point + pin_position_type → PinPosition</li>
 *   <li>LineString + path_type → CartPath</li>
 *   <li>LineString (no path_type) → OutOfBounds</li>
 *   <li>Polygon + tee_set_id → TeeBox</li>
 *   <li>Polygon + no special prop → FairwaySegment, Green, Bunker, WaterHazard, PenaltyArea</li>
 * </ul>
 */
@Component
public class FeatureTypeMapper {

    private static final Set<String> POINT_TYPES = Set.of("Point", "POINT");
    private static final Set<String> LINE_TYPES = Set.of("LineString", "LINESTRING", "MultiLineString", "MULTILINESTRING");
    private static final Set<String> POLYGON_TYPES = Set.of("Polygon", "POLYGON", "MultiPolygon", "MULTIPOLYGON");

    /**
     * Target entity type for import.
     */
    public enum TargetEntity {
        TEE_BOX("TeeBox"),
        FAIRWAY_SEGMENT("FairwaySegment"),
        GREEN("Green"),
        BUNKER("Bunker"),
        WATER_HAZARD("WaterHazard"),
        PENALTY_AREA("PenaltyArea"),
        OUT_OF_BOUNDS("OutOfBounds"),
        CART_PATH("CartPath"),
        LANDMARK("Landmark"),
        PIN_POSITION("PinPosition"),
        UNKNOWN("Unknown");

        private final String entityName;

        TargetEntity(String entityName) {
            this.entityName = entityName;
        }

        public String getEntityName() { return entityName; }
    }

    /**
     * Map a parsed feature to its target entity type.
     *
     * @param feature the parsed GeoJSON feature
     * @return the target entity type
     */
    public TargetEntity mapToEntity(ParsedFeature feature) {
        String geometryType = feature.getGeometryType();
        Map<String, Object> properties = feature.getProperties();

        if (properties == null) {
            properties = Map.of();
        }

        // Point features
        if (POINT_TYPES.contains(geometryType)) {
            String landmarkType = getStringProperty(properties, "landmark_type");
            String pinPositionType = getStringProperty(properties, "pin_position_type");

            if (landmarkType != null && !landmarkType.isBlank()) {
                return TargetEntity.LANDMARK;
            }
            if (pinPositionType != null && !pinPositionType.isBlank()) {
                return TargetEntity.PIN_POSITION;
            }
            // Default Point to Landmark if has name
            String name = getStringProperty(properties, "name");
            if (name != null && !name.isBlank()) {
                return TargetEntity.LANDMARK;
            }
        }

        // LineString features
        if (LINE_TYPES.contains(geometryType)) {
            String pathType = getStringProperty(properties, "path_type");
            if (pathType != null && !pathType.isBlank()) {
                return TargetEntity.CART_PATH;
            }
            return TargetEntity.OUT_OF_BOUNDS;
        }

        // Polygon features
        if (POLYGON_TYPES.contains(geometryType)) {
            String teeSetId = getStringProperty(properties, "tee_set_id");
            String holeId = getStringProperty(properties, "hole_id");
            String hazardType = getStringProperty(properties, "hazard_type");
            String featureType = getStringProperty(properties, "feature_type");

            if (teeSetId != null && holeId != null) {
                return TargetEntity.TEE_BOX;
            }

            // Use feature_type property to distinguish
            if (featureType != null) {
                return switch (featureType.toLowerCase()) {
                    case "fairway", "fairway_segment" -> TargetEntity.FAIRWAY_SEGMENT;
                    case "green" -> TargetEntity.GREEN;
                    case "bunker", "sand", "bunker_area" -> TargetEntity.BUNKER;
                    case "water", "water_hazard", "waterhazard" -> TargetEntity.WATER_HAZARD;
                    case "penalty", "penalty_area", "penaltyarea" -> TargetEntity.PENALTY_AREA;
                    case "out_of_bounds", "ob", "outofbounds" -> TargetEntity.OUT_OF_BOUNDS;
                    default -> TargetEntity.FAIRWAY_SEGMENT; // default
                };
            }

            // Infer from hazard_type
            if (hazardType != null) {
                String ht = hazardType.toLowerCase();
                if (ht.contains("water")) return TargetEntity.WATER_HAZARD;
                if (ht.contains("penalty")) return TargetEntity.PENALTY_AREA;
                if (ht.contains("bunker") || ht.contains("sand")) return TargetEntity.BUNKER;
            }

            // Default polygon to FairwaySegment
            return TargetEntity.FAIRWAY_SEGMENT;
        }

        return TargetEntity.UNKNOWN;
    }

    /**
     * Get required FK attribute names for a target entity.
     */
    public String[] getRequiredFks(TargetEntity entity) {
        return switch (entity) {
            case TEE_BOX -> new String[]{"hole_id", "tee_set_id"};
            case FAIRWAY_SEGMENT, GREEN, BUNKER, WATER_HAZARD, PENALTY_AREA -> new String[]{"hole_id"};
            case LANDMARK -> new String[]{"hole_id"};
            case PIN_POSITION -> new String[]{"hole_id"};
            case CART_PATH, OUT_OF_BOUNDS -> new String[]{"hole_id"};
            case UNKNOWN -> new String[]{};
        };
    }

    /**
     * Get required attribute names (non-FK) for a target entity.
     */
    public String[] getRequiredAttributes(TargetEntity entity) {
        return switch (entity) {
            case TEE_BOX -> new String[]{};
            case FAIRWAY_SEGMENT, GREEN, BUNKER, WATER_HAZARD, PENALTY_AREA, OUT_OF_BOUNDS -> new String[]{};
            case CART_PATH -> new String[]{"path_type"};
            case LANDMARK -> new String[]{"landmark_type", "name"};
            case PIN_POSITION -> new String[]{"pin_position_type"};
            case UNKNOWN -> new String[]{};
        };
    }

    /**
     * Get the PostGIS geometry type keyword for a target entity.
     */
    public String getPostgisGeometryType(TargetEntity entity) {
        return switch (entity) {
            case TEE_BOX, GREEN, BUNKER, PENALTY_AREA -> "Polygon";
            case FAIRWAY_SEGMENT, WATER_HAZARD, OUT_OF_BOUNDS -> "Geometry";
            case CART_PATH -> "LineString";
            case LANDMARK, PIN_POSITION -> "Point";
            case UNKNOWN -> "Geometry";
        };
    }

    private String getStringProperty(Map<String, Object> properties, String key) {
        if (properties == null) return null;
        Object value = properties.get(key);
        if (value == null) {
            // Case-insensitive lookup
            for (Map.Entry<String, Object> entry : properties.entrySet()) {
                if (entry.getKey().equalsIgnoreCase(key)) {
                    value = entry.getValue();
                    break;
                }
            }
        }
        if (value == null) return null;
        return value.toString();
    }
}
