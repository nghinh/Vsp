package vnpt.vsp.module.geometry;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * The model-traced shapes of one hole, and the single set of rules for which
 * of them may be shown.
 *
 * <p><strong>Why this exists.</strong> These rules lived inside
 * {@code HoleFeatureController}, so they applied to the endpoint the map calls
 * when it is online and to nothing else. The offline package was assembled
 * from the curated tables alone — {@code bunkers}, {@code greens},
 * {@code tee_boxes} — which on a traced course are empty. Long Biên is the
 * case that showed it: 488 traced shapes across its three nines on the
 * endpoint, and a downloadable package of 640 bytes a hole holding one tee
 * point and one green point. A golfer who downloaded the course for a round
 * with no signal got two dots.</p>
 *
 * <p>Both readers now ask the same question of the same table, so a shape a
 * golfer can see online is a shape they can see on the 6th with no bars, and
 * a rule tightened for one is tightened for both.</p>
 */
@Component
public class TracedHoleGeometry {

    /** One traced shape, with the provenance that must travel beside it. */
    public record TracedFeature(
            String layer,
            Map<String, Object> geometry,
            BigDecimal confidence,
            String source,
            String verificationStatus,
            String modelVersion,
            String name,
            boolean verified) {}

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final EntityManager em;
    private final BigDecimal minimumConfidence;

    public TracedHoleGeometry(
            EntityManager em,
            @Value("${vsp.vision.minimum-confidence:40}") int minimumConfidence) {
        this.em = em;
        this.minimumConfidence = BigDecimal.valueOf(minimumConfidence);
    }

    /** The confidence floor in force, for callers that report it. */
    public BigDecimal minimumConfidence() {
        return minimumConfidence;
    }

    /**
     * Every condition that decides whether a shape may be shown at all.
     *
     * <p>One string, used by the reader that serves shapes and by the count
     * that badges a course, so "what a golfer sees" and "what the badge
     * describes" cannot drift apart. Takes {@code :course} and {@code :floor};
     * callers add their own hole filter.</p>
     */
    private static final String VISIBLE_SHAPES = """
                FROM draft_geometry_features d
                JOIN holes h ON h.id = d.hole_id
                WHERE d.course_id = :course
                  AND d.is_valid
                  -- One floor, and it is set to catch garbage rather than to
                  -- grade shapes. GolfSeg's "confidence" is the mean softmax
                  -- probability over a class's own winning mask, which is a
                  -- per-class quantity on a per-class scale: a fairway is one
                  -- large homogeneous region and scores 82-93, a bunker is
                  -- thirty pixels across and mostly soft edge and scores
                  -- 49-88. Comparing them against one number compares nothing.
                  --
                  -- At 65 the effect, measured across every traced course, was
                  -- to discard 29% of bunkers and 18% of water hazards and 0%
                  -- of greens, fairways and tees. It was not a quality gate,
                  -- it was a bunker-and-water gate that fired by accident of
                  -- scale — and Long Biên's Đường B lost all eight bunkers on
                  -- its 1st at 62.04 and all four ponds at 48.44, on a hole a
                  -- golfer was standing on.
                  --
                  -- Nor does the number rank shapes within a class, which is
                  -- the only comparison it could honestly make. Checked
                  -- against the OSM-mapped courses: bunkers below 65 hit a
                  -- mapped bunker 10% of the time and bunkers above it 9%;
                  -- water 34% below and 36% above. The shapes it drops are the
                  -- same size as the ones it keeps (median bunker 674 m2
                  -- against 614 m2). It is not separating good from bad
                  -- because it does not know which is which.
                  --
                  -- What it does separate is a photograph from a blank sheet.
                  -- Shown Esri's flat placeholder the model returned 116
                  -- shapes at 22; real shapes on real imagery bottom out at
                  -- 48. The floor sits between those two populations and
                  -- nowhere near anything a golfer would want to see. Blank
                  -- imagery is now refused at the fetcher too (see
                  -- looks_blank), so this is the second line, not the first.
                  --
                  -- The shapes this lets through are unreviewed and the app
                  -- draws them as such: faint, dashed, and labelled. That is
                  -- the trade this reader exists to make.
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
                  --
                  -- The model fills in behind the mapper; it does not argue
                  -- with them. On a hole where a person drew this layer, only
                  -- their shapes go out — a hole has one green, and the
                  -- mapper's green beside the model's is unambiguous nonsense.
                  -- On a hole where nobody drew it, the model's shapes go out,
                  -- because the alternative is a hole with water on the ground
                  -- and nothing on the map.
                  --
                  -- That second half is new, and it is the whole point. There
                  -- used to be a second rule above this one that asked whether
                  -- a person had drawn the layer across *most of the course*,
                  -- and silenced the model course-wide when they had. On Long
                  -- Biên's Đường A a mapper drew one pond on each of five holes
                  -- out of nine; five doubled clears nine, so all 33 ponds
                  -- GolfSeg found were hidden — including sixteen on holes 1,
                  -- 5, 7 and 8, where nobody had drawn any water at all and the
                  -- map therefore showed none. The satellite photograph of
                  -- hole 2 has a lake across the middle of it.
                  --
                  -- KNOWN CONSEQUENCE, recorded rather than hidden: this mixes
                  -- OSM and non-OSM geometry inside one (course, layer) — the
                  -- five mapped ponds and the sixteen traced ones now share
                  -- Đường A's water layer. ODbL's horizontal-layers guidance
                  -- treats a mixed layer as a Derivative Database rather than a
                  -- Collective one, which would put our own traced polygons
                  -- under share-alike. The previous rule bought that separation
                  -- at the cost of blank holes. Choosing the golfer over the
                  -- separation is a licensing decision, and it was taken
                  -- deliberately; the way out, if it has to be taken back, is
                  -- to pick one source per (course, layer) by coverage rather
                  -- than to hide the model.
                  AND (d.source NOT IN ('ai-satellite', 'golfseg') OR NOT EXISTS (
                        SELECT 1 FROM draft_geometry_features here
                        WHERE here.course_id = d.course_id
                          AND here.hole_id = d.hole_id
                          AND here.layer_type = d.layer_type
                          AND here.is_valid
                          AND here.source NOT IN ('ai-satellite', 'golfseg')
                          AND here.verification_status <> 'REJECTED'))
                """;

    /**
     * The shapes of one hole, in the order the map draws them.
     *
     * <p>Where a person has drawn this layer on this hole, the model's
     * attempt at it is not shown beside theirs. It is not a second opinion a
     * golfer can weigh — it is the same green in the wrong place, and two
     * greens on one hole is worse than either alone.</p>
     */
    @SuppressWarnings("unchecked")
    public List<TracedFeature> forHole(Long courseId, int holeNumber) {
        var rows = em.createNativeQuery("""
                SELECT d.layer_type,
                       ST_AsGeoJSON(ST_GeomFromText(d.geometry, 4326)),
                       d.confidence, d.source, d.verification_status,
                       d.model_version, d.feature_name
                """ + VISIBLE_SHAPES + """
                  AND h.hole_number = :hole
                ORDER BY d.layer_type
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .setParameter("floor", minimumConfidence)
                .getResultList();

        var features = new ArrayList<TracedFeature>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            features.add(new TracedFeature(
                    layerOf((String) r[0]),
                    (Map<String, Object>) parse((String) r[1]),
                    (BigDecimal) r[2],
                    (String) r[3],
                    (String) r[4],
                    (String) r[5],
                    (String) r[6],
                    // What the app needs to draw it differently: nobody has
                    // checked this against the ground yet.
                    "VERIFIED".equals(r[4])));
        }
        return features;
    }

    /**
     * How many of the shapes this course actually shows nobody has checked.
     *
     * <p>For the course badge, which was answering a different question from
     * the map. Long Biên's every hole row says {@code VERIFIED /
     * C_VERIFIED_SATELLITE}, so the listing badged it verified — while 465 of
     * the 488 shapes drawn on its map came from GolfSeg and no person had
     * looked at any of them. A golfer reading "đã kiểm định" was being told
     * the sand was where the sand is.</p>
     *
     * <p>Counted through {@link #VISIBLE_SHAPES}, so it counts what a golfer
     * is shown and not what happens to sit in the table. A shape withheld by
     * the confidence floor is not a shape anybody has to trust.</p>
     */
    public long unreviewedShapes(Long courseId) {
        Object count = em.createNativeQuery("""
                SELECT count(*)
                """ + VISIBLE_SHAPES + """
                  AND d.verification_status <> 'VERIFIED'
                """)
                .setParameter("course", courseId)
                .setParameter("floor", minimumConfidence)
                .getSingleResult();
        return ((Number) count).longValue();
    }

    private static Object parse(String geoJson) {
        try {
            return MAPPER.readValue(geoJson, Map.class);
        } catch (Exception e) {
            return Map.of();
        }
    }

    /// The names the app's map already knows, so these features land in the
    /// same layers as a surveyed course's and are drawn by the same styles.
    public static String layerOf(String layerType) {
        return switch (layerType) {
            case "WATER_HAZARD" -> "water";
            case "PENALTY_AREA" -> "penaltyArea";
            case "OUT_OF_BOUNDS" -> "ob";
            case "CART_PATH" -> "cartPath";
            default -> layerType.toLowerCase(Locale.ROOT);
        };
    }
}
