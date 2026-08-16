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
import vnpt.vsp.module.geometry.golfseg.GolfSegImportService;
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
    private final GolfSegImportService golfSeg;
    private final BigDecimal minimumConfidence;
    private final int dailyLimit;

    public HoleFeatureController(
            EntityManager em,
            CourseMappingService mappingService,
            GolfSegImportService golfSeg,
            @Value("${vsp.vision.minimum-confidence:65}") int minimumConfidence,
            @Value("${vsp.vision.golfer-daily-limit:30}") int dailyLimit) {
        this.em = em;
        this.mappingService = mappingService;
        this.golfSeg = golfSeg;
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

        // Traced on the spot rather than queued. GolfSeg answers in about
        // three seconds, which is inside what a golfer will wait for on a tee
        // — and a queued job they have to come back for is a job they never
        // come back for. The queue existed because the model it replaced took
        // a metered call and half a minute.
        try {
            var filed = golfSeg.traceHole(courseId, holeNumber, requestedBy);
            int total = filed.values().stream().mapToInt(Integer::intValue).sum();
            log.info("GolfSeg traced course {} hole {} on request: {}",
                    courseId, holeNumber, filed);
            return Map.of("status", "READY", "tracedNow", true,
                    "featuresDetected", total, "perLayer", filed);
        } catch (VspApiException notAvailable) {
            // No vision service on this deployment, or it could not answer.
            // The hole stays as it was, which is how every hole was before any
            // of this existed — said plainly rather than dressed as a failure.
            log.info("GolfSeg unavailable for course {} hole {}: {}",
                    courseId, holeNumber, notAvailable.getMessage());
            return Map.of("status", "UNAVAILABLE", "tracedNow", false,
                    "featuresDetected", 0);
        }
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
                  -- Course-wide, not hole-by-hole, for two reasons that agree.
                  -- A course whose greens are real on holes 1 and 9 and the
                  -- model's on the other seven is one where nothing on screen
                  -- can be trusted more than the worst of it. And ODbL's
                  -- horizontal-layers guideline draws the same line: mixing
                  -- OSM and non-OSM geometry within one feature type in one
                  -- regional cut makes the whole layer a Derivative Database.
                  -- Keeping each (course, layer) to a single source keeps it a
                  -- Collective Database, and our own work our own.
                  --
                  -- Model-drawn sources live in one list. A third arriving is
                  -- a value here, not another branch: golfseg is judged by the
                  -- rule the satellite reader was, because the question is the
                  -- same one — did a person draw this layer?
                  -- ...but only where a person drew that layer across most of
                  -- the course. Đường B has three bunkers in OpenStreetMap and
                  -- about twenty on the ground; letting those three silence
                  -- every bunker the model found left holes with visible sand
                  -- and nothing drawn on it. Three scattered polygons are not
                  -- coverage. Nine greens on nine holes are.
                  --
                  -- On this hole, always. A hole has one green: showing the
                  -- mapper's and the model's side by side is unambiguous
                  -- nonsense whatever the rest of the course looks like.
                  AND (d.source NOT IN ('ai-satellite', 'golfseg') OR NOT EXISTS (
                        SELECT 1 FROM draft_geometry_features here
                        WHERE here.course_id = d.course_id
                          AND here.hole_id = d.hole_id
                          AND here.layer_type = d.layer_type
                          AND here.is_valid
                          AND here.source NOT IN ('ai-satellite', 'golfseg')
                          AND here.verification_status <> 'REJECTED'))
                  AND (d.source NOT IN ('ai-satellite', 'golfseg') OR NOT EXISTS (
                        SELECT 1 FROM (
                            SELECT count(DISTINCT surveyed.hole_id) AS drawn,
                                   (SELECT count(*) FROM holes hh
                                    WHERE hh.course_id = d.course_id) AS holes
                            FROM draft_geometry_features surveyed
                            WHERE surveyed.course_id = d.course_id
                              AND surveyed.layer_type = d.layer_type
                              AND surveyed.is_valid
                              AND surveyed.source NOT IN ('ai-satellite', 'golfseg')
                              AND surveyed.verification_status <> 'REJECTED'
                        ) coverage
                        WHERE coverage.holes > 0
                          AND coverage.drawn * 2 >= coverage.holes))
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
