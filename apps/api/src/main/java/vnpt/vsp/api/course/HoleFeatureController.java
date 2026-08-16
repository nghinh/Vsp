package vnpt.vsp.api.course;

import jakarta.persistence.EntityManager;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.geometry.vision.CourseMappingService;

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

    private static final org.slf4j.Logger log =
            org.slf4j.LoggerFactory.getLogger(HoleFeatureController.class);

    private final EntityManager em;
    private final CourseMappingService mappingService;
    private final BigDecimal minimumConfidence;
    private final int dailyLimit;

    public HoleFeatureController(
            EntityManager em,
            CourseMappingService mappingService,
            @Value("${vsp.vision.minimum-confidence:65}") int minimumConfidence,
            @Value("${vsp.vision.golfer-daily-limit:30}") int dailyLimit) {
        this.em = em;
        this.mappingService = mappingService;
        this.minimumConfidence = BigDecimal.valueOf(minimumConfidence);
        this.dailyLimit = dailyLimit;
    }

    /**
     * Asks for this hole to be traced, because nothing has drawn it yet.
     *
     * <p>The golfer standing on an unmapped tee is the person who needs it
     * and the only one who knows they are there, so they may ask — but each
     * request is a metered model call, and a golfer flicking through
     * eighteen holes would otherwise spend eighteen of them.
     *
     * <p>Three gates: a hole that already has shapes is answered with those
     * rather than traced again, one hole is never queued twice at once, and
     * an account gets a fixed number of requests a day.
     */
    @PostMapping("/courses/{courseId}/holes/{holeNumber}/features/request")
    @Transactional
    public Map<String, Object> request(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable @Min(1) @Max(18) int holeNumber) {

        String requestedBy = "golfer:" + authentication.getPrincipal();
        log.info("POST /courses/{}/holes/{}/features/request - {}",
                courseId, holeNumber, requestedBy);

        // Already drawn: answer with that rather than pay to draw it twice.
        Object existing = features(courseId, holeNumber).get("features");
        if (existing instanceof List<?> drawn && !drawn.isEmpty()) {
            return Map.of("status", "READY", "alreadyTraced", true,
                    "featuresDetected", drawn.size());
        }
        if (mappingService.runsToday(requestedBy) >= dailyLimit) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "limit",
                    Map.of("limit", "daily satellite-analysis limit reached"));
        }

        var jobId = mappingService.request(courseId, holeNumber, requestedBy);
        return mappingService.status(jobId);
    }

    @GetMapping("/courses/{courseId}/holes/{holeNumber}/features")
    @Transactional(readOnly = true)
    public Map<String, Object> features(
            @PathVariable Long courseId,
            @PathVariable @Min(1) @Max(18) int holeNumber) {

        // Where a person has drawn this layer on this hole, the model's
        // attempt at it is not shown beside theirs. It is not a second
        // opinion a golfer can weigh — it is the same green in the wrong
        // place, and two greens on one hole is worse than either alone.
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
                  -- A model-drawn fairway is the one shape on this map that
                  -- is both the largest thing on screen and carries no number
                  -- a golfer plays to. Long Biên's first came back as a
                  -- teardrop 57 m wide over a corridor that plays 35, filling
                  -- the screen and making the correct green beside it look
                  -- like part of the same mistake. It stays in the review
                  -- queue for somebody to correct; it does not go out.
                  AND NOT (d.source = 'ai-satellite'
                           AND d.layer_type IN ('FAIRWAY', 'ROUGH'))
                  AND (d.source <> 'ai-satellite' OR NOT EXISTS (
                        SELECT 1 FROM draft_geometry_features surveyed
                        WHERE surveyed.course_id = d.course_id
                          AND surveyed.hole_id = d.hole_id
                          AND surveyed.layer_type = d.layer_type
                          AND surveyed.is_valid
                          AND surveyed.source <> 'ai-satellite'
                          AND surveyed.verification_status <> 'REJECTED'))
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

        // Logged because its absence was unreadable: a screen showing no
        // shapes and a server showing no request look identical when the
        // request writes nothing down.
        log.info("GET /courses/{}/holes/{}/features - {} shape(s) above {}",
                courseId, holeNumber, features.size(), minimumConfidence);

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
