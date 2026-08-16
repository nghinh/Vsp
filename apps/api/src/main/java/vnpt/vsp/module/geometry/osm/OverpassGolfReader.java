package vnpt.vsp.module.geometry.osm;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import vnpt.vsp.module.geometry.LayerType;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Overpass JSON to shapes this app can file.
 *
 * <p>What arrives is a mapper's work, not a model's, so the checks here are
 * different in kind from the ones the satellite reader needs. Nothing has to
 * be argued out of a hallucination. What does have to be handled is that OSM
 * carries far more than golf: a way tagged {@code golf=cartpath} is a line
 * and not an area, {@code golf=hole} is the whole hole corridor rather than a
 * feature on it, and a driving range is not something to measure a shot to.
 */
public final class OverpassGolfReader {

    private static final Logger log = LoggerFactory.getLogger(OverpassGolfReader.class);

    /// Fewer than four points cannot close into an area.
    private static final int MIN_POINTS = 4;

    private final ObjectMapper objectMapper;

    public OverpassGolfReader(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public List<OsmGolfFeature> read(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        JsonNode root;
        try {
            root = objectMapper.readTree(json);
        } catch (Exception e) {
            log.warn("Overpass returned something that is not JSON: {}", e.getMessage());
            return List.of();
        }

        var features = new ArrayList<OsmGolfFeature>();
        for (JsonNode element : root.path("elements")) {
            if (!"way".equals(element.path("type").asText())) {
                continue;
            }
            LayerType layer = layerOf(element.path("tags"));
            if (layer == null) {
                continue;
            }
            // A cart path is a line and never closes; everything else is an
            // area and must.
            boolean isLine = layer == LayerType.CART_PATH;
            List<double[]> ring = ringOf(element.path("geometry"), isLine);
            if (ring == null) {
                continue;
            }
            features.add(new OsmGolfFeature(layer,
                    element.path("id").asLong(),
                    element.path("tags").path("name").asText(null),
                    ring));
        }
        return features;
    }

    /**
     * Which of our layers a set of OSM tags belongs in, or null to skip it.
     *
     * <p>The tags come from the OSM golf schema, which most Vietnamese
     * courses are mapped in. Anything outside the list is skipped rather than
     * guessed at: an unrecognised tag on a golf course is as likely to be a
     * hedge or a maintenance shed as a hazard.
     */
    static LayerType layerOf(JsonNode tags) {
        String golf = tags.path("golf").asText(null);
        if (golf != null) {
            return switch (golf.trim().toLowerCase(Locale.ROOT)) {
                case "green" -> LayerType.GREEN;
                case "bunker", "sand_trap" -> LayerType.BUNKER;
                case "fairway" -> LayerType.FAIRWAY;
                case "tee" -> LayerType.TEE;
                case "rough" -> LayerType.ROUGH;
                case "water_hazard", "lateral_water_hazard" -> LayerType.WATER_HAZARD;
                // A cart path is a line rather than an area, and nobody aims
                // at one — but the loop they form is the outline of the golf
                // course, which is the only thing that tells a segmentation
                // model that the houses next door are not part of it.
                case "cartpath", "path", "cart_path" -> LayerType.CART_PATH;
                // hole, clubhouse, driving_range, pin: either not a feature or
                // not something on the course.
                default -> null;
            };
        }
        // A pond inside a course is a hazard whether or not a mapper reached
        // for the golf schema — most tag it natural=water and stop there.
        if ("water".equals(tags.path("natural").asText(null))) {
            return LayerType.WATER_HAZARD;
        }
        return null;
    }

    /// The points of a way — closed for an area, open for a line.
    private static List<double[]> ringOf(JsonNode geometry, boolean isLine) {
        if (!geometry.isArray() || geometry.size() < (isLine ? 2 : MIN_POINTS)) {
            return null;
        }
        var ring = new ArrayList<double[]>(geometry.size());
        for (JsonNode point : geometry) {
            if (!point.has("lat") || !point.has("lon")) {
                return null;
            }
            ring.add(new double[]{point.get("lat").asDouble(),
                    point.get("lon").asDouble()});
        }
        if (isLine) {
            return ring;
        }
        double[] first = ring.get(0);
        double[] last = ring.get(ring.size() - 1);
        if (first[0] != last[0] || first[1] != last[1]) {
            // An open way is a path, a wall or a fence — not an area, however
            // it is tagged.
            return null;
        }
        return ring;
    }
}
