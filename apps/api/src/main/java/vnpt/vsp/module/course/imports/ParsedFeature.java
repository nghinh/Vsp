package vnpt.vsp.module.course.imports;

import java.util.Map;

/**
 * Intermediate DTO representing a parsed GeoJSON feature.
 * Per Story 3.4: parsed from GeoJSON before entity mapping and validation.
 */
public class ParsedFeature {

    private int index;
    private String geometryType;
    private Object coordinates;
    private Map<String, Object> properties;

    public ParsedFeature() {}

    public ParsedFeature(int index, String geometryType, Object coordinates, Map<String, Object> properties) {
        this.index = index;
        this.geometryType = geometryType;
        this.coordinates = coordinates;
        this.properties = properties;
    }

    public int getIndex() { return index; }
    public void setIndex(int index) { this.index = index; }
    public String getGeometryType() { return geometryType; }
    public void setGeometryType(String geometryType) { this.geometryType = geometryType; }
    public Object getCoordinates() { return coordinates; }
    public void setCoordinates(Object coordinates) { this.coordinates = coordinates; }
    public Map<String, Object> getProperties() { return properties; }
    public void setProperties(Map<String, Object> properties) { this.properties = properties; }

    /**
     * Get a property value by name, case-insensitive.
     */
    public Object getProperty(String name) {
        if (properties == null) return null;
        // Case-insensitive lookup
        for (Map.Entry<String, Object> entry : properties.entrySet()) {
            if (entry.getKey().equalsIgnoreCase(name)) {
                return entry.getValue();
            }
        }
        return null;
    }
}
