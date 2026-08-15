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

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Today's flag, and only today's.
 *
 * <p>The rule with teeth: an expired placement must not come back. A golfer
 * aiming at last week's flag walks confidently to the wrong half of the
 * green, which is worse than being told nothing.
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
class CoursePinPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private CoursePinController controller;
    private long courseId;

    @BeforeEach
    void setUp() {
        controller = new CoursePinController(em);

        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Pin probe facility', 'pin-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Pin probe course', 18, 72, 'pin-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();

        long holeOne = hole(1);
        long holeTwo = hole(2);

        // Today's flag on the 1st, and last week's, which must not surface.
        pin(holeOne, 21.0300, 105.8500, "now() - interval '2 hours'", "NULL");
        pin(holeOne, 21.0399, 105.8599,
                "now() - interval '9 days'", "now() - interval '7 days'");
        // A flag on the 2nd that has not started yet — tomorrow's tournament
        // placement, published early.
        pin(holeTwo, 21.0500, 105.8600,
                "now() + interval '1 day'", "NULL");
        em.flush();
    }

    private long hole(int number) {
        return ((Number) em.createNativeQuery("""
                INSERT INTO holes (course_id, hole_number, par, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:course, :number, 4, 'pin-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """)
                .setParameter("course", courseId)
                .setParameter("number", number)
                .getSingleResult()).longValue();
    }

    private void pin(long holeId, double lat, double lng, String from, String until) {
        em.createNativeQuery("""
                INSERT INTO pin_positions_ops
                    (hole_id, location, pin_position_type, published_by, publisher, confidence,
                     effective_from, expires_at, effective_date, version, created_at, updated_at)
                VALUES (:hole, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 'CURRENT',
                        'pin-test', 'pin-test', 90, %s, %s, CURRENT_DATE, 0, now(), now())
                """.formatted(from, until))
                .setParameter("hole", holeId)
                .setParameter("lat", lat)
                .setParameter("lng", lng)
                .executeUpdate();
    }

    @Test
    @DisplayName("today's flag comes back, decoded, and yesterday's does not")
    void answersOnlyTheCurrentPin() {
        var pins = controller.pins(courseId);

        assertThat(pins).hasSize(1);
        var pin = pins.get(0);
        assertThat(pin.holeNumber()).isEqualTo(1);
        // Coordinates arrive as numbers, not WKB the phone cannot read.
        assertThat(pin.latitude()).isEqualTo(21.0300);
        assertThat(pin.longitude()).isEqualTo(105.8500);
        assertThat(pin.type()).isEqualTo("CURRENT");
    }

    @Test
    @DisplayName("a course with no published pins answers an empty list")
    void answersNothingWhereNoOnePublishes() {
        assertThat(controller.pins(999_999_999L)).isEmpty();
    }
}
