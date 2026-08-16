package vnpt.vsp.module.round;

import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Clearing away rounds nobody played.
 *
 * <p>Sixteen of the seventeen rounds sitting in progress on this database had
 * no strokes at all. They are what a golfer leaves behind when they open the
 * setup screen, tap start to see what happens, and go back — the round is
 * created the moment they tap, because a round has to exist before a score can
 * be attached to it, and nothing ever closes it again.
 *
 * <p>The cost is not storage. It is that "Đang chơi" fills with rounds nobody
 * is playing, the app's resume-a-round prompt offers the wrong one, and the
 * handicap engine has to filter them out of every calculation.
 *
 * <h2>Why a sweep rather than not creating the round</h2>
 *
 * <p>The obvious fix — do not write the round until the first score — is the
 * one this deliberately does not do. Nothing in the app drains its round sync
 * queue back into the API today: the round is created eagerly precisely so
 * that a score entered a minute later has somewhere to go. Deferring it would
 * trade a tidy table for lost scores, which is the wrong way round.
 *
 * <p>So the round is still created, and one that turns out to hold nothing is
 * closed after a grace period long enough to cover a real round: a golfer who
 * tees off and does not write a score down for three hours is rare, and one
 * who abandons at the first tee is not.
 */
@Component
public class EmptyRoundSweep {

    private static final Logger log = LoggerFactory.getLogger(EmptyRoundSweep.class);

    private final EntityManager em;
    private final int graceHours;

    public EmptyRoundSweep(EntityManager em,
                           @Value("${vsp.rounds.empty-grace-hours:6}") int graceHours) {
        this.em = em;
        this.graceHours = graceHours;
    }

    /// Hourly, after a delay long enough that a restart does not sweep during
    /// startup while the connection pool is still filling.
    @Scheduled(initialDelay = 2 * 60_000, fixedDelay = 60 * 60_000)
    @Transactional
    public void sweep() {
        int closed = em.createNativeQuery("""
                UPDATE rounds r
                SET status = 'ABANDONED', updated_at = now()
                WHERE r.status = 'IN_PROGRESS'
                  AND r.created_at < now() - make_interval(hours => :grace)
                  AND NOT EXISTS (
                        SELECT 1 FROM score_entries se
                        JOIN scores s ON s.id = se.score_id
                        WHERE s.round_id = r.id AND se.strokes IS NOT NULL)
                """)
                .setParameter("grace", graceHours)
                .executeUpdate();

        if (closed > 0) {
            log.info("Closed {} in-progress round(s) with no strokes, older than {}h",
                    closed, graceHours);
        }
    }
}
