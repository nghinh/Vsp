package vnpt.vsp.module.geometry.golfseg;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Filing what the segmentation model traced.
 *
 * <p>Into the same table, through the same door, as OpenStreetMap and as a
 * human's survey — {@code draft_geometry_features}. That is the whole point of
 * having kept it: a new source of geometry is a new value in a column, not a
 * new pipeline.
 *
 * <p>It files with {@code source = 'golfseg'}, which places it below
 * OpenStreetMap in the rule the feature endpoint already applies: where a
 * person has drawn a layer on a course, the model's version of that layer is
 * not served beside it. So this fills the courses and the classes nobody
 * mapped, and stays out of the way where somebody did.
 */
@Service
public class GolfSegImportService {

    private static final Logger log =
            LoggerFactory.getLogger(GolfSegImportService.class);

    /// What the model must be sure of before its shape is worth a reviewer's
    /// time. Measured: the trained baseline reaches 0.53 IoU on greens, and
    /// the shapes it is least sure about are the ones that are wrong.
    private static final double MINIMUM_VISION_SCORE = 0.45;

    /// How many of each a single hole can have.
    ///
    /// The area bounds pass a fragment because a fragment is bunker-sized; it
    /// takes counting to notice that the first live run filed fifty-three
    /// bunkers, thirty tees and seven greens on one hole. A hole has one
    /// green. Whatever else the mask says, that is not negotiable, and the
    /// rest are ordered by area so the biggest survive — a shredded mask
    /// leaves the real feature as its largest piece.
    private static int limitFor(String layer) {
        return switch (layer) {
            case "GREEN" -> 1;
            case "FAIRWAY" -> 2;
            case "TEE" -> 4;
            case "BUNKER" -> 8;
            case "WATER_HAZARD" -> 4;
            case "ROUGH" -> 2;
            default -> 4;
        };
    }

    /// What a feature of this kind can plausibly measure, in square metres.
    ///
    /// The same bounds the satellite reader needed, for the same reason and
    /// found the same way: the first live trace of Đường B's opening hole came
    /// back with fifty-three bunkers, the largest of them 33,827 m². That is
    /// three and a half hectares of sand on one golf hole. A segmentation mask
    /// has no idea how big a bunker is; golf does.
    private static boolean isPlausible(String layer, double area) {
        return switch (layer) {
            case "BUNKER" -> area >= 20 && area <= 1_500;
            case "GREEN" -> area >= 200 && area <= 1_400;
            case "TEE" -> area >= 30 && area <= 2_000;
            case "FAIRWAY" -> area >= 2_000 && area <= 60_000;
            case "WATER_HAZARD", "PENALTY_AREA" -> area >= 100 && area <= 200_000;
            case "ROUGH" -> area >= 1_000 && area <= 120_000;
            default -> true;
        };
    }

    private final EntityManager em;
    private final GolfSegClient client;

    public GolfSegImportService(EntityManager em, GolfSegClient client) {
        this.em = em;
        this.client = client;
    }

    /**
     * Traces one hole and files what came back.
     *
     * @return how many shapes were filed, per layer
     */
    // No `::` casts: Hibernate reads them as named parameters.
    @Transactional
    public Map<String, Integer> traceHole(Long courseId, int holeNumber,
                                          String requestedBy) {
        if (!client.isConfigured()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "golfseg",
                    Map.of("golfseg", "no golf vision service is configured"));
        }

        var rows = em.createNativeQuery("""
                SELECT h.id,
                       ST_Y(CAST(h.teeing_ground_location AS geometry)),
                       ST_X(CAST(h.teeing_ground_location AS geometry)),
                       ST_Y(CAST(h.green_location AS geometry)),
                       ST_X(CAST(h.green_location AS geometry))
                FROM holes h
                WHERE h.course_id = :course AND h.hole_number = :hole
                  AND h.teeing_ground_location IS NOT NULL
                  AND h.green_location IS NOT NULL
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .getResultList();
        if (rows.isEmpty()) {
            throw new VspApiException(VspErrorCode.HOLE_001, "holeNumber");
        }
        Object[] row = (Object[]) rows.get(0);
        Long holeId = ((Number) row[0]).longValue();

        JsonNode answer = client.traceHole(courseId, holeNumber,
                ((Number) row[1]).doubleValue(), ((Number) row[2]).doubleValue(),
                ((Number) row[3]).doubleValue(), ((Number) row[4]).doubleValue());
        if (answer == null) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "golfseg",
                    Map.of("golfseg", "the golf vision service could not answer"));
        }

        return file(courseId, holeId, holeNumber, answer, requestedBy);
    }

    /**
     * Files a FeatureCollection somebody else produced.
     *
     * <p>The same filing path, without the call. The vision service runs on a
     * GPU host that this API cannot reach — the API is on a private network and
     * the GPU box is not — and tracing is a batch job rather than something on
     * a request path, so decoupling the two costs nothing and removes a
     * dependency that would have to be kept alive.
     *
     * <p>It also happens to be the door §34 asks for: anything that can produce
     * GeoJSON for a hole — a fine-tuned model, a licensed provider, a human's
     * QGIS export — arrives the same way and is judged by the same rules.
     */
    @Transactional
    public Map<String, Integer> ingest(Long courseId, int holeNumber,
                                       JsonNode featureCollection,
                                       String requestedBy) {
        Long holeId = holeIdOf(courseId, holeNumber);
        return file(courseId, holeId, holeNumber, featureCollection, requestedBy);
    }

    private Long holeIdOf(Long courseId, int holeNumber) {
        var rows = em.createNativeQuery("""
                SELECT h.id FROM holes h
                WHERE h.course_id = :course AND h.hole_number = :hole
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .getResultList();
        if (rows.isEmpty()) {
            throw new VspApiException(VspErrorCode.HOLE_001, "holeNumber");
        }
        return ((Number) rows.get(0)).longValue();
    }

    private Map<String, Integer> file(Long courseId, Long holeId, int holeNumber,
                                      JsonNode answer, String requestedBy) {
        // A re-trace replaces this hole's untouched proposals rather than
        // adding to them — the same rule the satellite reader needed, for the
        // same reason: the polygons differ slightly every run.
        em.createNativeQuery("""
                DELETE FROM draft_geometry_features
                WHERE course_id = :course AND hole_id = :hole
                  AND source = 'golfseg'
                  AND verification_status = 'PENDING_REVIEW'
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeId)
                .executeUpdate();

        String modelVersion = answer.path("metadata").path("checkpoint").asText("golfseg");
        String attribution = answer.path("attribution").asText("");

        // Gather, then keep the largest few of each. Sorting has to happen
        // across the whole answer, so it cannot be done in one pass.
        var candidates = new java.util.HashMap<String, java.util.List<double[]>>();
        var wkts = new java.util.HashMap<String, java.util.List<String>>();
        var visions = new java.util.HashMap<String, java.util.List<Double>>();
        for (JsonNode feature : answer.path("features")) {
            String layer = feature.path("properties").path("label").asText(null);
            double vision = feature.path("properties").path("scores")
                    .path("vision").asDouble(0);
            if (layer == null || vision < MINIMUM_VISION_SCORE) {
                continue;
            }
            double area = feature.path("properties").path("areaM2").asDouble(0);
            if (!isPlausible(layer, area)) {
                continue;
            }
            String wkt = toWkt(feature.path("geometry"));
            if (wkt == null) {
                continue;
            }
            candidates.computeIfAbsent(layer, k -> new java.util.ArrayList<>())
                    .add(new double[]{area, wkts.computeIfAbsent(layer,
                            k -> new java.util.ArrayList<>()).size()});
            wkts.get(layer).add(wkt);
            visions.computeIfAbsent(layer, k -> new java.util.ArrayList<>())
                    .add(vision);
        }

        var counts = new LinkedHashMap<String, Integer>();
        int index = 0;
        for (var entry : candidates.entrySet()) {
            String layer = entry.getKey();
            var byArea = entry.getValue();
            byArea.sort((a, b) -> Double.compare(b[0], a[0]));
            int limit = Math.min(limitFor(layer), byArea.size());
            for (int i = 0; i < limit; i++) {
                int at = (int) byArea.get(i)[1];
                save(courseId, holeId, layer, wkts.get(layer).get(at),
                        visions.get(layer).get(at), modelVersion,
                        attribution, requestedBy, index++);
                counts.merge(layer, 1, Integer::sum);
            }
        }

        log.info("GolfSeg traced course {} hole {}: {}", courseId, holeNumber, counts);
        return counts;
    }

    /// GeoJSON ring to WKT. Only the outer ring: an interior is drawn by the
    /// map from the polygon it sits in, and this table stores one ring.
    private static String toWkt(JsonNode geometry) {
        JsonNode coordinates = geometry.path("coordinates");
        if (!"Polygon".equals(geometry.path("type").asText())
                || !coordinates.isArray() || coordinates.isEmpty()) {
            return null;
        }
        JsonNode ring = coordinates.get(0);
        if (!ring.isArray() || ring.size() < 4) {
            return null;
        }
        var wkt = new StringBuilder("POLYGON((");
        for (int i = 0; i < ring.size(); i++) {
            if (i > 0) {
                wkt.append(", ");
            }
            wkt.append(ring.get(i).get(0).asDouble())
                    .append(' ')
                    .append(ring.get(i).get(1).asDouble());
        }
        return wkt.append("))").toString();
    }

    private void save(Long courseId, Long holeId, String layer, String wkt,
                      double vision, String modelVersion, String attribution,
                      String requestedBy, int index) {
        em.createNativeQuery("""
                INSERT INTO draft_geometry_features
                    (feature_uuid, course_id, hole_id, layer_type, geometry,
                     is_valid, external_feature_id, publisher, source, license,
                     accuracy_class, verification_status, confidence,
                     model_version, effective_date, version, created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :hole, :layer,
                        ST_AsText(ST_SetSRID(ST_GeomFromText(:wkt), 4326)),
                        true, :externalId, :publisher, 'golfseg', :license,
                        -- A model traced it and nobody has looked yet, which is
                        -- exactly what the community class means.
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
                .setParameter("layer", layer)
                .setParameter("wkt", wkt)
                .setParameter("externalId", "golfseg:" + layer.toLowerCase() + ":" + index)
                .setParameter("publisher", "golfseg:" + requestedBy)
                .setParameter("license", attribution)
                .setParameter("confidence", BigDecimal.valueOf(vision * 100)
                        .setScale(2, RoundingMode.HALF_UP))
                .setParameter("modelVersion", modelVersion)
                .executeUpdate();
    }
}
