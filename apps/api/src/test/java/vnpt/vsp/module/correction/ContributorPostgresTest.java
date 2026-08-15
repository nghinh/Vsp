package vnpt.vsp.module.correction;

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
 * Who gets the credit, and who does not.
 *
 * <p>The rule worth a test: a pending submission is not a contribution.
 * Counting the queue would reward volume over accuracy in a dataset whose
 * entire value is being right.
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
class ContributorPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private ContributorService service;
    private long courseId;
    private String busyName;

    @BeforeEach
    void setUp() {
        service = new ContributorService(em);

        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Contributor probe facility', 'contrib-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Contributor probe course', 18, 72, 'contrib-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();

        busyName = "Người săn thẻ " + System.nanoTime();
        long busy = golfer(busyName);
        long quiet = golfer("Người mới nộp " + System.nanoTime());

        correction(busy, "APPROVED");
        correction(busy, "APPROVED");
        // Submitted, not yet agreed with: not a contribution.
        correction(quiet, "PENDING");
        em.flush();
    }

    private long golfer(String name) {
        return ((Number) em.createNativeQuery("""
                INSERT INTO golfer_accounts (phone, display_name, status, created_at, updated_at)
                VALUES ('+849' || floor(random() * 100000000), :name, 'ACTIVE', now(), now())
                RETURNING id
                """).setParameter("name", name).getSingleResult()).longValue();
    }

    private void correction(long reporterId, String status) {
        // The payload is required by chk_correction_scorecard_payload: a
        // SCORECARD correction that proposes no card is not one.
        em.createNativeQuery("""
                INSERT INTO course_corrections
                    (course_id, reporter_id, correction_type, proposed_scorecard, status,
                     publisher, effective_date, submitted_at, reviewed_at, created_at, updated_at)
                VALUES (:course, :reporter, 'SCORECARD', CAST('{"holes":[]}' AS jsonb), :status,
                        'contrib-test', CURRENT_DATE, now(),
                        CASE WHEN :status = 'APPROVED' THEN now() ELSE NULL END, now(), now())
                """)
                .setParameter("course", courseId)
                .setParameter("reporter", reporterId)
                .setParameter("status", status)
                .executeUpdate();
    }

    @Test
    @DisplayName("credit follows approved cards, and a pending one earns none")
    void countsOnlyApproved() {
        var forCourse = service.forCourse(courseId);

        assertThat(forCourse).hasSize(1);
        assertThat(forCourse.get(0).displayName()).isEqualTo(busyName);
        assertThat(forCourse.get(0).approvedCorrections()).isEqualTo(2);
        assertThat(forCourse.get(0).coursesCovered()).isEqualTo(1);
        assertThat(forCourse.get(0).lastContributedOn()).isNotNull();
    }

    @Test
    @DisplayName("the leaderboard names the same people, most first")
    void leaderboardIsOrdered() {
        var board = service.leaderboard();

        assertThat(board).isNotEmpty();
        assertThat(board.get(0).approvedCorrections())
                .isGreaterThanOrEqualTo(board.get(board.size() - 1).approvedCorrections());
        assertThat(board).anyMatch(c -> c.displayName().equals(busyName));
    }
}
