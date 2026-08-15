package vnpt.vsp.api.course;

import jakarta.persistence.EntityManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Where the flag is today, for the golfer walking up to the green.
 *
 * <p>The greenkeeper has been able to publish pins from the portal since the
 * operations module landed, and the data has been sitting in
 * {@code pin_positions_ops} ever since — reachable only through
 * {@code /admin/courses/.../pins}, which a golfer's token cannot open. So the
 * one person the pin actually matters to could not see it. This is the read
 * side of that table, and nothing more.
 *
 * <p>Coordinates come out already decoded. The stored geometry is WKB, the
 * portal needed its own decoder to read it, and the mobile app has none —
 * sending latitude and longitude keeps that problem on the server, which is
 * the side that already has PostGIS.
 *
 * <p>Only pins whose window covers this instant. An expired pin is worse than
 * no pin: a golfer aiming at last week's flag walks confidently to the wrong
 * half of the green.
 */
@RestController
public class CoursePinController {

    private final EntityManager em;

    public CoursePinController(EntityManager em) {
        this.em = em;
    }

    @GetMapping("/courses/{courseId}/pins")
    @Transactional(readOnly = true)
    public List<CoursePin> pins(@PathVariable Long courseId) {
        var rows = em.createNativeQuery("""
                SELECT h.hole_number,
                       ST_Y(p.location), ST_X(p.location),
                       p.pin_position_type, p.confidence, p.expires_at
                FROM pin_positions_ops p
                JOIN holes h ON h.id = p.hole_id
                WHERE h.course_id = :course
                  AND p.effective_from <= now()
                  AND (p.expires_at IS NULL OR p.expires_at > now())
                ORDER BY h.hole_number, p.effective_from DESC
                """).setParameter("course", courseId).getResultList();

        var pins = new ArrayList<CoursePin>();
        var seen = new java.util.HashSet<Integer>();
        for (Object row : rows) {
            Object[] r = (Object[]) row;
            int hole = ((Number) r[0]).intValue();
            // One flag per hole: the most recently effective wins, which is
            // what the ORDER BY above puts first.
            if (!seen.add(hole)) {
                continue;
            }
            pins.add(new CoursePin(
                    hole,
                    ((Number) r[1]).doubleValue(),
                    ((Number) r[2]).doubleValue(),
                    (String) r[3],
                    (BigDecimal) r[4],
                    r[5] == null ? null : instant(r[5])));
        }
        return pins;
    }

    private static Instant instant(Object ts) {
        return ts instanceof Instant i ? i
                : ts instanceof java.time.OffsetDateTime o ? o.toInstant()
                : ((java.sql.Timestamp) ts).toInstant();
    }

    /**
     * One flag, as the golfer needs it.
     *
     * @param expiresAt when the greenkeeper says this placement stops being
     *                  true — surfaced so the app can stop drawing it rather
     *                  than show a stale flag as a current one
     */
    public record CoursePin(
            int holeNumber,
            double latitude,
            double longitude,
            String type,
            BigDecimal confidence,
            Instant expiresAt) {}
}
