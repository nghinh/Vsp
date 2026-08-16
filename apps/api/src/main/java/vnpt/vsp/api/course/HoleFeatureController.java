package vnpt.vsp.api.course;

import jakarta.persistence.EntityManager;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The shapes of one hole, as GeoJSON the map can draw.
 *
 * <p>Everything traced from satellite imagery so far. It is served to
 * golfers deliberately, before a human has reviewed it, because a hole drawn
 * approximately is worth more than two dots on an empty screen — but every
 * feature says what it is: {@code source} and {@code confidence} travel with
 * it, and the app draws unreviewed shapes differently and says so.
 *
 * <p>Below the confidence floor nothing is served at all. A shape the model
 * itself doubts is a shape a golfer would measure a distance to.
 */
@RestController
@Validated
public class HoleFeatureController {

    private final EntityManager em;
    private final BigDecimal minimumConfidence;

    public HoleFeatureController(
            EntityManager em,
            @Value("${vsp.vision.minimum-confidence:65}") int minimumConfidence) {
        this.em = em;
        this.minimumConfidence = BigDecimal.valueOf(minimumConfidence);
    }

    @GetMapping("/courses/{courseId}/holes/{holeNumber}/features")
    @Transactional(readOnly = true)
    public Map<String, Object> features(
            @PathVariable Long courseId,
            @PathVariable @Min(1) @Max(18) int holeNumber) {

        var rows = em.createNativeQuery("""
                SELECT d.layer_type,
                       ST_AsGeoJSON(ST_GeomFromText(d.geometry, 4326)),
                       d.confidence, d.source, d.verification_status,
                       d.model_version, d.feature_name
                FROM draft_geometry_features d
                JOIN holes h ON h.id = d.hole_id
                WHERE d.course_id = :course AND h.hole_number = :hole
                  AND d.is_valid
                  AND coalesce(d.confidence, 0) >= :floor
                  AND d.verification_status <> 'REJECTED'
                ORDER BY d.layer_type
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .setParameter("floor", minimumConfidence)
                .getResultList();

        var features = new ArrayList<Map<String, Object>>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            var properties = new LinkedHashMap<String, Object>();
            properties.put("layerType", layerOf((String) r[0]));
            properties.put("confidence", r[2]);
            properties.put("source", r[3]);
            properties.put("verificationStatus", r[4]);
            properties.put("modelVersion", r[5]);
            properties.put("name", r[6]);
            // What the app needs to draw it differently: nobody has checked
            // this against the ground yet.
            properties.put("verified", "VERIFIED".equals(r[4]));

            var feature = new LinkedHashMap<String, Object>();
            feature.put("type", "Feature");
            feature.put("geometry", new com.fasterxml.jackson.databind.ObjectMapper()
                    .convertValue(parse((String) r[1]), Map.class));
            feature.put("properties", properties);
            features.add(feature);
        }

        var collection = new LinkedHashMap<String, Object>();
        collection.put("type", "FeatureCollection");
        collection.put("features", features);
        return collection;
    }

    private static Object parse(String geoJson) {
        try {
            return new com.fasterxml.jackson.databind.ObjectMapper()
                    .readValue(geoJson, Map.class);
        } catch (Exception e) {
            return Map.of();
        }
    }

    /// The names the app's map already knows, so these features land in the
    /// same layers as a surveyed course's and are drawn by the same styles.
    private static String layerOf(String layerType) {
        return switch (layerType) {
            case "WATER_HAZARD" -> "water";
            case "PENALTY_AREA" -> "penaltyArea";
            case "OUT_OF_BOUNDS" -> "ob";
            case "CART_PATH" -> "cartPath";
            default -> layerType.toLowerCase(java.util.Locale.ROOT);
        };
    }
}
