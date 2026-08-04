package vnpt.vsp.module.geometry;

/**
 * Enumeration of editable geometry layer types for the course map editor.
 * Per PRD §9.1, Architecture §10, and Story 3.1 AC-1.
 *
 * <p>Each layer type corresponds to a PostGIS geometry column and has an
 * associated JTS geometry type used for validation.</p>
 */
public enum LayerType {

    TEE("tee", "Tee", "Point"),
    FAIRWAY("fairway", "Fairway", "Polygon"),
    ROUGH("rough", "Rough", "Polygon"),
    GREEN("green", "Green", "Polygon"),
    BUNKER("bunker", "Bunker", "Polygon"),
    WATER_HAZARD("water_hazard", "Water Hazard", "Polygon"),
    PENALTY_AREA("penalty_area", "Penalty Area", "Polygon"),
    OUT_OF_BOUNDS("out_of_bounds", "Out of Bounds", "LineString"),
    CART_PATH("cart_path", "Cart Path", "LineString"),
    LANDMARK("landmark", "Landmark", "Point");

    private final String tableName;
    private final String displayName;
    private final String geometryType;

    LayerType(String tableName, String displayName, String geometryType) {
        this.tableName = tableName;
        this.displayName = displayName;
        this.geometryType = geometryType;
    }

    public String getTableName() {
        return tableName;
    }

    public String getDisplayName() {
        return displayName;
    }

    public String getGeometryType() {
        return geometryType;
    }
}
