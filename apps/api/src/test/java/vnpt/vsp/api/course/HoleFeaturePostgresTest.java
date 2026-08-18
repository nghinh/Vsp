package vnpt.vsp.api.course;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Which of a hole's proposals a golfer is actually shown.
 *
 * <p>Drafts arrive from two places that are not equal. A mapper who drew a
 * green by hand off the same imagery got it right to within a few metres; a
 * vision model asked to trace the same green returned three times its area.
 * Both sit in the same table, and the rules that decide between them live in
 * one SQL statement — which is exactly the kind of thing that quietly stops
 * working.
 */
@DataJpaTest(properties = {
        "spring.datasource.url=jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DB:vsp}",
        "spring.datasource.username=${POSTGRES_USER:vsp}",
        "spring.datasource.password=${POSTGRES_PASSWORD:vsp_dev_password}",
        "spring.datasource.driver-class-name=org.postgresql.Driver",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.flyway.enabled=false",
        "spring.sql.init.mode=never"
})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@EnabledIf("postgisAvailable")
class HoleFeaturePostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    /// Kept in step with {@code vsp.vision.minimum-confidence} by hand, and
    /// asserted against below, because a floor that only exists in a YAML
    /// default is a floor nothing tests.
    private static final int DEFAULT_FLOOR = 40;

    private long courseId;
    private long holeId;
    private HoleFeatureController controller;

    @BeforeEach
    void setUp() {
        // The mapping and vision services are only reached by the request
        // endpoint, which this test does not exercise.
        //
        // The floor is the shipped default, so what these tests say about it
        // is what a golfer gets. It was 65 here and in application.yml, and at
        // 65 this endpoint withheld 29% of every bunker GolfSeg had ever
        // traced — see the query's own comment for why that number says
        // nothing about the bunkers.
        //
        // Which shapes may be shown now lives in TracedHoleGeometry, shared
        // with the package builder so an offline course holds what the online
        // map draws. These tests therefore exercise the same rules through
        // the endpoint that serves them.
        controller = new HoleFeatureController(
                em, null, null,
                new vnpt.vsp.module.geometry.TracedHoleGeometry(em, DEFAULT_FLOOR),
                30);

        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Feature probe facility', 'feature-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Feature probe course', 9, 36, 'feature-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();
        holeId = ((Number) em.createNativeQuery("""
                INSERT INTO holes (course_id, hole_number, par, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:course, 1, 4, 'feature-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("course", courseId).getSingleResult()).longValue();
        em.flush();
    }

    /// A small square somewhere over Hanoi. Where it is does not matter here;
    /// only which rows come back does.
    private static final String SQUARE = """
            POLYGON((105.8910 21.0350, 105.8912 21.0350,
                     105.8912 21.0352, 105.8910 21.0352, 105.8910 21.0350))""";

    private void draft(String layer, String source, String status, double confidence) {
        em.createNativeQuery("""
                INSERT INTO draft_geometry_features
                    (feature_uuid, course_id, hole_id, layer_type, geometry,
                     is_valid, external_feature_id, publisher, source,
                     accuracy_class, verification_status, confidence,
                     effective_date, version, created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :hole, :layer, :wkt,
                        true, :externalId, :source, :source,
                        'D_UNVERIFIED_COMMUNITY', :status, :confidence,
                        CURRENT_DATE, 0, now(), now())
                """)
                .setParameter("course", courseId)
                .setParameter("hole", holeId)
                .setParameter("layer", layer)
                .setParameter("wkt", SQUARE)
                .setParameter("externalId", layer + ":" + source + ":" + status)
                .setParameter("source", source)
                .setParameter("status", status)
                .setParameter("confidence", java.math.BigDecimal.valueOf(confidence))
                .executeUpdate();
        em.flush();
    }

    @SuppressWarnings("unchecked")
    private List<String> servedLayers() {
        var collection = controller.features(courseId, 1);
        var features = (List<Map<String, Object>>) collection.get("features");
        return features.stream()
                .map(feature -> (Map<String, Object>) feature.get("properties"))
                .map(properties -> properties.get("layerType") + ":"
                        + properties.get("source"))
                .toList();
    }

    /// The rule the whole import exists for. Two greens on one hole is worse
    /// than either alone, and it is never the model's that is right.
    @Test
    @DisplayName("where a person drew the layer, the model's version is not served")
    void aPersonsShapeReplacesTheModels() {
        draft("GREEN", "openstreetmap", "PENDING_REVIEW", 90);
        draft("GREEN", "ai-satellite", "PENDING_REVIEW", 88);

        assertThat(servedLayers()).containsExactly("green:openstreetmap");
    }

    /// Only for that layer. A hole where a mapper drew the green but nobody
    /// drew the bunkers still wants the model's bunkers.
    @Test
    @DisplayName("the model still supplies the layers nobody drew")
    void theModelFillsTheGaps() {
        draft("GREEN", "openstreetmap", "PENDING_REVIEW", 90);
        draft("BUNKER", "ai-satellite", "PENDING_REVIEW", 80);

        assertThat(servedLayers())
                .containsExactlyInAnyOrder("bunker:ai-satellite", "green:openstreetmap");
    }

    /// A hole the mapper did not reach shows the model's shape.
    ///
    /// This used to assert the opposite, and the opposite was wrong on a real
    /// course. One green drawn on hole 1 silenced the model on hole 2, and
    /// hole 2 came back with nothing to draw. The mapper's work is not a claim
    /// about the holes they never touched.
    ///
    /// What has not changed: on the hole they did draw, only their shape goes
    /// out. See "on this hole, a mapper's shape always replaces the model's".
    @Test
    @DisplayName("a hole the mapper did not reach shows the model's shape")
    void theModelCoversTheHolesNobodyDrew() {
        long otherHole = ((Number) em.createNativeQuery("""
                INSERT INTO holes (course_id, hole_number, par, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:course, 2, 4, 'feature-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("course", courseId).getSingleResult()).longValue();
        em.flush();

        // Hole 1: a mapper drew the green. Hole 2: only the model did.
        draft("GREEN", "openstreetmap", "PENDING_REVIEW", 90);
        em.createNativeQuery("""
                INSERT INTO draft_geometry_features
                    (feature_uuid, course_id, hole_id, layer_type, geometry,
                     is_valid, external_feature_id, publisher, source,
                     accuracy_class, verification_status, confidence,
                     effective_date, version, created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :hole, 'GREEN', :wkt,
                        true, 'ai:green:2', 'ai-satellite', 'ai-satellite',
                        'D_UNVERIFIED_COMMUNITY', 'PENDING_REVIEW', 88,
                        CURRENT_DATE, 0, now(), now())
                """)
                .setParameter("course", courseId)
                .setParameter("hole", otherHole)
                .setParameter("wkt", SQUARE)
                .executeUpdate();
        em.flush();

        var holeTwo = controller.features(courseId, 2);
        assertThat((List<?>) holeTwo.get("features")).hasSize(1);
    }

    /// The largest thing on screen and the one carrying no number a golfer
    /// plays to. It stays in the queue for a reviewer; it does not go out.
    @Test
    @DisplayName("a model-drawn fairway is filed but not served")
    void doesNotServeAModelsFairway() {
        draft("FAIRWAY", "ai-satellite", "PENDING_REVIEW", 90);
        draft("ROUGH", "ai-satellite", "PENDING_REVIEW", 90);

        assertThat(servedLayers()).isEmpty();
    }

    /// A fairway somebody actually drew is a different thing entirely.
    @Test
    @DisplayName("a fairway a person drew is served")
    void servesAMappedFairway() {
        draft("FAIRWAY", "openstreetmap", "PENDING_REVIEW", 90);

        assertThat(servedLayers()).containsExactly("fairway:openstreetmap");
    }

    @Test
    @DisplayName("a shape traced off a blank tile is not served")
    void refusesGarbage() {
        // The failure the floor is actually for. Esri answers a request
        // outside its high-resolution coverage with a flat placeholder rather
        // than a 404, and the model, shown a blank sheet, does not say "I
        // cannot see" — over Bắc Giang it returned 116 shapes at 22.
        draft("BUNKER", "ai-satellite", "PENDING_REVIEW", 22);

        assertThat(servedLayers()).isEmpty();
    }

    @Test
    @DisplayName("a bunker the model is merely unsure of is served")
    void servesAnUncertainBunker() {
        // 62.04 is not invented: it is what GolfSeg returned for all eight
        // bunkers on the 1st of Long Biên's Đường B, which is round hole 10
        // of an A+B pairing, on a hole a golfer was standing on when they
        // reported that the map had no bunkers.
        //
        // The number is the mean softmax over the class's own mask, so it
        // measures how crisp the edges of a thirty-pixel shape are and not
        // whether there is sand there. Nothing in the database ranks by it:
        // bunkers below 65 hit an OSM-mapped bunker 10% of the time and
        // bunkers above it 9%. Withholding this shape buys no accuracy and
        // costs the golfer the hazard.
        draft("BUNKER", "golfseg", "PENDING_REVIEW", 62.04);

        assertThat(servedLayers()).containsExactly("bunker:golfseg");
    }

    @Test
    @DisplayName("a pond the model is unsure of is served too")
    void servesAnUncertainPond() {
        // Water scores lowest of every class — 48.44 on that same hole — and
        // is the class the model is measurably best at: 0.766 IoU on the
        // held-out Vietnamese courses against 0.450 for bunkers. The ranking
        // by confidence and the ranking by accuracy point opposite ways,
        // which is the clearest statement available that this number is not
        // a quality score.
        draft("WATER_HAZARD", "golfseg", "PENDING_REVIEW", 48.44);

        assertThat(servedLayers()).containsExactly("water:golfseg");
    }

    @Test
    @DisplayName("a shape somebody rejected is not served")
    void refusesRejected() {
        draft("BUNKER", "ai-satellite", "REJECTED", 95);

        assertThat(servedLayers()).isEmpty();
    }

    /// A rejected human-drawn green must not suppress the model's, or a
    /// reviewer throwing out a bad import would leave the hole blank.
    @Test
    @DisplayName("a rejected import does not suppress the model's version")
    void aRejectedImportDoesNotSuppress() {
        draft("GREEN", "openstreetmap", "REJECTED", 90);
        draft("GREEN", "ai-satellite", "PENDING_REVIEW", 88);

        assertThat(servedLayers()).containsExactly("green:ai-satellite");
    }

    /// Three scattered polygons are not coverage. Đường B has three bunkers in
    /// OpenStreetMap and about twenty on the ground; letting those three
    /// silence every bunker the model found left holes with visible sand and
    /// nothing drawn on them.
    @Test
    @DisplayName("a thinly mapped layer does not silence the model")
    void thinCoverageDoesNotSuppress() {
        // Nine holes; a mapper drew one bunker.
        for (int number = 2; number <= 9; number++) {
            em.createNativeQuery("""
                    INSERT INTO holes (course_id, hole_number, par, publisher, effective_date, confidence, version, created_at, updated_at)
                    VALUES (:course, :n, 4, 'feature-test', CURRENT_DATE, 0, 0, now(), now())
                    """)
                    .setParameter("course", courseId)
                    .setParameter("n", number)
                    .executeUpdate();
        }
        em.flush();

        // The mapper's bunker is on hole 2; hole 1 has only the model's.
        long second = ((Number) em.createNativeQuery("""
                SELECT id FROM holes WHERE course_id = :course AND hole_number = 2
                """).setParameter("course", courseId).getSingleResult()).longValue();
        em.createNativeQuery("""
                INSERT INTO draft_geometry_features
                    (feature_uuid, course_id, hole_id, layer_type, geometry,
                     is_valid, external_feature_id, publisher, source,
                     accuracy_class, verification_status, confidence,
                     effective_date, version, created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :hole, 'BUNKER', :wkt,
                        true, 'osm:b2', 'openstreetmap', 'openstreetmap',
                        'C_VERIFIED_SATELLITE', 'PENDING_REVIEW', 90,
                        CURRENT_DATE, 0, now(), now())
                """)
                .setParameter("course", courseId)
                .setParameter("hole", second)
                .setParameter("wkt", SQUARE)
                .executeUpdate();
        em.flush();
        draft("BUNKER", "golfseg", "PENDING_REVIEW", 80);

        // Hole 1 shows the model's: one mapped hole out of nine is a gap, not
        // a survey, and nobody drew a bunker here.
        assertThat(servedLayers()).containsExactly("bunker:golfseg");
    }

    /// And on the hole itself the mapper always wins, however thin the rest
    /// of the course is. Two greens on one hole is nonsense either way.
    @Test
    @DisplayName("on this hole, a mapper's shape always replaces the model's")
    void onThisHoleTheMapperAlwaysWins() {
        for (int number = 2; number <= 9; number++) {
            em.createNativeQuery("""
                    INSERT INTO holes (course_id, hole_number, par, publisher, effective_date, confidence, version, created_at, updated_at)
                    VALUES (:course, :n, 4, 'feature-test', CURRENT_DATE, 0, 0, now(), now())
                    """)
                    .setParameter("course", courseId).setParameter("n", number)
                    .executeUpdate();
        }
        em.flush();

        draft("GREEN", "openstreetmap", "PENDING_REVIEW", 90);
        draft("GREEN", "golfseg", "PENDING_REVIEW", 88);

        assertThat(servedLayers()).containsExactly("green:openstreetmap");
    }

    /// And the other side of the same line, which used to be the opposite
    /// answer: a layer somebody drew almost everywhere still lets the model
    /// fill the hole they missed.
    ///
    /// There was a second rule here that asked whether a person had drawn the
    /// layer across most of the course and, if so, silenced the model on every
    /// hole of it — including the holes nobody had drawn. On Long Biên's Đường
    /// A a mapper drew one pond on each of five holes out of nine, which
    /// cleared that bar, and all 33 ponds GolfSeg found were hidden: holes 1,
    /// 5, 7 and 8 had water on the ground, sixteen traced ponds between them,
    /// and an empty map. The satellite photograph of hole 2 has a lake across
    /// the middle of it.
    ///
    /// The model fills in behind the mapper now. It still never argues with
    /// them on a hole they drew — see the test above.
    @Test
    @DisplayName("a hole the mapper missed still gets the model's shape")
    void theModelFillsTheGapTheMapperLeft() {
        // Nine holes. The mapper drew a green on eight of them — every hole
        // but this one — which is as thorough as a mapper gets and used to be
        // exactly the condition that emptied this hole.
        for (int number = 2; number <= 9; number++) {
            long id = ((Number) em.createNativeQuery("""
                    INSERT INTO holes (course_id, hole_number, par, publisher, effective_date, confidence, version, created_at, updated_at)
                    VALUES (:course, :n, 4, 'feature-test', CURRENT_DATE, 0, 0, now(), now())
                    RETURNING id
                    """)
                    .setParameter("course", courseId)
                    .setParameter("n", number)
                    .getSingleResult()).longValue();
            em.createNativeQuery("""
                    INSERT INTO draft_geometry_features
                        (feature_uuid, course_id, hole_id, layer_type, geometry,
                         is_valid, external_feature_id, publisher, source,
                         accuracy_class, verification_status, confidence,
                         effective_date, version, created_at, updated_at)
                    VALUES (gen_random_uuid(), :course, :hole, 'GREEN', :wkt,
                            true, :ext, 'openstreetmap', 'openstreetmap',
                            'C_VERIFIED_SATELLITE', 'PENDING_REVIEW', 90,
                            CURRENT_DATE, 0, now(), now())
                    """)
                    .setParameter("course", courseId)
                    .setParameter("hole", id)
                    .setParameter("ext", "osm:green-" + number)
                    .setParameter("wkt", SQUARE)
                    .executeUpdate();
        }
        em.flush();

        // Hole 1 — this hole — has only the model's.
        draft("GREEN", "golfseg", "PENDING_REVIEW", 88);

        assertThat(servedLayers()).containsExactly("green:golfseg");
    }
}
