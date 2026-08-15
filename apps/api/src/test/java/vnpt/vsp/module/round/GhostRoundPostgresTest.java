package vnpt.vsp.module.round;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Which round the ghost is.
 *
 * <p>The choosing is the behaviour: best against par, completed rounds only,
 * same course pairing only, and silence — not an error — when a golfer has
 * never finished a round there.
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
class GhostRoundPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private GhostRoundService service;
    private long golferId;
    private long courseId;

    @BeforeEach
    void setUp() {
        service = new GhostRoundService(em);

        golferId = ((Number) em.createNativeQuery("""
                INSERT INTO golfer_accounts (phone, display_name, status, created_at, updated_at)
                VALUES ('+849' || floor(random() * 100000000), 'Ghost Probe', 'ACTIVE', now(), now())
                RETURNING id
                """).getSingleResult()).longValue();

        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Ghost probe facility', 'ghost-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();

        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Ghost probe course', 9, 36, 'ghost-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();

        // Two completed rounds: 40 strokes, then 38 — the 38 is the ghost.
        round("COMPLETED", 40);
        round("COMPLETED", 38);
        // A better round still in progress does not haunt anyone yet.
        round("IN_PROGRESS", 36);
        em.flush();
    }

    private void round(String status, int totalStrokes) {
        UUID roundId = (UUID) em.createNativeQuery("""
                INSERT INTO rounds (golfer_account_id, course_id, status, started_at, ended_at)
                VALUES (:golfer, :course, :status, now(), now())
                RETURNING id
                """)
                .setParameter("golfer", golferId)
                .setParameter("course", courseId)
                .setParameter("status", status)
                .getSingleResult();
        UUID scoreId = (UUID) em.createNativeQuery("""
                INSERT INTO scores (round_id, golfer_account_id)
                VALUES (:round, :golfer) RETURNING id
                """)
                .setParameter("round", roundId)
                .setParameter("golfer", golferId)
                .getSingleResult();
        // Nine par-4 holes; the difference lands on the ninth.
        for (int hole = 1; hole <= 9; hole++) {
            int strokes = hole < 9 ? 4 : totalStrokes - 32;
            em.createNativeQuery("""
                    INSERT INTO score_entries (score_id, hole_number, par, strokes)
                    VALUES (:score, :hole, 4, :strokes)
                    """)
                    .setParameter("score", scoreId)
                    .setParameter("hole", hole)
                    .setParameter("strokes", strokes)
                    .executeUpdate();
        }
    }

    @Test
    @DisplayName("the ghost is the best completed round, hole by hole")
    void picksTheBestCompletedRound() {
        var ghost = service.ghost(courseId, null, golferId);

        assertThat(ghost).isNotNull();
        assertThat(ghost.totalStrokes()).isEqualTo(38);
        assertThat(ghost.holes()).hasSize(9);
        assertThat(ghost.holes().get(8).strokes()).isEqualTo(6);
        assertThat(ghost.playedOn()).isEqualTo(LocalDate.now());
    }

    /// A first round on a course has no ghost, and that is a fact, not a 404.
    @Test
    @DisplayName("a course never played answers nothing")
    void answersNullWhereThereIsNoHistory() {
        assertThat(service.ghost(999_999_999L, null, golferId)).isNull();
    }

    /// The pairing is part of the identity: a front nine plus a different
    /// back nine is a different race.
    @Test
    @DisplayName("a two-nine pairing does not borrow the single-course ghost")
    void aPairingIsItsOwnRace() {
        assertThat(service.ghost(courseId, courseId, golferId)).isNull();
    }
}
