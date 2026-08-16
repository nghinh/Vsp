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

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Tracing a whole course as a job.
 *
 * <p>The two rules with money behind them: one course is not analysed twice
 * at once, and a hole the model cannot read does not throw away the holes it
 * already traced.
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
class CourseMappingPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private long courseId;

    private static VisionProvider model(String answer) {
        return new VisionProvider() {
            @Override public boolean isConfigured() { return true; }
            @Override public String modelVersion() { return "test-vision-1"; }
            @Override public String analyzeImage(byte[] image, String mediaType,
                                                 String prompt, int maxTokens) {
                return answer;
            }
        };
    }

    private static SatelliteImageService imagery() {
        return new SatelliteImageService("https://tiles.example/{z}/{x}/{y}.png",
                "© Test imagery", 19) {
            @Override
            public StitchedImage fetch(double south, double west,
                                       double north, double east) {
                return new StitchedImage(new byte[]{1},
                        new ImageBounds(north, south, east, west, 18), "© Test");
            }
        };
    }

    private CourseMappingService service(String answer) {
        var visionService = new HoleGeometryVisionService(
                em, imagery(), model(answer), new ObjectMapper());
        return new CourseMappingService(em, visionService, model(answer),
                new CourseMappingJobStore(em));
    }

    @BeforeEach
    void setUp() {
        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Mapping probe facility', 'map-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Mapping probe course', 9, 36, 'map-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();
        for (int hole = 1; hole <= 3; hole++) {
            em.createNativeQuery("""
                    INSERT INTO holes (course_id, hole_number, par,
                                       teeing_ground_location, green_location,
                                       publisher, effective_date, confidence, version,
                                       created_at, updated_at)
                    VALUES (:course, :hole, 4,
                            ST_SetSRID(ST_MakePoint(105.8963, 21.0368), 4326),
                            ST_SetSRID(ST_MakePoint(105.8911, 21.0350), 4326),
                            'map-test', CURRENT_DATE, 0, 0, now(), now())
                    """)
                    .setParameter("course", courseId)
                    .setParameter("hole", hole)
                    .executeUpdate();
        }
        em.flush();
    }

    private static final String ONE_GREEN = """
            {"features": [{"layer": "green", "confidence": 0.9,
              "polygon": [[0.45,0.45],[0.55,0.45],[0.55,0.55],[0.45,0.55]]}]}
            """;

    @Test
    @DisplayName("a run covers every hole that has coordinates")
    void tracesTheWholeCourse() {
        var service = service(ONE_GREEN);

        UUID jobId = service.request(courseId, "tester");
        service.run(jobId);

        var status = service.status(jobId);
        assertThat(status.get("status")).isEqualTo("READY");
        assertThat(status.get("holesTotal")).isEqualTo(3);
        assertThat(status.get("holesAnalysed")).isEqualTo(3);
        assertThat(status.get("featuresDetected")).isEqualTo(3);
        assertThat(status.get("modelVersion")).isEqualTo("test-vision-1");
    }

    /// Starting the same course twice would trace the same holes and bill
    /// for both.
    @Test
    @DisplayName("a course already being traced returns the running job")
    void refusesToRunTwice() {
        var service = service(ONE_GREEN);

        UUID first = service.request(courseId, "tester");
        UUID second = service.request(courseId, "someone else");

        assertThat(second).isEqualTo(first);
    }

    @Test
    @DisplayName("a course with no coordinates has nothing to trace")
    void refusesACourseWithNoPoints() {
        long empty = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                SELECT facility_id, 'Empty probe', 9, 36, 'map-test', CURRENT_DATE, 0, 0, now(), now()
                FROM courses WHERE id = :course
                RETURNING id
                """).setParameter("course", courseId).getSingleResult()).longValue();
        em.flush();

        assertThatThrownBy(() -> service(ONE_GREEN).request(empty, "tester"))
                .isInstanceOf(VspApiException.class);
    }

    /// An hour of tracing must not be thrown away because one image came
    /// back unreadable.
    @Test
    @DisplayName("a hole the model cannot read costs only that hole")
    void keepsWhatItTracedWhenOneHoleFails() {
        // An answer that is not JSON: every hole "succeeds" with no features.
        var service = service("the sky is cloudy");

        UUID jobId = service.request(courseId, "tester");
        service.run(jobId);

        var status = service.status(jobId);
        assertThat(status.get("status")).isEqualTo("READY");
        assertThat(status.get("holesAnalysed")).isEqualTo(3);
        assertThat(status.get("featuresDetected")).isEqualTo(0);
    }

    @Test
    @DisplayName("the worker claims one job at a time")
    void claimsOneAtATime() {
        var service = service(ONE_GREEN);
        UUID queued = service.request(courseId, "tester");

        UUID claimed = service.claimNext();
        UUID nothingLeft = service.claimNext();

        assertThat(claimed).isEqualTo(queued);
        assertThat(nothingLeft).isNull();
    }

    @Test
    @DisplayName("an unknown job id is a refusal, not an empty answer")
    void refusesAnUnknownJob() {
        assertThatThrownBy(() -> service(ONE_GREEN).status(UUID.randomUUID()))
                .isInstanceOf(VspApiException.class);
    }
}
