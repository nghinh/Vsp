package vnpt.vsp.module.profile;

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
 * Which rounds are allowed to move a golfer's handicap.
 *
 * <p>Three were not being excluded and should have been: a round still in
 * progress, a round the golfer deleted, and a round played as practice. The
 * last is the worst of the three — the setup screen has offered "Tập luyện"
 * since it existed, so a golfer could decline to have a round counted, watch
 * it be counted, and have no way to tell.
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
class AppHandicapWindowPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private AppHandicapService service;
    private long golferId;

    @BeforeEach
    void setUp() {
        service = new AppHandicapService(em);
        golferId = ((Number) em.createNativeQuery("""
                INSERT INTO golfer_accounts (phone, display_name, status, created_at, updated_at)
                VALUES ('+849' || floor(random() * 100000000), 'Handicap Probe', 'ACTIVE', now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
    }

    /// A round of eighteen par-4s played in {@code overPar} over.
    private void round(String status, boolean deleted, boolean counts, int overPar) {
        UUID roundId = (UUID) em.createNativeQuery("""
                INSERT INTO rounds (golfer_account_id, status, started_at, ended_at,
                                    deleted_at, counts_toward_handicap, format)
                VALUES (:golfer, :status, now(), now(),
                        CASE WHEN :deleted THEN now() ELSE NULL END, :counts, 'CASUAL')
                RETURNING id
                """)
                .setParameter("golfer", golferId)
                .setParameter("status", status)
                .setParameter("deleted", deleted)
                .setParameter("counts", counts)
                .getSingleResult();
        UUID scoreId = (UUID) em.createNativeQuery("""
                INSERT INTO scores (round_id, golfer_account_id) VALUES (:round, :golfer)
                RETURNING id
                """)
                .setParameter("round", roundId)
                .setParameter("golfer", golferId)
                .getSingleResult();
        for (int hole = 1; hole <= 18; hole++) {
            em.createNativeQuery("""
                    INSERT INTO score_entries (score_id, hole_number, par, strokes)
                    VALUES (:score, :hole, 4, :strokes)
                    """)
                    .setParameter("score", scoreId)
                    .setParameter("hole", hole)
                    .setParameter("strokes", hole == 1 ? 4 + overPar : 4)
                    .executeUpdate();
        }
        em.flush();
    }

    @Test
    @DisplayName("three finished, counting rounds make a handicap")
    void countsTheRoundsThatCount() {
        round("COMPLETED", false, true, 10);
        round("COMPLETED", false, true, 12);
        round("COMPLETED", false, true, 14);

        var handicap = service.compute(golferId);

        assertThat(handicap.roundsCounted()).isEqualTo(3);
        assertThat(handicap.handicap()).isNotNull();
    }

    /// The bug the "Tập luyện" chip promised to prevent and did not.
    @Test
    @DisplayName("a practice round does not move the handicap")
    void ignoresPractice() {
        round("COMPLETED", false, true, 10);
        round("COMPLETED", false, true, 12);
        round("COMPLETED", false, true, 14);
        round("COMPLETED", false, false, 40);   // a bad practice round

        var handicap = service.compute(golferId);

        assertThat(handicap.roundsCounted()).isEqualTo(3);
    }

    @Test
    @DisplayName("a round still being played is not evidence yet")
    void ignoresRoundsInProgress() {
        round("COMPLETED", false, true, 10);
        round("IN_PROGRESS", false, true, 40);

        assertThat(service.compute(golferId).roundsCounted()).isEqualTo(1);
    }

    @Test
    @DisplayName("a deleted round stays deleted")
    void ignoresDeletedRounds() {
        round("COMPLETED", false, true, 10);
        round("COMPLETED", true, true, 40);

        assertThat(service.compute(golferId).roundsCounted()).isEqualTo(1);
    }

    /// Under three counting rounds there is no number, however many practice
    /// rounds sit behind it.
    @Test
    @DisplayName("practice rounds do not fill the three-round floor")
    void practiceDoesNotReachTheFloor() {
        round("COMPLETED", false, true, 10);
        round("COMPLETED", false, false, 10);
        round("COMPLETED", false, false, 10);

        var handicap = service.compute(golferId);

        assertThat(handicap.roundsCounted()).isEqualTo(1);
        assertThat(handicap.handicap()).isNull();
    }
}
