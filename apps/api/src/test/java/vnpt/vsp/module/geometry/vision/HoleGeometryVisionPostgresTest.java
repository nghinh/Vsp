package vnpt.vsp.module.geometry.vision;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.persistence.PostgresTestSupport;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Filing what the satellite reader saw.
 *
 * <p>The model and the imagery are both stubbed — what is checked here is
 * that a proposal reaches the review queue as a valid polygon in the right
 * place, and that a deployment without imagery or without a model refuses
 * rather than writing something empty.
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
class HoleGeometryVisionPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private long courseId;

    /// Imagery that needs no network: a plain PNG over a known box.
    private static SatelliteImageService imagery(boolean configured) {
        return new SatelliteImageService(
                configured ? "https://tiles.example/{z}/{x}/{y}.png" : "",
                configured ? "© Test imagery" : "",
                configured ? 19 : 0) {
            @Override
            public StitchedImage fetch(double south, double west,
                                       double north, double east) {
                if (!isConfigured()) {
                    return null;
                }
                return new StitchedImage(new byte[]{1, 2, 3},
                        new ImageBounds(north, south, east, west, 18),
                        "© Test imagery");
            }
        };
    }

    /// A model that answers with whatever the test hands it.
    private static VisionProvider model(String answer) {
        return new VisionProvider() {
            @Override
            public boolean isConfigured() {
                return answer != null;
            }

            @Override
            public String modelVersion() {
                return "test-vision-1";
            }

            @Override
            public String analyzeImage(byte[] image, String mediaType,
                                       String prompt, int maxTokens) {
                return answer;
            }
        };
    }

    private HoleGeometryVisionService service(String answer, boolean withImagery) {
        return new HoleGeometryVisionService(
                em, imagery(withImagery), model(answer), new ObjectMapper());
    }

    @BeforeEach
    void setUp() {
        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Vision probe facility', 'vision-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Vision probe course', 9, 36, 'vision-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();
        em.createNativeQuery("""
                INSERT INTO holes (course_id, hole_number, par,
                                   teeing_ground_location, green_location,
                                   publisher, effective_date, confidence, version,
                                   created_at, updated_at)
                VALUES (:course, 1, 4,
                        ST_SetSRID(ST_MakePoint(105.8963, 21.0368), 4326),
                        ST_SetSRID(ST_MakePoint(105.8911, 21.0350), 4326),
                        'vision-test', CURRENT_DATE, 0, 0, now(), now())
                """).setParameter("course", courseId).executeUpdate();
        em.flush();
    }

    @Test
    @DisplayName("a traced green reaches the review queue as a real polygon")
    void filesADraft() {
        var service = service("""
                {"features": [
                  {"layer": "green", "name": "Green 1", "confidence": 0.82,
                   "polygon": [[0.48,0.48],[0.52,0.48],[0.52,0.52],[0.48,0.52]]},
                  {"layer": "bunker", "confidence": 0.6,
                   "polygon": [[0.30,0.40],[0.34,0.40],[0.34,0.44],[0.30,0.44]]}
                ]}
                """, true);

        var counts = service.detect(courseId, 1, "tester");

        assertThat(counts).containsEntry("GREEN", 1).containsEntry("BUNKER", 1);

        Object[] row = (Object[]) em.createNativeQuery("""
                SELECT layer_type, source, verification_status, confidence,
                       model_version,
                       ST_IsValid(ST_GeomFromText(geometry, 4326)),
                       ST_Y(ST_Centroid(ST_GeomFromText(geometry, 4326))),
                       ST_X(ST_Centroid(ST_GeomFromText(geometry, 4326)))
                FROM draft_geometry_features
                WHERE course_id = :course AND layer_type = 'GREEN'
                """).setParameter("course", courseId).getSingleResult();

        assertThat(row[0]).isEqualTo("GREEN");
        assertThat(row[1]).isEqualTo("ai-satellite");
        // Never published, always reviewed.
        assertThat(row[2]).isEqualTo("PENDING_REVIEW");
        assertThat(((Number) row[3]).doubleValue()).isEqualTo(82.0);
        // Which model drew it, so a later one's work can be told apart.
        assertThat(row[4]).isEqualTo("test-vision-1");
        assertThat(row[5]).isEqualTo(true);
        // Traced at the middle of the frame, so it lands between tee and green.
        assertThat(((Number) row[6]).doubleValue()).isBetween(21.0340, 21.0380);
        assertThat(((Number) row[7]).doubleValue()).isBetween(105.8900, 105.8975);
    }

    @Test
    @DisplayName("nothing seen files nothing")
    void filesNothingWhenTheModelSeesNothing() {
        var counts = service("{\"features\": []}", true).detect(courseId, 1, "tester");

        assertThat(counts).isEmpty();
        assertThat(draftCount()).isZero();
    }

    /// The polygons differ slightly on every run, so keying on their shape
    /// left one hole with three greens and twelve bunkers — a review queue
    /// full of the same hole traced three times.
    @Test
    @DisplayName("a re-trace replaces this hole's proposals rather than adding")
    void aRetraceReplaces() {
        service("""
                {"features": [{"layer": "green",
                  "polygon": [[0.48,0.48],[0.52,0.48],[0.52,0.52],[0.48,0.52]]}]}
                """, true).detect(courseId, 1, "tester");
        // A slightly different trace of the same green.
        service("""
                {"features": [{"layer": "green",
                  "polygon": [[0.47,0.47],[0.53,0.48],[0.52,0.53],[0.48,0.52]]}]}
                """, true).detect(courseId, 1, "tester");

        assertThat(draftCount()).isEqualTo(1);
    }

    /// A proposal somebody has already looked at is theirs, and a new model
    /// run does not get to delete their decision.
    @Test
    @DisplayName("a reviewed proposal survives a re-trace")
    void keepsWhatAHumanTouched() {
        service("""
                {"features": [{"layer": "green",
                  "polygon": [[0.48,0.48],[0.52,0.48],[0.52,0.52],[0.48,0.52]]}]}
                """, true).detect(courseId, 1, "tester");
        em.createNativeQuery("""
                UPDATE draft_geometry_features SET verification_status = 'VERIFIED'
                WHERE course_id = :course
                """).setParameter("course", courseId).executeUpdate();
        em.flush();

        service("""
                {"features": [{"layer": "green",
                  "polygon": [[0.40,0.40],[0.44,0.40],[0.44,0.44],[0.40,0.44]]}]}
                """, true).detect(courseId, 1, "tester");

        // The verified one, plus the new proposal beside it.
        assertThat(draftCount()).isEqualTo(2);
    }

    @Test
    @DisplayName("a deployment with no licensed imagery refuses")
    void refusesWithoutImagery() {
        assertThatThrownBy(() -> service("{\"features\": []}", false)
                .detect(courseId, 1, "tester"))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("a deployment with no vision model refuses")
    void refusesWithoutAModel() {
        assertThatThrownBy(() -> service(null, true).detect(courseId, 1, "tester"))
                .isInstanceOf(VspApiException.class);
    }

    /// A hole with no coordinates cannot be framed, which is most holes this
    /// project has only a card for.
    @Test
    @DisplayName("a hole with no coordinates is refused, not guessed at")
    void refusesAHoleWithNoPoints() {
        em.createNativeQuery("""
                INSERT INTO holes (course_id, hole_number, par, publisher,
                                   effective_date, confidence, version, created_at, updated_at)
                VALUES (:course, 2, 4, 'vision-test', CURRENT_DATE, 0, 0, now(), now())
                """).setParameter("course", courseId).executeUpdate();
        em.flush();

        assertThatThrownBy(() -> service("{\"features\": []}", true)
                .detect(courseId, 2, "tester"))
                .isInstanceOf(VspApiException.class);
    }

    private int draftCount() {
        return ((Number) em.createNativeQuery(
                "SELECT count(*) FROM draft_geometry_features WHERE course_id = :course")
                .setParameter("course", courseId).getSingleResult()).intValue();
    }
}
