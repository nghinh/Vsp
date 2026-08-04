package vnpt.vsp.module.course.imports;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Parses GeoJSON into a list of ParsedFeature.
 * Per Story 3.4 AC-1: GeoJSON import support.
 * Handles FeatureCollection and single Feature.
 */
@Component
public class GeoJsonParser {

    private static final Logger log = LoggerFactory.getLogger(GeoJsonParser.class);
    private final ObjectMapper objectMapper;

    public GeoJsonParser(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /**
     * Parse a GeoJSON string into a list of ParsedFeature.
     *
     * @param geoJson the GeoJSON string
     * @return list of parsed features
     * @throws VspApiException if the GeoJSON is invalid or has no features
     */
    public List<ParsedFeature> parse(String geoJson) {
        if (geoJson == null || geoJson.isBlank()) {
            throw new VspApiException(VspErrorCode.COURSE_IMPORT_001, "GeoJSON content is empty");
        }

        try {
            JsonNode root = objectMapper.readTree(geoJson);

            if (!root.isObject()) {
                throw new VspApiException(VspErrorCode.COURSE_IMPORT_001, "GeoJSON must be a JSON object");
            }

            String type = root.path("type").asText("");
            List<ParsedFeature> features = new ArrayList<>();

            if ("FeatureCollection".equalsIgnoreCase(type)) {
                JsonNode featureArray = root.path("features");
                if (featureArray.isArray()) {
                    int index = 0;
                    for (JsonNode feature : featureArray) {
                        ParsedFeature parsed = parseFeature(feature, index);
                        if (parsed != null) {
                            features.add(parsed);
                        }
                        index++;
                    }
                }
            } else if ("Feature".equalsIgnoreCase(type)) {
                features.add(parseFeature(root, 0));
            } else {
                throw new VspApiException(VspErrorCode.COURSE_IMPORT_001,
                    "Unsupported GeoJSON type: " + type + ". Expected FeatureCollection or Feature");
            }

            if (features.isEmpty()) {
                throw new VspApiException(VspErrorCode.COURSE_IMPORT_002, "No features found in GeoJSON");
            }

            return features;

        } catch (VspApiException e) {
            throw e;
        } catch (Exception e) {
            log.warn("GeoJSON parse error: {}", e.getMessage());
            throw new VspApiException(VspErrorCode.COURSE_IMPORT_001,
                "Invalid GeoJSON format: " + e.getMessage());
        }
    }

    private ParsedFeature parseFeature(JsonNode feature, int index) {
        if (!feature.isObject()) {
            return null;
        }

        JsonNode geometry = feature.path("geometry");
        String geometryType = geometry.path("type").asText("");
        Object coordinates = null;

        if (!geometryType.isEmpty() && !geometry.isNull()) {
            JsonNode coordsNode = geometry.path("coordinates");
            if (!coordsNode.isMissingNode()) {
                try {
                    coordinates = objectMapper.treeToValue(coordsNode, Object.class);
                } catch (Exception e) {
                    log.warn("Failed to parse coordinates at index {}: {}", index, e.getMessage());
                }
            }
        }

        Map<String, Object> properties = null;
        JsonNode propsNode = feature.path("properties");
        if (propsNode.isObject()) {
            try {
                properties = objectMapper.convertValue(propsNode, Map.class);
            } catch (Exception e) {
                log.warn("Failed to parse properties at index {}: {}", index, e.getMessage());
            }
        }

        return new ParsedFeature(index, geometryType, coordinates, properties);
    }
}
