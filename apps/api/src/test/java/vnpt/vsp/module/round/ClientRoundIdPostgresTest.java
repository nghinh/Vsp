package vnpt.vsp.module.round;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The id survives the round trip through Hibernate.
 *
 * <p>This is the half of the change that a mocked repository cannot see. The
 * {@code rounds.id} column was filled by {@code @GeneratedValue}; it is now
 * assigned in the entity so a caller can choose it. That changes which branch
 * Spring Data takes on save — an entity arriving with an id is not new, so it
 * is merged rather than persisted — and whether an assigned UUID actually
 * reaches the table is a question about Hibernate, not about our code.</p>
 *
 * <p>Asserted against the row itself rather than the returned object, because
 * merge hands back a different instance and it would happily report an id the
 * database does not have.</p>
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
class ClientRoundIdPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;
    @Autowired private RoundRepository roundRepository;

    private long golferId;
    private long courseId;

    @BeforeEach
    void setUp() {
        golferId = ((Number) em.createNativeQuery("""
                INSERT INTO golfer_accounts (phone, display_name, status, created_at, updated_at)
                VALUES ('+849' || floor(random() * 100000000), 'Client id probe', 'ACTIVE', now(), now())
                RETURNING id
                """).getSingleResult()).longValue();

        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('Client id probe facility', 'client-id-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();

        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:facility, 'Client id probe course', 9, 36, 'client-id-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("facility", facilityId).getSingleResult()).longValue();
    }

    private Round roundWith(UUID id) {
        Round round = new Round();
        round.setId(id);
        round.setCourseId(courseId);
        round.setGolferAccountId(golferId);
        round.setStatus(Round.RoundStatus.IN_PROGRESS);
        round.setStartedAt(Instant.now());
        return round;
    }

    @Test
    @DisplayName("a round saved under a chosen id is in the table under that id")
    void assignedIdReachesTheTable() {
        UUID chosen = UUID.randomUUID();

        roundRepository.save(roundWith(chosen));
        em.flush();
        em.clear();

        Object found = em.createNativeQuery("SELECT id FROM rounds WHERE id = :id")
                .setParameter("id", chosen)
                .getSingleResult();
        assertThat(found).isEqualTo(chosen);
    }

    @Test
    @DisplayName("a round saved without one still gets an id of its own")
    void theDefaultStillWorks() {
        // Nothing about the ordinary path changed, and this is what would
        // break loudly if the generator were still needed.
        Round round = new Round();
        round.setCourseId(courseId);
        round.setGolferAccountId(golferId);
        round.setStatus(Round.RoundStatus.IN_PROGRESS);
        round.setStartedAt(Instant.now());

        Round saved = roundRepository.save(round);
        em.flush();

        assertThat(saved.getId()).isNotNull();
        assertThat(roundRepository.findById(saved.getId())).isPresent();
    }

    @Test
    @DisplayName("saving the same id twice leaves one row, not two")
    void theSameIdTwiceIsOneRound() {
        // What a phone retrying a round start looks like from the database's
        // side. Two rows would be one afternoon in the history twice.
        UUID chosen = UUID.randomUUID();

        roundRepository.save(roundWith(chosen));
        em.flush();
        em.clear();
        roundRepository.save(roundWith(chosen));
        em.flush();
        em.clear();

        Number rows = (Number) em.createNativeQuery(
                        "SELECT count(*) FROM rounds WHERE id = :id")
                .setParameter("id", chosen)
                .getSingleResult();
        assertThat(rows.intValue()).isEqualTo(1);
    }
}
