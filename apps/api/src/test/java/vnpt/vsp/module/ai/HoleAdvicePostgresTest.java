package vnpt.vsp.module.ai;

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
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The advice queries, against the database that has to run them.
 *
 * <p>This exists because of a bug that reached production. {@code hole()} filters
 * an optional tee with {@code (:tee IS NULL OR t.name = :tee)}, and Postgres
 * cannot infer the type of a bound null in that position: it answers 42P18,
 * "could not determine data type of parameter". Every request that did not name
 * a tee was a 500 — and not naming a tee is what the app does by default.
 *
 * <p>Nothing caught it. The prompt tests assert what goes into the model and
 * never touch a database, and the unit tests mock the repository. A claim about
 * SQL can only be checked by running the SQL, so this runs it. Skipped rather
 * than run against H2, whose type inference is not Postgres's and would have
 * happily passed the broken query.
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
class HoleAdvicePostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private HoleAdviceService service;
    private Long courseId;

    @BeforeEach
    void setUp() {
        // No key and no Redis: this probe is about the SQL, and an
        // unconfigured gateway makes the service return the facts alone —
        // which is exactly the part being checked.
        service = new HoleAdviceService(
                em,
                new LlmGateway(new ObjectMapper(), "", "", ""),
                null,
                new ObjectMapper());

        GolfFacility facility = new GolfFacility();
        facility.setName("Hole advice probe facility");
        stamp(facility.getMetadata());
        em.persist(facility);

        Course course = new Course();
        course.setFacility(facility);
        course.setName("Hole advice probe course");
        course.setHolesCount(18);
        course.setParTotal(72);
        stamp(course.getMetadata());
        em.persist(course);

        Hole hole = new Hole();
        hole.setCourse(course);
        hole.setHoleNumber(7);
        hole.setPar(4);
        hole.setPlayingLengthMeters(new BigDecimal("379.48"));
        stamp(hole.getMetadata());
        em.persist(hole);
        em.flush();

        courseId = course.getId();
    }

    private static void stamp(DataQualityMetadata metadata) {
        metadata.setPublisher("hole-advice-test");
        metadata.setEffectiveDate(LocalDate.now());
        metadata.setConfidence(BigDecimal.ZERO);
    }

    /// The bug. A golfer opening a hole without having picked a tee is the
    /// ordinary case, and it was a 500.
    @Test
    @DisplayName("a request that names no tee is answered, not a 500")
    void answersWithoutATee() {
        var advice = service.advise(courseId, 7, null, 1L);

        assertThat(advice.par()).isEqualTo(4);
        assertThat(advice.meters()).isEqualByComparingTo("379.48");
        assertThat(advice.roundsPlayed()).isZero();
        // No model configured, so the sentence is absent and the facts stand.
        assertThat(advice.advice()).isNull();
    }

    @Test
    @DisplayName("a request that names a tee is answered too")
    void answersWithATee() {
        var advice = service.advise(courseId, 7, "Black", 1L);

        assertThat(advice.par()).isEqualTo(4);
    }

    /// A hole the course does not have must say so rather than fall through
    /// the query into an unhandled failure.
    @Test
    @DisplayName("a hole this course does not have is a course-not-found, not a crash")
    void refusesAHoleThatIsNotThere() {
        assertThatThrownBy(() -> service.advise(courseId, 12, null, 1L))
                .isInstanceOf(VspApiException.class);
    }

    /// A golfer with no rounds, no profile and no bag is most golfers, and
    /// each of those three queries has to survive finding nothing.
    @Test
    @DisplayName("a golfer with no history, profile or bag is answered")
    void answersForAGolferWithNothingOnRecord() {
        var advice = service.advise(courseId, 7, null, 999_999L);

        assertThat(advice.roundsPlayed()).isZero();
        assertThat(advice.averageStrokes()).isNull();
        assertThat(advice.bestStrokes()).isNull();
    }
}
