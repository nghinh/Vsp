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
import vnpt.vsp.persistence.PostgresTestSupport;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The recap's queries, against the database that runs them.
 *
 * <p>Native SQL over five tables with a UUID round id and an aggregate per
 * pile — the shape of query the hole-advice 42P18 bug taught this project to
 * run for real. No model is configured, so what is asserted is the facts:
 * the counts, the best hole, the ownership check.
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
class RoundRecapPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private RoundRecapService service;
    private UUID roundId;
    private long golferId;

    @BeforeEach
    void setUp() {
        service = new RoundRecapService(
                em, new LlmGateway(new ObjectMapper(), "", "", ""), null);

        // The account, straight into the table: the entity model wants a
        // phone-or-email dance this test has no stake in.
        golferId = ((Number) em.createNativeQuery("""
                INSERT INTO golfer_accounts (phone, display_name, status, created_at, updated_at)
                VALUES ('+849' || floor(random() * 100000000), 'Recap Probe', 'ACTIVE', now(), now())
                RETURNING id
                """).getSingleResult()).longValue();

        roundId = (UUID) em.createNativeQuery("""
                INSERT INTO rounds (golfer_account_id, status, started_at, ended_at)
                VALUES (:golfer, 'COMPLETED', now(), now())
                RETURNING id
                """).setParameter("golfer", golferId).getSingleResult();

        UUID scoreId = (UUID) em.createNativeQuery("""
                INSERT INTO scores (round_id, golfer_account_id)
                VALUES (:round, :golfer)
                RETURNING id
                """)
                .setParameter("round", roundId)
                .setParameter("golfer", golferId)
                .getSingleResult();

        // Nine holes: a birdie on 3, pars, a double on 7, two penalties.
        int[][] holes = {
                {1, 4, 4}, {2, 4, 4}, {3, 4, 3}, {4, 3, 3}, {5, 5, 5},
                {6, 4, 5}, {7, 4, 6}, {8, 3, 3}, {9, 5, 5},
        };
        for (int[] h : holes) {
            em.createNativeQuery("""
                    INSERT INTO score_entries (score_id, hole_number, par, strokes, penalties)
                    VALUES (:score, :hole, :par, :strokes, :penalties)
                    """)
                    .setParameter("score", scoreId)
                    .setParameter("hole", h[0])
                    .setParameter("par", h[1])
                    .setParameter("strokes", h[2])
                    .setParameter("penalties", h[0] == 7 ? 2 : 0)
                    .executeUpdate();
        }
        em.flush();
    }

    @Test
    @DisplayName("the card is sorted into the piles golfers talk in")
    void countsThePiles() {
        var recap = service.recap(roundId, golferId);

        assertThat(recap.holes()).isEqualTo(9);
        assertThat(recap.totalStrokes()).isEqualTo(38);
        assertThat(recap.totalPar()).isEqualTo(36);
        assertThat(recap.birdies()).isEqualTo(1);
        assertThat(recap.pars()).isEqualTo(6);
        assertThat(recap.bogeys()).isEqualTo(1);
        assertThat(recap.doubleOrWorse()).isEqualTo(1);
        assertThat(recap.penalties()).isEqualTo(2);
        // The birdie on 3 is the story.
        assertThat(recap.bestHoleNumber()).isEqualTo(3);
        // One round on record, so it is also the best.
        assertThat(recap.roundsOnRecord()).isEqualTo(1);
        assertThat(recap.isBestRound()).isTrue();
        // No model configured: the facts stand, the sentence is absent.
        assertThat(recap.recap()).isNull();
    }

    /// The recap is the golfer's own: someone else's round id answers
    /// not-found, not someone else's scores.
    @Test
    @DisplayName("a round this golfer did not play is a not-found")
    void refusesSomeoneElsesRound() {
        assertThatThrownBy(() -> service.recap(roundId, golferId + 1))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("a round with nothing scored has no story to tell")
    void refusesAnEmptyRound() {
        UUID empty = (UUID) em.createNativeQuery("""
                INSERT INTO rounds (golfer_account_id, status, started_at)
                VALUES (:golfer, 'IN_PROGRESS', now())
                RETURNING id
                """).setParameter("golfer", golferId).getSingleResult();
        em.flush();

        assertThatThrownBy(() -> service.recap(empty, golferId))
                .isInstanceOf(VspApiException.class);
    }
}
