package vnpt.vsp.module.round;

import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * What this golfer has done on this hole before, and what they wrote about it.
 *
 * <p>Both halves answer the same question a golfer asks on the tee — "how does
 * this one go?" — and they answer it differently. The scores say what
 * happened; the notes say why, and the why is the part that is lost between
 * visits. A golfer works out on the fourth tee that the driver runs into the
 * ditch, plays a 3-wood for the rest of the day, and arrives next month with
 * a driver in their hand again.
 *
 * <p>Strictly this golfer's own. Not because the data is sensitive but because
 * it would be wrong: two players on the same tee have different notes, since
 * the note is about what their ball does.
 */
@Service
public class HoleHistoryService {

    /// Enough to see a pattern without turning the tee box into a spreadsheet.
    private static final int PAST_ROUNDS = 8;
    private static final int RECENT_NOTES = 5;

    private final EntityManager em;

    public HoleHistoryService(EntityManager em) {
        this.em = em;
    }

    /**
     * This golfer's past scores and notes on one hole.
     *
     * <p>Only rounds that were actually played: a round abandoned before a
     * stroke was written is not a previous attempt at this hole, and listing
     * it as one would put a blank row on the tee box.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> forHole(Long accountId, Long courseId, int holeNumber) {
        var response = new LinkedHashMap<String, Object>();
        response.put("courseId", courseId);
        response.put("holeNumber", holeNumber);
        response.put("scores", pastScores(accountId, courseId, holeNumber));
        response.put("notes", notes(accountId, courseId, holeNumber));
        response.putAll(summary(accountId, courseId, holeNumber));
        return response;
    }

    // No `::` casts in these queries — Hibernate reads them as parameters.
    private List<Map<String, Object>> pastScores(Long accountId, Long courseId,
                                                 int holeNumber) {
        var rows = em.createNativeQuery("""
                SELECT se.strokes, se.par, se.putts,
                       r.id, r.status,
                       coalesce(r.started_at, r.created_at)
                FROM score_entries se
                JOIN scores s ON s.id = se.score_id
                JOIN rounds r ON r.id = s.round_id
                WHERE s.golfer_account_id = :account
                  AND r.course_id = :course
                  AND se.hole_number = :hole
                  AND se.strokes IS NOT NULL
                  AND s.deleted_at IS NULL
                  AND r.deleted_at IS NULL
                  AND r.status <> 'ABANDONED'
                ORDER BY coalesce(r.started_at, r.created_at) DESC
                LIMIT :limit
                """)
                .setParameter("account", accountId)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .setParameter("limit", PAST_ROUNDS)
                .getResultList();

        var scores = new ArrayList<Map<String, Object>>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            var entry = new LinkedHashMap<String, Object>();
            int strokes = ((Number) r[0]).intValue();
            entry.put("strokes", strokes);
            entry.put("par", r[1] == null ? null : ((Number) r[1]).intValue());
            entry.put("putts", r[2] == null ? null : ((Number) r[2]).intValue());
            if (r[1] != null) {
                entry.put("toPar", strokes - ((Number) r[1]).intValue());
            }
            entry.put("roundId", r[3] == null ? null : r[3].toString());
            entry.put("playedAt", r[5] == null ? null : r[5].toString());
            scores.add(entry);
        }
        return scores;
    }

    private List<Map<String, Object>> notes(Long accountId, Long courseId,
                                            int holeNumber) {
        var rows = em.createNativeQuery("""
                SELECT n.id, n.note, n.created_at, n.round_id
                FROM hole_notes n
                WHERE n.golfer_account_id = :account
                  AND n.course_id = :course
                  AND n.hole_number = :hole
                  AND n.deleted_at IS NULL
                -- id breaks the tie. now() is the transaction's start time in
                -- Postgres, so two notes written in one transaction carry the
                -- same timestamp and "newest first" would be whatever order
                -- the planner felt like. The id is monotonic and says which
                -- was written second.
                ORDER BY n.created_at DESC, n.id DESC
                LIMIT :limit
                """)
                .setParameter("account", accountId)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .setParameter("limit", RECENT_NOTES)
                .getResultList();

        var notes = new ArrayList<Map<String, Object>>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            var note = new LinkedHashMap<String, Object>();
            note.put("id", ((Number) r[0]).longValue());
            note.put("note", r[1]);
            note.put("createdAt", r[2] == null ? null : r[2].toString());
            note.put("roundId", r[3] == null ? null : r[3].toString());
            notes.add(note);
        }
        return notes;
    }

    /// The two numbers worth reading at a glance: how it usually goes, and
    /// the best it has ever gone.
    private Map<String, Object> summary(Long accountId, Long courseId,
                                        int holeNumber) {
        var rows = em.createNativeQuery("""
                SELECT count(*), avg(se.strokes), min(se.strokes)
                FROM score_entries se
                JOIN scores s ON s.id = se.score_id
                JOIN rounds r ON r.id = s.round_id
                WHERE s.golfer_account_id = :account
                  AND r.course_id = :course
                  AND se.hole_number = :hole
                  AND se.strokes IS NOT NULL
                  AND s.deleted_at IS NULL
                  AND r.deleted_at IS NULL
                  AND r.status <> 'ABANDONED'
                """)
                .setParameter("account", accountId)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .getResultList();

        var summary = new LinkedHashMap<String, Object>();
        Object[] r = (Object[]) rows.get(0);
        int played = ((Number) r[0]).intValue();
        summary.put("timesPlayed", played);
        // Null rather than zero when the hole is new: "average 0.0" reads as a
        // score, and a golfer standing on a tee they have never played should
        // see nothing at all rather than a number that means nothing.
        summary.put("averageStrokes", played == 0 ? null
                : Math.round(((Number) r[1]).doubleValue() * 10) / 10.0);
        summary.put("bestStrokes", played == 0 ? null
                : ((Number) r[2]).intValue());
        return summary;
    }

    /**
     * Writes a note for this hole.
     *
     * @param roundId the round it was written during, or null between rounds
     */
    @Transactional
    public Map<String, Object> addNote(Long accountId, Long courseId,
                                       int holeNumber, String note,
                                       UUID roundId) {
        String trimmed = note == null ? "" : note.trim();
        if (trimmed.isEmpty()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "note",
                    Map.of("note", "a note cannot be empty"));
        }
        if (trimmed.length() > 2000) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "note",
                    Map.of("note", "a note is at most 2000 characters"));
        }

        Object id = em.createNativeQuery("""
                INSERT INTO hole_notes
                    (golfer_account_id, course_id, hole_number, note, round_id,
                     created_at, updated_at)
                VALUES (:account, :course, :hole, :note, :round, now(), now())
                RETURNING id
                """)
                .setParameter("account", accountId)
                .setParameter("course", courseId)
                .setParameter("hole", holeNumber)
                .setParameter("note", trimmed)
                .setParameter("round", roundId)
                .getSingleResult();

        return Map.of("id", ((Number) id).longValue(),
                "note", trimmed,
                "createdAt", LocalDate.now().toString());
    }

    /**
     * Removes one of this golfer's notes.
     *
     * <p>Scoped by account in the statement itself rather than checked first:
     * a note that is not theirs simply matches nothing, which is the same
     * answer as a note that does not exist and tells a prober no more.
     */
    @Transactional
    public boolean deleteNote(Long accountId, long noteId) {
        return em.createNativeQuery("""
                UPDATE hole_notes SET deleted_at = now(), updated_at = now()
                WHERE id = :id AND golfer_account_id = :account
                  AND deleted_at IS NULL
                """)
                .setParameter("id", noteId)
                .setParameter("account", accountId)
                .executeUpdate() > 0;
    }
}
