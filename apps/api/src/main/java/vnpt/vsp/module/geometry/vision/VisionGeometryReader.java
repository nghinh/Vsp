package vnpt.vsp.module.geometry.vision;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import vnpt.vsp.module.geometry.LayerType;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Turns what a vision model says about a satellite image into ground
 * coordinates.
 *
 * <p>The model is asked for polygons in image space — fractions of the width
 * and height — because that is a thing it can actually see. Latitude and
 * longitude are not visible in a picture, and a model asked for them invents
 * plausible numbers near whatever it was told the centre was.
 *
 * <p>Everything is checked before it becomes a proposal: points inside the
 * frame, enough of them to be a shape, a layer this app knows, an area that
 * is not the whole image. A model that returns nonsense should produce no
 * drafts rather than forty for a reviewer to reject one at a time.
 */
public final class VisionGeometryReader {

    private static final Logger log = LoggerFactory.getLogger(VisionGeometryReader.class);

    /// Below this many points a "polygon" is a line or a dot.
    private static final int MIN_POINTS = 4;

    /// A feature covering nearly the whole frame is the model outlining the
    /// image rather than a bunker.
    private static final double MAX_AREA_FRACTION = 0.92;

    private final ObjectMapper objectMapper;

    public VisionGeometryReader(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /**
     * @param json   what the model answered
     * @param bounds the ground extent of the image it was shown
     */
    public List<DetectedFeature> read(String json, ImageBounds bounds) {
        return read(json, bounds, null);
    }

    /**
     * @param image the picture the model was shown, where the edges of the
     *              shapes it named can be taken from the pixels instead of
     *              from its description of them. Null skips the refinement.
     */
    public List<DetectedFeature> read(String json, ImageBounds bounds,
                                      java.awt.image.BufferedImage image) {
        JsonNode root;
        try {
            root = objectMapper.readTree(strip(json));
        } catch (Exception e) {
            log.warn("Vision model returned something that is not JSON: {}", e.getMessage());
            return List.of();
        }

        JsonNode features = root.path("features");
        if (!features.isArray()) {
            log.warn("Vision model returned no features array");
            return List.of();
        }

        var detected = new ArrayList<DetectedFeature>();
        for (JsonNode feature : features) {
            LayerType layer = layerOf(feature.path("layer").asText(null));
            if (layer == null) {
                continue;
            }
            List<double[]> imageRing = fractionsOf(feature.path("polygon"));
            if (imageRing == null) {
                continue;
            }
            // Sand and water are flat in colour and stand out from grass, so
            // their edges can be taken from the picture. A fairway is grass
            // beside grass — there is no edge to find — and a green is grass
            // too, so those keep the model's own outline.
            if (image != null && REFINABLE.contains(layer)) {
                List<double[]> snapped = ShapeRefiner.refine(image, imageRing);
                if (snapped != null) {
                    imageRing = snapped;
                }
            }
            List<double[]> ring = toGround(imageRing, bounds);
            detected.add(new DetectedFeature(
                    layer,
                    feature.path("name").asText(null),
                    clamp(feature.path("confidence").asDouble(0.5)),
                    ring));
        }
        return detected;
    }

    /// Models like to wrap JSON in a fenced block however firmly they are
    /// asked not to.
    private static String strip(String json) {
        String text = json == null ? "" : json.trim();
        if (text.startsWith("```")) {
            int firstBreak = text.indexOf('\n');
            int lastFence = text.lastIndexOf("```");
            if (firstBreak > 0 && lastFence > firstBreak) {
                return text.substring(firstBreak + 1, lastFence).trim();
            }
        }
        return text;
    }

    private static LayerType layerOf(String name) {
        if (name == null) {
            return null;
        }
        String normalised = name.trim().toUpperCase(Locale.ROOT).replace(' ', '_');
        for (LayerType type : LayerType.values()) {
            if (type.name().equals(normalised)) {
                return type;
            }
        }
        // The words a model is likelier to reach for than our column names.
        return switch (normalised) {
            case "WATER", "POND", "LAKE", "HAZARD" -> LayerType.WATER_HAZARD;
            case "SAND", "SAND_TRAP", "TRAP" -> LayerType.BUNKER;
            case "OB", "OUT_OF_BOUND" -> LayerType.OUT_OF_BOUNDS;
            case "TEE_BOX", "TEEING_GROUND" -> LayerType.TEE;
            case "PUTTING_GREEN" -> LayerType.GREEN;
            case "TREES", "TREE", "FOREST", "WOODS" -> LayerType.LANDMARK;
            default -> null;
        };
    }

    /// The layers whose edges are worth taking from the pixels.
    private static final java.util.Set<LayerType> REFINABLE =
            java.util.EnumSet.of(LayerType.BUNKER, LayerType.WATER_HAZARD,
                    LayerType.PENALTY_AREA);

    /// Image fractions to latitude and longitude.
    private static List<double[]> toGround(List<double[]> ring, ImageBounds bounds) {
        var ground = new ArrayList<double[]>(ring.size());
        for (double[] point : ring) {
            ground.add(new double[]{
                    bounds.latitudeAt(point[1]),
                    bounds.longitudeAt(point[0]),
            });
        }
        return ground;
    }

    /**
     * One ring as the model gave it: fractions of the image, validated.
     *
     * <p>Null for anything that is not a usable shape — too few points,
     * outside the frame, or covering almost all of it.
     */
    private static List<double[]> fractionsOf(JsonNode polygon) {
        if (!polygon.isArray() || polygon.size() < MIN_POINTS) {
            return null;
        }
        var ring = new ArrayList<double[]>();
        double minX = 1, maxX = 0, minY = 1, maxY = 0;
        for (JsonNode point : polygon) {
            if (!point.isArray() || point.size() < 2) {
                return null;
            }
            double x = point.get(0).asDouble(-1);
            double y = point.get(1).asDouble(-1);
            if (x < 0 || x > 1 || y < 0 || y > 1) {
                return null;
            }
            minX = Math.min(minX, x);
            maxX = Math.max(maxX, x);
            minY = Math.min(minY, y);
            maxY = Math.max(maxY, y);
            ring.add(new double[]{x, y});
        }
        if ((maxX - minX) * (maxY - minY) > MAX_AREA_FRACTION) {
            return null;
        }
        // Close the ring if the model left it open.
        double[] first = ring.get(0);
        double[] last = ring.get(ring.size() - 1);
        if (first[0] != last[0] || first[1] != last[1]) {
            ring.add(new double[]{first[0], first[1]});
        }
        return ring;
    }

    private static double clamp(double confidence) {
        return Math.max(0, Math.min(1, confidence));
    }
}
