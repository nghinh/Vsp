package vnpt.vsp.module.round;

import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.round.dto.GhostRoundResponse;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.UUID;

/**
 * The golfer's best completed round on a course, hole by hole — the ghost
 * the active round races.
 *
 * <p>Best against par rather than raw strokes, so nine- and eighteen-hole
 * rounds stand in one list, and only among rounds on the same course pairing:
 * a front nine at one club has nothing to say to a ghost who played another.
 *
 * <p>Null rather than an error when there is nothing to race — a golfer's
 * first round on a course has no ghost, and that is a fact, not a failure.
 */
@Service
public class GhostRoundService {

    private static final ZoneId VIETNAM = ZoneId.of("Asia/Ho_Chi_Minh");

    private final EntityManager em;

    public GhostRoundService(EntityManager em) {
        this.em = em;
    }

    @Transactional(readOnly = true)
    public GhostRoundResponse ghost(Long courseId, Long backNineCourseId, Long golferId) {
        var rows = em.createNativeQuery("""
                SELECT s.round_id, sum(e.strokes), sum(e.par), min(r.started_at)
                FROM scores s
                JOIN score_entries e ON e.score_id = s.id
                JOIN rounds r ON r.id = s.round_id
                WHERE s.golfer_account_id = :golfer AND s.deleted_at IS NULL
                  AND r.deleted_at IS NULL AND r.status = 'COMPLETED'
                  AND r.course_id = :course
                  AND coalesce(r.back_nine_course_id, -1) = coalesce(CAST(:backNine AS bigint), -1)
                GROUP BY s.round_id
                HAVING count(*) IN (9, 18)
                ORDER BY sum(e.strokes - e.par), min(r.started_at)
                LIMIT 1
                """)
                .setParameter("golfer", golferId)
                .setParameter("course", courseId)
                .setParameter("backNine", backNineCourseId)
                .getResultList();
        if (rows.isEmpty()) {
            return null;
        }
        Object[] r = (Object[]) rows.get(0);
        UUID roundId = (UUID) r[0];
        int strokes = ((Number) r[1]).intValue();
        int par = ((Number) r[2]).intValue();
        LocalDate playedOn = instant(r[3]).atZone(VIETNAM).toLocalDate();

        var holes = new ArrayList<GhostRoundResponse.GhostHole>();
        for (Object row : em.createNativeQuery("""
                SELECT e.hole_number, e.strokes, e.par
                FROM score_entries e
                JOIN scores s ON s.id = e.score_id
                WHERE s.round_id = :round AND s.golfer_account_id = :golfer
                  AND s.deleted_at IS NULL
                ORDER BY e.hole_number
                """)
                .setParameter("round", roundId)
                .setParameter("golfer", golferId)
                .getResultList()) {
            Object[] h = (Object[]) row;
            holes.add(new GhostRoundResponse.GhostHole(
                    ((Number) h[0]).intValue(),
                    ((Number) h[1]).intValue(),
                    ((Number) h[2]).intValue()));
        }
        return new GhostRoundResponse(roundId, playedOn, strokes, par, holes);
    }

    private static Instant instant(Object ts) {
        return ts instanceof Instant i ? i
                : ts instanceof java.time.OffsetDateTime o ? o.toInstant()
                : ((java.sql.Timestamp) ts).toInstant();
    }
}
