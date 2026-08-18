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
import vnpt.vsp.module.geometry.TracedHoleGeometry;
import vnpt.vsp.module.geometry.golfseg.GolfSegImportService;
import vnpt.vsp.module.geometry.vision.CourseMappingService;

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
 * <p>Below the confidence floor nothing is served at all — but see
 * {@code minimum-confidence} for what that floor can and cannot decide. It
 * catches the model hallucinating over a blank tile. It does not rank one real
 * shape above another.
 */
@RestController
@Validated
public class HoleFeatureController {

    private static final org.slf4j.Logger log =
            org.slf4j.LoggerFactory.getLogger(HoleFeatureController.class);

    private final EntityManager em;
    private final CourseMappingService mappingService;
    private final GolfSegImportService golfSeg;
    private final TracedHoleGeometry tracedGeometry;
    private final int dailyLimit;

    public HoleFeatureController(
            EntityManager em,
            CourseMappingService mappingService,
            GolfSegImportService golfSeg,
            TracedHoleGeometry tracedGeometry,
            @Value("${vsp.vision.golfer-daily-limit:30}") int dailyLimit) {
        this.em = em;
        this.mappingService = mappingService;
        this.golfSeg = golfSeg;
        this.tracedGeometry = tracedGeometry;
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

        // Which shapes may be shown is not decided here. It is decided once,
        // in TracedHoleGeometry, so that the offline package a golfer
        // downloads holds the same shapes this endpoint serves — it used to
        // hold a tee point and a green point and nothing else.
        var traced = tracedGeometry.forHole(courseId, holeNumber);

        var features = new ArrayList<Map<String, Object>>();
        for (var t : traced) {
            var properties = new LinkedHashMap<String, Object>();
            properties.put("layerType", t.layer());
            properties.put("confidence", t.confidence());
            properties.put("source", t.source());
            properties.put("verificationStatus", t.verificationStatus());
            properties.put("modelVersion", t.modelVersion());
            properties.put("name", t.name());
            properties.put("verified", t.verified());

            var feature = new LinkedHashMap<String, Object>();
            feature.put("type", "Feature");
            feature.put("geometry", t.geometry());
            feature.put("properties", properties);
            features.add(feature);
        }

        // Logged because its absence was unreadable: a screen showing no
        // shapes and a server showing no request look identical when the
        // request writes nothing down.
        log.info("GET /courses/{}/holes/{}/features - {} shape(s) above {}",
                courseId, holeNumber, features.size(),
                tracedGeometry.minimumConfidence());

        var collection = new LinkedHashMap<String, Object>();
        collection.put("type", "FeatureCollection");
        collection.put("features", features);
        return collection;
    }

}
