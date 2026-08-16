package vnpt.vsp.module.geometry.vision;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Reading a hole off the satellite picture.
 *
 * <p>Nine hundred holes in this database have a tee point, a green point and
 * nothing else — no fairway, no bunker, no water. Digitising them by hand is
 * the work of months, and the imagery this operator already licenses shows
 * every one of those features plainly. So the model is asked to trace them.
 *
 * <h2>Everything it produces is a proposal</h2>
 *
 * <p>Drafts, in the same queue a golfer's geometry correction goes to, for a
 * human to accept against the same image. Nothing here writes to the live
 * geometry tables. A model that traces a car park as a bunker is not a
 * disaster in a review queue; it is a disaster on a golfer's map with a
 * distance measured to it.
 *
 * <h2>What it is told</h2>
 *
 * <p>Image coordinates, not coordinates on Earth: a model cannot see
 * latitude, and asked for it will produce confident numbers near whatever
 * centre it was given. Fractions of the frame are a thing it can actually
 * measure, and {@link ImageBounds} converts them back.
 */
@Service
public class HoleGeometryVisionService {

    private static final Logger log =
            LoggerFactory.getLogger(HoleGeometryVisionService.class);

    private static final int MAX_TOKENS = 4000;

    /// How far around the tee-to-green line to look, in degrees — roughly
    /// 120 m, enough to catch the bunkers and the water beside a hole
    /// without pulling in the next fairway.
    private static final double MARGIN_DEGREES = 0.0011;

    private final EntityManager em;
    private final SatelliteImageService satellite;
    private final VisionProvider vision;
    private final VisionGeometryReader reader;

    public HoleGeometryVisionService(EntityManager em,
                                     SatelliteImageService satellite,
                                     VisionProvider vision,
                                     ObjectMapper objectMapper) {
        this.em = em;
        this.satellite = satellite;
        this.vision = vision;
        this.reader = new VisionGeometryReader(objectMapper);
    }

    /**
     * Traces one hole and files what it found as drafts.
     *
     * @return how many proposals were filed, per layer
     */
    // No `::` casts in these queries. Hibernate parses a native query for
    // named parameters before Postgres sees it, and `location::geometry`
    // reads to that parser as a parameter called "geometry" — the same trap
    // that took the scorecard publish guard down.
    @Transactional
    public Map<String, Integer> detect(Long courseId, int holeNumber, String requestedBy) {
        if (!satellite.isConfigured()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "satellite",
                    Map.of("satellite", "no licensed satellite imagery is configured"));
        }
        if (!vision.isConfigured()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "model",
                    Map.of("model", "no vision model is configured on this server"));
        }

        Hole hole = hole(courseId, holeNumber);
        if (hole == null) {
            throw new VspApiException(VspErrorCode.HOLE_001, "holeNumber");
        }

        var image = satellite.fetch(
                Math.min(hole.teeLat, hole.greenLat) - MARGIN_DEGREES,
                Math.min(hole.teeLng, hole.greenLng) - MARGIN_DEGREES,
                Math.max(hole.teeLat, hole.greenLat) + MARGIN_DEGREES,
                Math.max(hole.teeLng, hole.greenLng) + MARGIN_DEGREES);
        if (image == null) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "satellite",
                    Map.of("satellite", "the satellite imagery could not be fetched"));
        }

        String answer = vision.analyzeImage(image.png(), "image/png",
                prompt(hole, image.bounds()), MAX_TOKENS);
        List<DetectedFeature> detected = reader.read(answer, image.bounds());

        var counts = new java.util.LinkedHashMap<String, Integer>();
        for (DetectedFeature feature : detected) {
            save(courseId, hole.id, feature, requestedBy, image.attribution());
            counts.merge(feature.layerType().name(), 1, Integer::sum);
        }
        log.info("Satellite reading of course {} hole {} proposed {} feature(s): {}",
                courseId, holeNumber, detected.size(), counts);
        return counts;
    }

    /**
     * The prompt.
     *
     * <p>The refusals matter more than the instructions. A model asked to
     * outline a golf hole will outline something whatever the picture holds,
     * and an invented bunker that reaches review looks exactly like a real
     * one — the reviewer is looking at the same ambiguous image.
     */
    private String prompt(Hole hole, ImageBounds bounds) {
        double[] teeAt = bounds.fractionOf(hole.teeLat, hole.teeLng);
        double[] greenAt = bounds.fractionOf(hole.greenLat, hole.greenLng);
        return """
                You are tracing one golf hole from a satellite image so its shapes
                can be reviewed by a human editor.

                THIS HOLE: number %d, par %d. In THIS image the teeing ground
                is at about x=%.3f, y=%.3f and the green at about x=%.3f,
                y=%.3f — the same fractions you will answer in. Everything you
                trace belongs to the hole those two points define; the image
                also shows parts of neighbouring holes, which are not yours.

                RETURN STRICT JSON, no prose, no code fence:
                {"features": [{"layer": "...", "name": "...", "confidence": 0.0,
                  "polygon": [[x, y], [x, y], ...]}]}

                COORDINATES: x and y are fractions of the image, 0 to 1. x is
                measured from the LEFT edge, y from the TOP edge. Do not output
                latitude, longitude, pixels or metres — only fractions.

                LAYERS you may use, and nothing else:
                  green          the putting surface only, not its surrounds
                  bunker         one polygon per sand trap, however small
                  water_hazard   ponds, lakes, streams
                  fairway        the mown corridor between tee and green
                  tee            the teeing ground platforms
                  rough          only where it is clearly a distinct mown band
                  out_of_bounds  a line along a boundary, where one is visible
                  landmark       trees or wooded areas beside the hole

                RULES:
                - Trace only what you can actually see in THIS image. If the
                  green is hidden by cloud or shadow, omit it. A shape you are
                  guessing at is worse than a missing shape: a reviewer looking
                  at the same picture cannot tell the difference, and a wrong
                  bunker becomes a distance a golfer trusts on the tee.
                - 6 to 30 points per polygon. Follow the edge; do not return
                  rectangles for things that are not rectangular.
                - confidence is your own, 0 to 1. Be honest — 0.4 for a shape
                  half in shadow is more useful than 0.9 for everything.
                - Do not outline the whole image, the clubhouse, roads, car
                  parks, buildings or neighbouring holes.
                - The fairway is this hole's mown corridor, not the whole
                  green expanse in the picture. Where you cannot tell this
                  fairway from the next one, omit it.
                - The tee polygon is the platform at the point given above,
                  not another hole's tee that happens to be in frame.
                - Return an empty features array if this image does not show a
                  golf hole.
                """.formatted(hole.number, hole.par,
                teeAt[0], teeAt[1], greenAt[0], greenAt[1]);
    }

    /// Files one proposal in the review queue.
    private void save(Long courseId, Long holeId, DetectedFeature feature,
                      String requestedBy, String attribution) {
        em.createNativeQuery("""
                INSERT INTO draft_geometry_features
                    (feature_uuid, course_id, hole_id, layer_type, geometry,
                     is_valid, feature_name, external_feature_id,
                     publisher, source, license, accuracy_class,
                     verification_status, confidence, model_version,
                     effective_date, version, created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :hole, :layer,
                        ST_AsText(ST_SetSRID(ST_GeomFromText(:wkt), 4326)),
                        true, :name, :externalId,
                        :publisher, 'ai-satellite', :license,
                        -- Not C_VERIFIED_SATELLITE: that class means a human
                        -- digitised it off imagery. A model traced this and
                        -- nobody has looked yet, which is exactly what the
                        -- community class means.
                        'D_UNVERIFIED_COMMUNITY',
                        'PENDING_REVIEW', :confidence, :modelVersion,
                        CURRENT_DATE, 0, now(), now())
                ON CONFLICT (course_id, layer_type, hole_id, external_feature_id)
                DO UPDATE SET geometry = EXCLUDED.geometry,
                              confidence = EXCLUDED.confidence,
                              model_version = EXCLUDED.model_version,
                              updated_at = now()
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeId)
                .setParameter("layer", feature.layerType().name())
                .setParameter("wkt", feature.toWkt())
                .setParameter("name", feature.name())
                .setParameter("externalId",
                        "ai:" + feature.layerType().name().toLowerCase()
                                + ":" + Math.abs(feature.toWkt().hashCode()))
                .setParameter("publisher", "ai-satellite:" + requestedBy)
                .setParameter("license", attribution)
                .setParameter("confidence", BigDecimal.valueOf(feature.confidence() * 100)
                        .setScale(2, java.math.RoundingMode.HALF_UP))
                .setParameter("modelVersion", vision.modelVersion())
                .executeUpdate();
    }

    /// The hole's two known points. Without both there is nothing to frame
    /// an image around, which is every hole this project has not loaded a
    /// card for.
    private Hole hole(Long courseId, int holeNumber) {
        var rows = em.createNativeQuery("""
                SELECT h.id, h.hole_number, h.par,
                       ST_Y(CAST(h.teeing_ground_location AS geometry)), ST_X(CAST(h.teeing_ground_location AS geometry)),
                       ST_Y(CAST(h.green_location AS geometry)), ST_X(CAST(h.green_location AS geometry))
                FROM holes h
                WHERE h.course_id = :course AND h.hole_number = :hole
                  AND h.teeing_ground_location IS NOT NULL AND h.green_location IS NOT NULL
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .getResultList();
        if (rows.isEmpty()) {
            return null;
        }
        Object[] r = (Object[]) rows.get(0);
        var hole = new Hole();
        hole.id = ((Number) r[0]).longValue();
        hole.number = ((Number) r[1]).intValue();
        hole.par = r[2] == null ? 4 : ((Number) r[2]).intValue();
        hole.teeLat = ((Number) r[3]).doubleValue();
        hole.teeLng = ((Number) r[4]).doubleValue();
        hole.greenLat = ((Number) r[5]).doubleValue();
        hole.greenLng = ((Number) r[6]).doubleValue();
        return hole;
    }

    private static final class Hole {
        Long id;
        int number;
        int par;
        double teeLat;
        double teeLng;
        double greenLat;
        double greenLng;
    }
}
