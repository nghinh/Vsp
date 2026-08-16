package vnpt.vsp.module.geometry.osm;

import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Drawing the edge of a golf course from the path golfers drive round it.
 *
 * <p>§29 asks for a course boundary and warns against a convex hull, which on
 * a course shaped like a horseshoe swallows the housing estate in the middle
 * of it. This does something simpler and truer to the ground: a cart path is
 * where a buggy can go, so the ground within a wedge of one is the course.
 * Buffer the path network, union it with every feature a mapper drew, and the
 * shape that falls out is the course — holes and all, in the right places,
 * with the neighbours outside.
 *
 * <p>What it is for: a segmentation model shown the first hole at Long Biên
 * labelled the corrugated roofs next door as water. It is not wrong about the
 * pixels — a blue-grey metal roof and a pond look alike from 300 m up — it is
 * answering a question the picture cannot answer. The boundary answers it.
 */
@Service
public class CourseBoundaryService {

    private static final Logger log =
            LoggerFactory.getLogger(CourseBoundaryService.class);

    /// How far either side of a cart path still counts as the course.
    ///
    /// A path runs down the side of a hole rather than through the middle, so
    /// this has to cover a fairway's width from one edge — 60 m is generous
    /// for a Vietnamese course and still stops well short of the houses,
    /// which is the whole point.
    private static final int CART_PATH_BUFFER_M = 60;

    /// Around a green, a bunker or a pond. Smaller, because these are the
    /// course rather than a line beside it.
    private static final int FEATURE_BUFFER_M = 35;

    /// How much of a course's own tees and greens an outline must contain
    /// before it is allowed to decide what is on the course.
    ///
    /// The measured split is not close. Six courses came out at 94-100%; the
    /// one built from a single path segment came out at 6%. Anything in
    /// between is a course whose path network is mapped in pieces, and the
    /// honest answer there is to admit everything and say so rather than to
    /// filter by a guess.
    private static final double MINIMUM_HOLE_COVERAGE = 0.8;

    private final EntityManager em;

    public CourseBoundaryService(EntityManager em) {
        this.em = em;
    }

    /**
     * Builds and stores the boundary for one course.
     *
     * @return what it was built from, and how big it came out
     */
    // No `::` casts — Hibernate reads them as named parameters.
    @Transactional
    public Map<String, Object> rebuild(Long courseId) {
        int cartPaths = count(courseId, "CART_PATH");
        int features = countAreas(courseId);
        if (cartPaths == 0 && features == 0) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "course",
                    Map.of("course", "this course has no geometry to draw a boundary from"));
        }

        // Everything buffered in metres, which means going through geography
        // and back. ST_Buffer on a geography returns geography; the union has
        // to happen in geometry, so each side is cast once and the result cast
        // back for the area.
        //
        // The closing buffer pair (+25 then −25) fills the gaps between
        // separate path segments: OSM maps a cart path as a dozen ways, and
        // without this the boundary comes out as a dozen sausages.
        // Cart paths alone where there are any. Unioning every feature as
        // well was the first attempt and it came out at 107 hectares for a
        // nine-hole course — three times what one occupies — with the
        // greenhouses and the housing estate inside it, because a course's
        // ponds and greens are scattered right across the facility and their
        // buffers bridge everything between them.
        //
        // The cart path is the honest outline: it is where a buggy can go, so
        // the ground within a wedge of one is the course and the ground
        // beyond it is not. Features are the fallback for a course nobody has
        // mapped paths for, and that boundary is loose by construction.
        String boundary = (String) em.createNativeQuery("""
                WITH parts AS (
                    SELECT ST_Buffer(CAST(ST_GeomFromText(d.geometry, 4326) AS geography),
                                     CASE WHEN d.layer_type = 'CART_PATH'
                                          THEN :pathBuffer ELSE :featureBuffer END)
                           AS shape
                    FROM draft_geometry_features d
                    WHERE d.course_id = :course AND d.is_valid
                      AND d.verification_status <> 'REJECTED'
                      AND (d.layer_type = 'CART_PATH' OR NOT :hasPaths)
                ),
                merged AS (
                    SELECT ST_Union(CAST(shape AS geometry)) AS shape FROM parts
                ),
                closed AS (
                    SELECT ST_Buffer(
                             ST_Buffer(CAST(shape AS geography), 25),
                             -25) AS shape
                    FROM merged
                )
                -- No convex hull. §29 warns against it and this is why: a
                -- course bent round a housing estate has that estate inside
                -- its hull, which would re-admit the exact roofs this exists
                -- to exclude. The buffered union is already the right shape —
                -- concave where the course is concave — so it is simplified
                -- and kept.
                SELECT ST_AsText(
                         ST_SimplifyPreserveTopology(CAST(shape AS geometry), 0.00002))
                FROM closed
                """)
                .setParameter("course", courseId)
                .setParameter("hasPaths", cartPaths > 0)
                .setParameter("pathBuffer", CART_PATH_BUFFER_M)
                .setParameter("featureBuffer", FEATURE_BUFFER_M)
                .getSingleResult();

        if (boundary == null || boundary.isBlank()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "course",
                    Map.of("course", "the boundary came out empty"));
        }

        // A boundary has to contain the holes it bounds.
        //
        // Six of the seven courses with cart paths came out containing every
        // tee and every green on file. The seventh — Chí Linh's Đường C, built
        // from a single mapped path segment — contained one point of eighteen,
        // and 127 of its own 135 traced shapes fell outside it. That is not a
        // course outline, it is a 120 m corridor down one side of the course,
        // and stored it would have been worse than storing nothing: contains()
        // treats a boundary that exists as authoritative, so the next trace of
        // that đường would have had almost everything on it refused as
        // somebody else's land.
        //
        // The check is the cheapest true one available. Every course being
        // traced has real tee and green coordinates from a source that is not
        // this pipeline, so they are independent of whatever the model drew,
        // and a shape that excludes them is answering about the wrong ground.
        double covered = holeCoverage(courseId, boundary);
        if (covered < MINIMUM_HOLE_COVERAGE) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "course",
                    Map.of("course", String.format(
                            "the outline drawn from %d cart path(s) contains only "
                            + "%.0f%% of this course's own tees and greens; it is not "
                            + "the course's edge. Map more of the path network first "
                            + "— no boundary admits everything, which is the safer "
                            + "wrong answer.", cartPaths, covered * 100)));
        }

        // Named after what it was actually built from. `hasPaths` excludes
        // every non-path feature from the union above, so calling the result
        // "cartpath+features" credited it with data it had deliberately not
        // used — and the feature count printed beside it is the number of
        // shapes that were *left out*.
        String source = cartPaths > 0 ? "cartpath-only" : "features-only";
        em.createNativeQuery("""
                INSERT INTO course_boundary
                    (course_id, geometry, source, cart_path_count, feature_count,
                     area_hectares, created_at, updated_at)
                VALUES (:course, :wkt, :source, :paths, :features,
                        ST_Area(CAST(ST_GeomFromText(:wkt, 4326) AS geography)) / 10000,
                        now(), now())
                ON CONFLICT (course_id) DO UPDATE
                SET geometry = EXCLUDED.geometry,
                    source = EXCLUDED.source,
                    cart_path_count = EXCLUDED.cart_path_count,
                    feature_count = EXCLUDED.feature_count,
                    area_hectares = EXCLUDED.area_hectares,
                    updated_at = now()
                """)
                .setParameter("course", courseId)
                .setParameter("wkt", boundary)
                .setParameter("source", source)
                .setParameter("paths", cartPaths)
                .setParameter("features", features)
                .executeUpdate();

        Object hectares = em.createNativeQuery(
                "SELECT area_hectares FROM course_boundary WHERE course_id = :course")
                .setParameter("course", courseId).getSingleResult();

        int retired = retireShapesOutside(courseId, boundary);

        var result = new LinkedHashMap<String, Object>();
        result.put("courseId", courseId);
        result.put("source", source);
        result.put("cartPaths", cartPaths);
        // What the union was built from is the paths; this is how many area
        // features exist on the course, which the check below covers.
        result.put("features", features);
        result.put("areaHectares", hectares);
        result.put("holeCoverage", Math.round(covered * 100) / 100.0);
        result.put("shapesRetired", retired);
        log.info("Course {} boundary from {} cart path(s): {} ha, covers {}% of "
                 + "its holes, retired {} shape(s) outside it",
                courseId, cartPaths, hectares, Math.round(covered * 100), retired);
        return result;
    }

    /**
     * True when this point is on the course, or when nobody has drawn its edge.
     *
     * <p>An unknown boundary admits everything. Rejecting geometry because a
     * course has not been outlined yet would turn a missing boundary into a
     * missing map, which is a worse answer than a slightly wrong one.
     */
    @Transactional(readOnly = true)
    public boolean contains(Long courseId, double latitude, double longitude) {
        var rows = em.createNativeQuery("""
                SELECT ST_Contains(ST_GeomFromText(b.geometry, 4326),
                                   ST_SetSRID(ST_MakePoint(:lng, :lat), 4326))
                FROM course_boundary b WHERE b.course_id = :course
                """)
                .setParameter("course", courseId)
                .setParameter("lat", latitude)
                .setParameter("lng", longitude)
                .getResultList();
        return rows.isEmpty() || Boolean.TRUE.equals(rows.get(0));
    }

    /**
     * The share of this course's own tee and green points that [boundary]
     * contains.
     *
     * <p>1.0 where the course has no coordinates to check against — there is
     * nothing to fail, and refusing a boundary for lack of evidence would
     * block the courses that most need one.
     */
    private double holeCoverage(Long courseId, String boundary) {
        Object[] row = (Object[]) em.createNativeQuery("""
                SELECT count(*) * 2,
                       count(*) FILTER (WHERE ST_Contains(
                           ST_GeomFromText(:wkt, 4326),
                           CAST(h.green_location AS geometry)))
                     + count(*) FILTER (WHERE ST_Contains(
                           ST_GeomFromText(:wkt, 4326),
                           CAST(h.teeing_ground_location AS geometry)))
                FROM holes h
                WHERE h.course_id = :course
                  AND h.green_location IS NOT NULL
                  AND h.teeing_ground_location IS NOT NULL
                """)
                .setParameter("course", courseId)
                .setParameter("wkt", boundary)
                .getSingleResult();
        long points = ((Number) row[0]).longValue();
        if (points == 0) {
            return 1.0;
        }
        return ((Number) row[1]).doubleValue() / points;
    }

    /**
     * Retires the model's shapes that this boundary puts off the course.
     *
     * <p>Drawing the edge is the moment the database learns which of its own
     * shapes were never on the course. Most of them were filed before any
     * outline existed — the sweep that traced 862 holes ran with a boundary on
     * three courses out of seventy-three — so the check the filing path
     * performs had nothing to check against.
     *
     * <p>Only the model's. A shape a person drew that falls outside an outline
     * this service derived means the outline is wrong, not the shape, and
     * quietly retiring a mapper's work on the strength of a buffered path
     * would be the worst trade in this file.
     *
     * <p>Marked invalid rather than deleted: it is a judgement about where the
     * course ends, made from imperfect data, and the geometry costs nothing to
     * keep for whoever revisits it.
     */
    private int retireShapesOutside(Long courseId, String boundary) {
        return em.createNativeQuery("""
                UPDATE draft_geometry_features d
                SET is_valid = false,
                    validity_message = 'outside the course boundary drawn from '
                                       || 'its cart paths',
                    updated_at = now()
                WHERE d.course_id = :course
                  AND d.is_valid
                  AND d.source IN ('golfseg', 'ai-satellite')
                  AND NOT ST_Contains(
                        ST_GeomFromText(:wkt, 4326),
                        ST_Centroid(ST_SetSRID(ST_GeomFromText(d.geometry), 4326)))
                """)
                .setParameter("course", courseId)
                .setParameter("wkt", boundary)
                .executeUpdate();
    }

    private int count(Long courseId, String layer) {
        return ((Number) em.createNativeQuery("""
                SELECT count(*) FROM draft_geometry_features
                WHERE course_id = :course AND layer_type = :layer AND is_valid
                """)
                .setParameter("course", courseId)
                .setParameter("layer", layer)
                .getSingleResult()).intValue();
    }

    private int countAreas(Long courseId) {
        return ((Number) em.createNativeQuery("""
                SELECT count(*) FROM draft_geometry_features
                WHERE course_id = :course AND is_valid AND layer_type <> 'CART_PATH'
                """)
                .setParameter("course", courseId)
                .getSingleResult()).intValue();
    }
}
