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

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Closing rounds nobody played, and only those.
 *
 * <p>The rule has to be exactly right in both directions. Too eager and it
 * closes a round a golfer is walking down the first fairway of; too timid and
 * "Đang chơi" stays full of rounds that were never played.
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
class EmptyRoundSweepPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private long courseId;
    private long accountId;

    @BeforeEach
    void setUp() {
        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Sweep probe facility', 'sweep-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:f, 'Sweep probe course', 9, 36, 'sweep-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("f", facilityId).getSingleResult()).longValue();
        accountId = ((Number) em.createNativeQuery("""
                INSERT INTO golfer_accounts (display_name, email, status, created_at, updated_at)
                VALUES ('Sweep probe golfer',
                        'sweep-' || gen_random_uuid() || '@probe.test',
                        'ACTIVE', now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        em.flush();
    }

    /// A round created [hoursAgo] hours ago, optionally with a stroke on it.
    private UUID round(int hoursAgo, boolean withStroke) {
        UUID roundId = (UUID) em.createNativeQuery("""
                INSERT INTO rounds (id, course_id, golfer_account_id, status,
                                    created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :account, 'IN_PROGRESS',
                        now() - make_interval(hours => :ago),
                        now() - make_interval(hours => :ago))
                RETURNING id
                """)
                .setParameter("course", courseId)
                .setParameter("account", accountId)
                .setParameter("ago", hoursAgo)
                .getSingleResult();

        // Every round carries a scorecard row per player from the moment it is
        // created; it is the strokes that say whether anybody played.
        UUID scoreId = (UUID) em.createNativeQuery("""
                INSERT INTO scores (id, round_id, golfer_account_id, created_at, updated_at)
                VALUES (gen_random_uuid(), :round, :account, now(), now())
                RETURNING id
                """)
                .setParameter("round", roundId)
                .setParameter("account", accountId)
                .getSingleResult();

        if (withStroke) {
            em.createNativeQuery("""
                    INSERT INTO score_entries (id, score_id, hole_number, par, strokes, created_at, updated_at)
                    VALUES (gen_random_uuid(), :score, 1, 4, 4, now(), now())
                    """)
                    .setParameter("score", scoreId)
                    .executeUpdate();
        }
        em.flush();
        return roundId;
    }

    private String statusOf(UUID roundId) {
        return (String) em.createNativeQuery(
                "SELECT status FROM rounds WHERE id = :id")
                .setParameter("id", roundId)
                .getSingleResult();
    }

    @Test
    @DisplayName("a round nobody scored on is closed once the grace has passed")
    void closesAnEmptyRound() {
        UUID abandoned = round(12, false);

        new EmptyRoundSweep(em, 6).sweep();
        em.clear();

        assertThat(statusOf(abandoned)).isEqualTo("ABANDONED");
    }

    /// The one that matters most: a golfer on the course.
    @Test
    @DisplayName("a round with a single stroke on it is left alone, however old")
    void keepsARoundSomebodyPlayed() {
        UUID played = round(48, true);

        new EmptyRoundSweep(em, 6).sweep();
        em.clear();

        assertThat(statusOf(played)).isEqualTo("IN_PROGRESS");
    }

    /// A golfer who has just teed off has no score yet either.
    @Test
    @DisplayName("a round started minutes ago is inside the grace period")
    void keepsAFreshRound() {
        UUID fresh = round(1, false);

        new EmptyRoundSweep(em, 6).sweep();
        em.clear();

        assertThat(statusOf(fresh)).isEqualTo("IN_PROGRESS");
    }

    @Test
    @DisplayName("a round somebody already finished is not touched")
    void ignoresFinishedRounds() {
        UUID finished = round(24, false);
        em.createNativeQuery("UPDATE rounds SET status = 'COMPLETED' WHERE id = :id")
                .setParameter("id", finished).executeUpdate();
        em.flush();

        new EmptyRoundSweep(em, 6).sweep();
        em.clear();

        assertThat(statusOf(finished)).isEqualTo("COMPLETED");
    }

    @Test
    @DisplayName("the grace period is configurable")
    void honoursTheConfiguredGrace() {
        UUID round = round(12, false);

        new EmptyRoundSweep(em, 24).sweep();
        em.clear();
        assertThat(statusOf(round)).isEqualTo("IN_PROGRESS");

        new EmptyRoundSweep(em, 6).sweep();
        em.clear();
        assertThat(statusOf(round)).isEqualTo("ABANDONED");
    }
}
