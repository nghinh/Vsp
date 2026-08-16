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

    private long courseId;
    private long holeId;
    private HoleFeatureController controller;

    @BeforeEach
    void setUp() {
        // The mapping service is only reached by the request endpoint, which
        // this test does not exercise.
        controller = new HoleFeatureController(em, null, 65, 30);

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

    /// The rule is the course's, not the hole's. A course with real greens on
    /// two holes and the model's on the other seven is one where nothing on
    /// screen can be trusted more than the worst of it — and ODbL's
    /// horizontal-layers guideline draws the same line, because mixing
    /// sources within one feature type in one regional cut makes the whole
    /// layer a Derivative Database.
    @Test
    @DisplayName("a mapped green on one hole silences the model's on the others")
    void theRuleCoversTheWholeCourse() {
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
        assertThat((List<?>) holeTwo.get("features")).isEmpty();
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
    @DisplayName("a shape the model doubts is not served")
    void refusesLowConfidence() {
        draft("BUNKER", "ai-satellite", "PENDING_REVIEW", 40);

        assertThat(servedLayers()).isEmpty();
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
}
