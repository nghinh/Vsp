package vnpt.vsp.module.correction;

import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.correction.dto.ContributorResponse;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

/**
 * Who filled in the country's scorecards.
 *
 * <p>Every stroke index in this database arrived because somebody
 * photographed a card in a clubhouse and typed it in. No open dataset carries
 * them; the scrapers get pars wrong and indexes not at all. The people who
 * did that work are the reason stroke allocation, net scoring and the games
 * engine exist at all, and until now nothing anywhere said their names.
 *
 * <p>Only approved corrections count. A submission queue is not a
 * contribution — it becomes one when a reviewer agrees it matches the card —
 * and counting pending rows would reward volume over accuracy, which is the
 * wrong thing to reward in a dataset whose whole value is being right.
 *
 * <p>Display names only. The account behind a contribution has a phone number
 * and an email on it, and neither belongs on a leaderboard.
 */
@Service
public class ContributorService {

    private static final ZoneId VIETNAM = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final int LEADERBOARD_SIZE = 50;

    private final EntityManager em;

    public ContributorService(EntityManager em) {
        this.em = em;
    }

    /// The people with the most approved corrections, most first.
    @Transactional(readOnly = true)
    public List<ContributorResponse> leaderboard() {
        return read(em.createNativeQuery("""
                SELECT a.display_name, count(*), count(DISTINCT c.course_id), max(c.reviewed_at)
                FROM course_corrections c
                JOIN golfer_accounts a ON a.id = c.reporter_id
                WHERE c.status = 'APPROVED'
                GROUP BY a.id, a.display_name
                ORDER BY count(*) DESC, max(c.reviewed_at) DESC
                LIMIT :limit
                """).setParameter("limit", LEADERBOARD_SIZE).getResultList());
    }

    /// The people who filled in this particular course.
    ///
    /// Shown on the course itself, which is where the credit means something:
    /// the golfer reading the card is holding the work.
    @Transactional(readOnly = true)
    public List<ContributorResponse> forCourse(Long courseId) {
        return read(em.createNativeQuery("""
                SELECT a.display_name, count(*), count(DISTINCT c.course_id), max(c.reviewed_at)
                FROM course_corrections c
                JOIN golfer_accounts a ON a.id = c.reporter_id
                WHERE c.status = 'APPROVED' AND c.course_id = :course
                GROUP BY a.id, a.display_name
                ORDER BY count(*) DESC, max(c.reviewed_at) DESC
                """).setParameter("course", courseId).getResultList());
    }

    private List<ContributorResponse> read(List<?> rows) {
        var contributors = new ArrayList<ContributorResponse>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            contributors.add(new ContributorResponse(
                    (String) r[0],
                    ((Number) r[1]).intValue(),
                    ((Number) r[2]).intValue(),
                    date(r[3])));
        }
        return contributors;
    }

    private static LocalDate date(Object ts) {
        if (ts == null) {
            return null;
        }
        Instant instant = ts instanceof Instant i ? i
                : ts instanceof java.time.OffsetDateTime o ? o.toInstant()
                : ((java.sql.Timestamp) ts).toInstant();
        return instant.atZone(VIETNAM).toLocalDate();
    }
}
