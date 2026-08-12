package vnpt.vsp.module.score.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.score.entity.ScoreEntry;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ScoreEntryRepository extends JpaRepository<ScoreEntry, UUID> {

    List<ScoreEntry> findByScoreIdOrderByHoleNumberAsc(UUID scoreId);

    Optional<ScoreEntry> findByScoreIdAndHoleNumber(UUID scoreId, Integer holeNumber);

    /**
     * Writes one hole's score, whether or not a row for it already exists.
     *
     * Read-then-insert cannot be made safe here. Two requests for the same hole
     * can be in flight together — the phone posts one per tap, and its queue
     * retries — and both read nothing before either writes. V39 makes
     * {@code (score_id, hole_number)} unique, so the loser of that race used to
     * fail on the insert, and catching that failure did not help: PostgreSQL
     * aborts the whole transaction on a constraint violation, so every
     * statement the recovery ran was rejected with 25P02 and the golfer's
     * request came back a 500.
     *
     * {@code ON CONFLICT DO UPDATE} settles it in one statement, so there is no
     * failure to recover from. Par is only written when the existing row has
     * none: it is course data the server resolves, and a later sync must not
     * overwrite a known par with a fallback. Putts, penalties and notes keep
     * their stored value when the update omits them, matching the sync
     * contract, while the flags are always taken from the newest word.
     */
    @Modifying
    @Query(value = """
            INSERT INTO score_entries (
                id, score_id, hole_number, par, strokes, putts, penalties,
                fairway_hit, gir, bunker, notes, created_at, updated_at)
            VALUES (
                gen_random_uuid(), :scoreId, :holeNumber, :par, :strokes,
                COALESCE(:putts, 0), COALESCE(:penalties, 0),
                :fairwayHit, :gir, :bunker, :notes, now(), now())
            ON CONFLICT (score_id, hole_number) DO UPDATE SET
                strokes     = EXCLUDED.strokes,
                par         = CASE WHEN score_entries.par IS NULL OR score_entries.par = 0
                                   THEN EXCLUDED.par ELSE score_entries.par END,
                putts       = COALESCE(:putts, score_entries.putts),
                penalties   = COALESCE(:penalties, score_entries.penalties),
                fairway_hit = EXCLUDED.fairway_hit,
                gir         = EXCLUDED.gir,
                bunker      = EXCLUDED.bunker,
                notes       = COALESCE(:notes, score_entries.notes),
                updated_at  = now()
            """, nativeQuery = true)
    void upsertHole(
            @Param("scoreId") UUID scoreId,
            @Param("holeNumber") Integer holeNumber,
            @Param("par") Integer par,
            @Param("strokes") Integer strokes,
            @Param("putts") Integer putts,
            @Param("penalties") Integer penalties,
            @Param("fairwayHit") Boolean fairwayHit,
            @Param("gir") Boolean gir,
            @Param("bunker") Boolean bunker,
            @Param("notes") String notes);
}
