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
 * A golfer's own numbers.
 *
 * <p>What is asserted hardest is the difference between zero and unknown. A
 * golfer who has never ticked the greens-in-regulation box has not hit 0% of
 * greens, and a tile that says so is a lie the golfer cannot see through.
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
class GolferPerformancePostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private GolferPerformanceService service;
    private long golferId;

    @BeforeEach
    void setUp() {
        service = new GolferPerformanceService(em, new AppHandicapService(em));
        golferId = ((Number) em.createNativeQuery("""
                INSERT INTO golfer_accounts (phone, display_name, status, created_at, updated_at)
                VALUES ('+849' || floor(random() * 100000000), 'Stats Probe', 'ACTIVE', now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
    }

    /// One round of nine par-4s: a birdie, six pars, a bogey and a triple.
    /// Putts, greens and fairways recorded only when [withDetail].
    private UUID round(boolean withDetail) {
        UUID roundId = (UUID) em.createNativeQuery("""
                INSERT INTO rounds (golfer_account_id, status, started_at, ended_at)
                VALUES (:golfer, 'COMPLETED', now(), now())
                RETURNING id
                """).setParameter("golfer", golferId).getSingleResult();
        UUID scoreId = (UUID) em.createNativeQuery("""
                INSERT INTO scores (round_id, golfer_account_id)
                VALUES (:round, :golfer) RETURNING id
                """)
                .setParameter("round", roundId)
                .setParameter("golfer", golferId)
                .getSingleResult();
        int[] strokes = {3, 4, 4, 4, 4, 4, 4, 5, 7};
        for (int hole = 1; hole <= 9; hole++) {
            em.createNativeQuery("""
                    INSERT INTO score_entries
                        (score_id, hole_number, par, strokes, putts, penalties, gir, fairway_hit)
                    VALUES (:score, :hole, 4, :strokes, :putts, :penalties, :gir, :fairway)
                    """)
                    .setParameter("score", scoreId)
                    .setParameter("hole", hole)
                    .setParameter("strokes", strokes[hole - 1])
                    .setParameter("putts", withDetail ? 2 : null)
                    .setParameter("penalties", hole == 9 ? 1 : 0)
                    .setParameter("gir", withDetail ? hole <= 3 : null)
                    .setParameter("fairway", withDetail ? hole <= 5 : null)
                    .executeUpdate();
        }
        em.flush();
        return roundId;
    }

    @Test
    @DisplayName("counts the holes, the piles and the best round")
    void countsWhatWasPlayed() {
        round(true);

        var stats = service.compute(golferId, null);

        assertThat(stats.rounds()).isEqualTo(1);
        assertThat(stats.holes()).isEqualTo(9);
        // 39 strokes against par 36.
        assertThat(stats.bestToPar()).isEqualTo(3);
        assertThat(stats.bestToParHoles()).isEqualTo(9);
        assertThat(bucket(stats, "BIRDIE")).isEqualTo(1);
        assertThat(bucket(stats, "PAR")).isEqualTo(6);
        assertThat(bucket(stats, "BOGEY")).isEqualTo(1);
        assertThat(bucket(stats, "TRIPLE_OR_WORSE")).isEqualTo(1);
        assertThat(stats.penaltiesPerRound()).isEqualByComparingTo("1.00");
    }

    @Test
    @DisplayName("putts, greens and fairways come from the holes that recorded them")
    void countsTheDetailWhereItExists() {
        round(true);

        var stats = service.compute(golferId, null);

        assertThat(stats.puttsPerHole()).isEqualByComparingTo("2.00");
        assertThat(stats.holesWithPutts()).isEqualTo(9);
        assertThat(stats.girPercent()).isEqualByComparingTo("33");   // 3 of 9
        assertThat(stats.fairwayPercent()).isEqualByComparingTo("56"); // 5 of 9
    }

    /// The distinction the screen depends on: nobody recorded a green, so
    /// there is no percentage — not a zero.
    @Test
    @DisplayName("a round with no detail recorded reports nothing, not zero")
    void tellsUnknownApartFromZero() {
        round(false);

        var stats = service.compute(golferId, null);

        assertThat(stats.puttsPerHole()).isNull();
        assertThat(stats.girPercent()).isNull();
        assertThat(stats.fairwayPercent()).isNull();
        assertThat(stats.holesWithGir()).isZero();
        // The scoring itself is still counted.
        assertThat(stats.holes()).isEqualTo(9);
        assertThat(bucket(stats, "PAR")).isEqualTo(6);
    }

    @Test
    @DisplayName("the window keeps only the most recent rounds")
    void honoursTheWindow() {
        round(true);
        round(true);
        round(true);

        assertThat(service.compute(golferId, null).rounds()).isEqualTo(3);
        assertThat(service.compute(golferId, 2).rounds()).isEqualTo(2);
        assertThat(service.compute(golferId, 2).holes()).isEqualTo(18);
    }

    @Test
    @DisplayName("each par says what it costs this golfer")
    void averagesByPar() {
        round(true);

        var byPar = service.compute(golferId, null).byPar();

        assertThat(byPar).hasSize(1);
        assertThat(byPar.get(0).par()).isEqualTo(4);
        assertThat(byPar.get(0).holes()).isEqualTo(9);
        assertThat(byPar.get(0).best()).isEqualTo(3);
        assertThat(byPar.get(0).worst()).isEqualTo(7);
    }

    @Test
    @DisplayName("a golfer who has played nothing gets an empty page, not an error")
    void answersForANewGolfer() {
        var stats = service.compute(golferId, null);

        assertThat(stats.rounds()).isZero();
        assertThat(stats.holes()).isZero();
        assertThat(stats.bestToPar()).isNull();
        assertThat(stats.byPar()).isEmpty();
        assertThat(stats.handicap()).isNull();
    }

    private static int bucket(vnpt.vsp.module.profile.dto.GolferPerformanceResponse stats,
                              String label) {
        return stats.distribution().stream()
                .filter(b -> b.label().equals(label))
                .findFirst()
                .orElseThrow()
                .holes();
    }
}
