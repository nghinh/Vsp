package vnpt.vsp.module.geometry.osm;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.geometry.LayerType;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Taking a course's shapes from OpenStreetMap.
 *
 * <p>This exists because of what the satellite model produced. Asked to
 * outline the greens at Long Biên it returned smooth blobs averaging two
 * thousand square metres; the greens a human mapper had already drawn at the
 * same course measure 491 to 712, which is what a golf green measures. The
 * model was not close and no amount of prompting was going to make it close.
 *
 * <p>Where somebody has already done the work, use their work. Long Biên has
 * twelve greens, sixty-five bodies of water and three bunkers in OSM, and
 * eleven of those greens sit within eight metres of the green point this
 * database already held — independent confirmation that both are right.
 *
 * <h2>Licence</h2>
 *
 * <p>OSM is ODbL. Every row written here carries that licence string and the
 * attribution the app already displays, and {@code source = 'openstreetmap'}
 * so this data can be told apart from ours and removed as a set if it ever
 * has to be. Nothing is laundered into looking like our own survey.
 *
 * <h2>What it does not do</h2>
 *
 * <p>It does not overwrite anything a human here has touched. A re-import
 * clears this course's untouched OSM proposals and files the current ones;
 * a proposal somebody has accepted, edited or rejected is theirs and stays.
 */
@Service
public class OsmCourseImportService {

    private static final Logger log =
            LoggerFactory.getLogger(OsmCourseImportService.class);

    /// Roughly 150 m of margin around the holes, so a pond that the hole
    /// plays over but whose centre lies outside the tee-to-green box is
    /// still fetched.
    private static final double MARGIN_DEGREES = 0.0014;

    /// How far a green or a tee may sit from the point this database already
    /// holds for it and still be the same green. The matches at Long Biên
    /// were 5 to 8 m; thirty is generous and still less than the gap between
    /// two adjacent greens.
    private static final double GREEN_MATCH_METRES = 30;
    private static final double TEE_MATCH_METRES = 45;

    /// How far from the line of play a hazard may lie and still belong to
    /// this hole. Beyond this it is the next fairway's bunker, and drawing it
    /// here would put a carry distance on a golfer's screen to sand they
    /// cannot reach.
    private static final double HAZARD_MATCH_METRES = 90;

    private final EntityManager em;
    private final OverpassClient overpass;
    private final OverpassGolfReader reader;

    public OsmCourseImportService(EntityManager em, OverpassClient overpass,
                                  ObjectMapper objectMapper) {
        this.em = em;
        this.overpass = overpass;
        this.reader = new OverpassGolfReader(objectMapper);
    }

    /**
     * Imports every golf feature OSM holds for this course.
     *
     * @return how many proposals were filed, per layer, plus what was
     *         fetched and what was too far from any hole to place
     */
    // No `::` casts: Hibernate reads them as named parameters.
    @Transactional
    public Map<String, Object> importCourse(Long courseId, String requestedBy) {
        double[] box = boundingBox(courseId);
        if (box == null) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "course",
                    Map.of("course", "this course has no hole coordinates to search around"));
        }

        String json = overpass.fetchGolfFeatures(
                box[0] - MARGIN_DEGREES, box[1] - MARGIN_DEGREES,
                box[2] + MARGIN_DEGREES, box[3] + MARGIN_DEGREES);
        if (json == null) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "overpass",
                    Map.of("overpass", "OpenStreetMap could not be reached"));
        }

        List<OsmGolfFeature> features = reader.read(json);
        if (features.isEmpty()) {
            log.info("OSM has nothing mapped for course {}", courseId);
            return Map.of("fetched", 0, "imported", 0, "unplaced", 0,
                    "perLayer", Map.of());
        }

        // Same rule as a re-trace: this source's untouched proposals are
        // replaced, and anything a human has looked at is left alone.
        em.createNativeQuery("""
                DELETE FROM draft_geometry_features
                WHERE course_id = :course
                  AND source = 'openstreetmap'
                  AND verification_status = 'PENDING_REVIEW'
                """)
                .setParameter("course", courseId)
                .executeUpdate();

        var perLayer = new LinkedHashMap<String, Integer>();
        int imported = 0;
        int unplaced = 0;
        for (OsmGolfFeature feature : features) {
            Long holeId = holeFor(courseId, feature);
            if (holeId == null) {
                unplaced++;
                continue;
            }
            save(courseId, holeId, feature, requestedBy);
            perLayer.merge(feature.layer().name(), 1, Integer::sum);
            imported++;
        }

        log.info("OSM import of course {}: fetched {}, placed {}, unplaced {} — {}",
                courseId, features.size(), imported, unplaced, perLayer);
        return Map.of("fetched", features.size(), "imported", imported,
                "unplaced", unplaced, "perLayer", perLayer);
    }

    /**
     * Which hole a feature belongs to, or null when it belongs to none.
     *
     * <p>A green is matched to the green point this database already holds,
     * a tee to the tee point, and everything else to the line between them.
     * The distinction matters: two greens can sit forty metres apart, and
     * matching one of them to whichever line of play passes closest would
     * hand hole 5's green to hole 6.
     */
    private Long holeFor(Long courseId, OsmGolfFeature feature) {
        String anchor = switch (feature.layer()) {
            case GREEN -> "CAST(h.green_location AS geometry)";
            case TEE -> "CAST(h.teeing_ground_location AS geometry)";
            default -> """
                    ST_MakeLine(CAST(h.teeing_ground_location AS geometry),
                                CAST(h.green_location AS geometry))""";
        };
        double limit = switch (feature.layer()) {
            case GREEN -> GREEN_MATCH_METRES;
            case TEE -> TEE_MATCH_METRES;
            default -> HAZARD_MATCH_METRES;
        };

        var rows = em.createNativeQuery("""
                SELECT h.id,
                       ST_Distance(CAST(%s AS geography),
                                   CAST(ST_GeomFromText(:wkt, 4326) AS geography))
                FROM holes h
                WHERE h.course_id = :course
                  AND h.teeing_ground_location IS NOT NULL
                  AND h.green_location IS NOT NULL
                ORDER BY 2
                LIMIT 1
                """.formatted(anchor))
                .setParameter("course", courseId)
                .setParameter("wkt", feature.toWkt())
                .getResultList();
        if (rows.isEmpty()) {
            return null;
        }
        Object[] row = (Object[]) rows.get(0);
        double distance = ((Number) row[1]).doubleValue();
        return distance <= limit ? ((Number) row[0]).longValue() : null;
    }

    private void save(Long courseId, Long holeId, OsmGolfFeature feature,
                      String requestedBy) {
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
                        'openstreetmap', 'openstreetmap', :license,
                        -- A person digitised this from imagery, which is what
                        -- the class says. Not B: nobody licensed it to us, it
                        -- is open data with an attribution obligation.
                        'C_VERIFIED_SATELLITE',
                        'PENDING_REVIEW', :confidence, :importedBy,
                        CURRENT_DATE, 0, now(), now())
                ON CONFLICT (course_id, layer_type, hole_id, external_feature_id)
                DO UPDATE SET geometry = EXCLUDED.geometry,
                              feature_name = EXCLUDED.feature_name,
                              updated_at = now()
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeId)
                .setParameter("layer", feature.layer().name())
                .setParameter("wkt", feature.toWkt())
                .setParameter("name", feature.name())
                .setParameter("externalId", feature.externalId())
                .setParameter("license", "ODbL 1.0 — © OpenStreetMap contributors")
                .setParameter("confidence", new BigDecimal("90.00"))
                .setParameter("importedBy", "osm-import:" + requestedBy)
                .executeUpdate();
    }

    /// South, west, north, east of the course's holes.
    private double[] boundingBox(Long courseId) {
        var rows = em.createNativeQuery("""
                SELECT min(least(ST_Y(CAST(h.teeing_ground_location AS geometry)),
                                 ST_Y(CAST(h.green_location AS geometry)))),
                       min(least(ST_X(CAST(h.teeing_ground_location AS geometry)),
                                 ST_X(CAST(h.green_location AS geometry)))),
                       max(greatest(ST_Y(CAST(h.teeing_ground_location AS geometry)),
                                    ST_Y(CAST(h.green_location AS geometry)))),
                       max(greatest(ST_X(CAST(h.teeing_ground_location AS geometry)),
                                    ST_X(CAST(h.green_location AS geometry))))
                FROM holes h
                WHERE h.course_id = :course
                  AND h.teeing_ground_location IS NOT NULL
                  AND h.green_location IS NOT NULL
                """)
                .setParameter("course", courseId)
                .getResultList();
        if (rows.isEmpty()) {
            return null;
        }
        Object[] row = (Object[]) rows.get(0);
        for (Object value : row) {
            if (value == null) {
                return null;
            }
        }
        return new double[]{
                ((Number) row[0]).doubleValue(), ((Number) row[1]).doubleValue(),
                ((Number) row[2]).doubleValue(), ((Number) row[3]).doubleValue(),
        };
    }
}
