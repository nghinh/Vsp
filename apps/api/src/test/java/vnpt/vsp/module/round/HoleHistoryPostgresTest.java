package vnpt.vsp.module.round;

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

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * What a golfer standing on a tee is shown about the last time they stood there.
 *
 * <p>The two rules with something at stake: the record is theirs alone, and a
 * round nobody played is not a previous attempt.
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
class HoleHistoryPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private EntityManager em;

    private HoleHistoryService service;
    private long courseId;
    private long me;
    private long somebodyElse;

    @BeforeEach
    void setUp() {
        service = new HoleHistoryService(em);

        long facilityId = ((Number) em.createNativeQuery("""
                INSERT INTO golf_facilities (name, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES ('History probe facility', 'history-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).getSingleResult()).longValue();
        courseId = ((Number) em.createNativeQuery("""
                INSERT INTO courses (facility_id, name, holes_count, par_total, publisher, effective_date, confidence, version, created_at, updated_at)
                VALUES (:f, 'History probe course', 9, 36, 'history-test', CURRENT_DATE, 0, 0, now(), now())
                RETURNING id
                """).setParameter("f", facilityId).getSingleResult()).longValue();
        me = golfer("Me");
        somebodyElse = golfer("Somebody else");
        em.flush();
    }

    private long golfer(String name) {
        return ((Number) em.createNativeQuery("""
                INSERT INTO golfer_accounts (display_name, email, status, created_at, updated_at)
                VALUES (:name, 'h-' || gen_random_uuid() || '@probe.test', 'ACTIVE', now(), now())
                RETURNING id
                """).setParameter("name", name).getSingleResult()).longValue();
    }

    /// A played round with one stroke recorded on [hole].
    private UUID playedRound(long account, int hole, int strokes, int par,
                             String status, int daysAgo) {
        UUID roundId = (UUID) em.createNativeQuery("""
                INSERT INTO rounds (id, course_id, golfer_account_id, status,
                                    started_at, created_at, updated_at)
                VALUES (gen_random_uuid(), :course, :account, :status,
                        now() - make_interval(days => :ago),
                        now() - make_interval(days => :ago), now())
                RETURNING id
                """)
                .setParameter("course", courseId)
                .setParameter("account", account)
                .setParameter("status", status)
                .setParameter("ago", daysAgo)
                .getSingleResult();

        UUID scoreId = (UUID) em.createNativeQuery("""
                INSERT INTO scores (id, round_id, golfer_account_id, created_at, updated_at)
                VALUES (gen_random_uuid(), :round, :account, now(), now())
                RETURNING id
                """)
                .setParameter("round", roundId)
                .setParameter("account", account)
                .getSingleResult();

        em.createNativeQuery("""
                INSERT INTO score_entries (id, score_id, hole_number, par, strokes, created_at, updated_at)
                VALUES (gen_random_uuid(), :score, :hole, :par, :strokes, now(), now())
                """)
                .setParameter("score", scoreId)
                .setParameter("hole", hole)
                .setParameter("par", par)
                .setParameter("strokes", strokes)
                .executeUpdate();
        em.flush();
        return roundId;
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> scoresOf(Map<String, Object> history) {
        return (List<Map<String, Object>>) history.get("scores");
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> notesOf(Map<String, Object> history) {
        return (List<Map<String, Object>>) history.get("notes");
    }

    @Test
    @DisplayName("past scores on the hole come back newest first")
    void listsPastScoresNewestFirst() {
        playedRound(me, 4, 6, 4, "COMPLETED", 30);
        playedRound(me, 4, 4, 4, "COMPLETED", 2);

        var scores = scoresOf(service.forHole(me, courseId, 4));

        assertThat(scores).hasSize(2);
        assertThat(scores.get(0)).containsEntry("strokes", 4);
        assertThat(scores.get(0)).containsEntry("toPar", 0);
        assertThat(scores.get(1)).containsEntry("strokes", 6);
        assertThat(scores.get(1)).containsEntry("toPar", 2);
    }

    @Test
    @DisplayName("the summary is how it usually goes and the best it has gone")
    void summarisesTheHole() {
        playedRound(me, 4, 6, 4, "COMPLETED", 30);
        playedRound(me, 4, 4, 4, "COMPLETED", 10);
        playedRound(me, 4, 5, 4, "COMPLETED", 2);

        var history = service.forHole(me, courseId, 4);

        assertThat(history).containsEntry("timesPlayed", 3);
        assertThat(history).containsEntry("averageStrokes", 5.0);
        assertThat(history).containsEntry("bestStrokes", 4);
    }

    /// A tee nobody has played shows nothing rather than an average of zero,
    /// which reads as a score.
    @Test
    @DisplayName("a hole never played reports no numbers at all")
    void saysNothingAboutANewHole() {
        var history = service.forHole(me, courseId, 7);

        assertThat(history).containsEntry("timesPlayed", 0);
        assertThat(history.get("averageStrokes")).isNull();
        assertThat(history.get("bestStrokes")).isNull();
        assertThat(scoresOf(history)).isEmpty();
    }

    /// The round nobody played. Sixteen of these were sitting in the database.
    @Test
    @DisplayName("an abandoned round is not a previous attempt")
    void ignoresAbandonedRounds() {
        playedRound(me, 4, 5, 4, "ABANDONED", 3);

        assertThat(scoresOf(service.forHole(me, courseId, 4))).isEmpty();
    }

    @Test
    @DisplayName("another golfer's rounds on the same hole are not mine")
    void keepsGolfersApart() {
        playedRound(somebodyElse, 4, 3, 4, "COMPLETED", 1);
        playedRound(me, 4, 7, 4, "COMPLETED", 1);

        var mine = scoresOf(service.forHole(me, courseId, 4));

        assertThat(mine).hasSize(1);
        assertThat(mine.get(0)).containsEntry("strokes", 7);
    }

    @Test
    @DisplayName("only this hole, not the whole card")
    void keepsHolesApart() {
        playedRound(me, 4, 5, 4, "COMPLETED", 1);
        playedRound(me, 5, 3, 3, "COMPLETED", 1);

        assertThat(scoresOf(service.forHole(me, courseId, 4))).hasSize(1);
        assertThat(scoresOf(service.forHole(me, courseId, 5))).hasSize(1);
    }

    @Test
    @DisplayName("a note written on the hole comes back next time")
    void keepsWhatTheGolferWrote() {
        UUID round = playedRound(me, 4, 6, 4, "COMPLETED", 20);
        service.addNote(me, courseId, 4,
                "Driver chạy vào rãnh — đánh gỗ 3 là đủ", round);

        var notes = notesOf(service.forHole(me, courseId, 4));

        assertThat(notes).hasSize(1);
        assertThat(notes.get(0).get("note").toString()).contains("gỗ 3");
        assertThat(notes.get(0).get("roundId")).isEqualTo(round.toString());
    }

    /// Several notes over time is the point: what a golfer wrote in March and
    /// in August is a record of them learning the hole.
    @Test
    @DisplayName("notes accumulate, newest first")
    void keepsSeveralNotes() {
        service.addNote(me, courseId, 4, "Green dốc mạnh về sau", null);
        service.addNote(me, courseId, 4, "Gió thường ngược ở đây", null);

        var notes = notesOf(service.forHole(me, courseId, 4));

        assertThat(notes).hasSize(2);
        assertThat(notes.get(0).get("note").toString()).contains("Gió");
    }

    @Test
    @DisplayName("a note between rounds carries no round")
    void allowsANoteWithNoRound() {
        service.addNote(me, courseId, 4, "Xem lại chỗ phát bóng", null);

        assertThat(notesOf(service.forHole(me, courseId, 4)).get(0).get("roundId"))
                .isNull();
    }

    @Test
    @DisplayName("an empty note is refused rather than stored blank")
    void refusesAnEmptyNote() {
        assertThatThrownBy(() -> service.addNote(me, courseId, 4, "   ", null))
                .isInstanceOf(VspApiException.class);
        assertThatThrownBy(() -> service.addNote(me, courseId, 4, null, null))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("another golfer's notes are not mine")
    void keepsNotesPrivate() {
        service.addNote(somebodyElse, courseId, 4, "Their note", null);
        service.addNote(me, courseId, 4, "My note", null);

        var mine = notesOf(service.forHole(me, courseId, 4));

        assertThat(mine).hasSize(1);
        assertThat(mine.get(0)).containsEntry("note", "My note");
    }

    @Test
    @DisplayName("a golfer can remove their own note and nobody else's")
    void deletesOnlyOwnNotes() {
        long mineId = ((Number) service.addNote(me, courseId, 4, "Mine", null)
                .get("id")).longValue();

        assertThat(service.deleteNote(somebodyElse, mineId)).isFalse();
        assertThat(notesOf(service.forHole(me, courseId, 4))).hasSize(1);

        assertThat(service.deleteNote(me, mineId)).isTrue();
        assertThat(notesOf(service.forHole(me, courseId, 4))).isEmpty();
    }
}
