package vnpt.vsp.module.profile;

import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.profile.dto.PerformanceResponse;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;

/**
 * What a golfer's own rounds say about them.
 *
 * <p>Counted, never modelled. Every figure traces to score entries this
 * golfer wrote down, and a figure with no rows behind it comes back null so
 * the screen can show a dash rather than a confident zero. "0% greens in
 * regulation" and "nobody has ever ticked the GIR box" look identical on a
 * tile and mean opposite things.
 *
 * <p>Only completed, undeleted rounds — the same window the handicap uses,
 * minus the practice filter: a golfer looking at their own statistics wants
 * to see the practice rounds they played, even though those rounds do not
 * move their handicap.
 */
@Service
public class PerformanceService {

    /// Windows the app offers: everything, the last twenty, the last five.
    private static final int ALL = 10_000;

    private final EntityManager em;
    private final AppHandicapService appHandicapService;

    public PerformanceService(EntityManager em, AppHandicapService appHandicapService) {
        this.em = em;
        this.appHandicapService = appHandicapService;
    }

    @Transactional(readOnly = true)
    public PerformanceResponse compute(Long golferId, Integer window) {
        int limit = window == null || window <= 0 ? ALL : window;

        Object[] totals = (Object[]) em.createNativeQuery("""
                WITH window_scores AS (
                    SELECT sc.id
                    FROM scores sc
                    JOIN rounds r ON r.id = sc.round_id
                    WHERE sc.golfer_account_id = :golfer
                      AND sc.deleted_at IS NULL
                      AND r.deleted_at IS NULL
                      AND r.status = 'COMPLETED'
                    ORDER BY r.created_at DESC
                    LIMIT :limit
                )
                SELECT count(DISTINCT e.score_id),
                       count(*),
                       coalesce(sum(e.strokes) - sum(e.par), 0),
                       sum(e.putts) FILTER (WHERE e.putts IS NOT NULL AND e.putts > 0),
                       count(*) FILTER (WHERE e.putts IS NOT NULL AND e.putts > 0),
                       count(*) FILTER (WHERE e.gir),
                       count(*) FILTER (WHERE e.gir IS NOT NULL),
                       count(*) FILTER (WHERE e.fairway_hit),
                       count(*) FILTER (WHERE e.fairway_hit IS NOT NULL),
                       coalesce(sum(e.penalties), 0),
                       count(*) FILTER (WHERE e.strokes <= e.par - 2),
                       count(*) FILTER (WHERE e.strokes = e.par - 1),
                       count(*) FILTER (WHERE e.strokes = e.par),
                       count(*) FILTER (WHERE e.strokes = e.par + 1),
                       count(*) FILTER (WHERE e.strokes = e.par + 2),
                       count(*) FILTER (WHERE e.strokes >= e.par + 3)
                FROM score_entries e
                JOIN window_scores w ON w.id = e.score_id
                """)
                .setParameter("golfer", golferId)
                .setParameter("limit", limit)
                .getSingleResult();

        int rounds = num(totals[0]);
        int holes = num(totals[1]);
        int overPar = num(totals[2]);
        Integer putts = totals[3] == null ? null : num(totals[3]);
        int holesWithPutts = num(totals[4]);
        int girs = num(totals[5]);
        int holesWithGir = num(totals[6]);
        int fairways = num(totals[7]);
        int holesWithFairway = num(totals[8]);
        int penalties = num(totals[9]);

        BestRound best = bestRound(golferId, limit);

        var distribution = new ArrayList<PerformanceResponse.ScoreBucket>();
        String[] labels = {"EAGLE_OR_BETTER", "BIRDIE", "PAR", "BOGEY",
                "DOUBLE_BOGEY", "TRIPLE_OR_WORSE"};
        for (int i = 0; i < labels.length; i++) {
            int count = num(totals[10 + i]);
            distribution.add(new PerformanceResponse.ScoreBucket(
                    labels[i], count, percent(count, holes)));
        }

        return new PerformanceResponse(
                rounds, holes,
                appHandicapService.compute(golferId).handicap(),
                best.toPar(), best.holes(),
                holes == 0 ? null : ratio(overPar, holes),
                putts == null || holesWithPutts == 0 ? null : ratio(putts, holesWithPutts),
                holesWithPutts,
                percentOrNull(girs, holesWithGir), holesWithGir,
                percentOrNull(fairways, holesWithFairway), holesWithFairway,
                rounds == 0 ? null : ratio(penalties, rounds),
                distribution,
                byPar(golferId, limit));
    }

    /// The best round and the size of card it was played on. A record
    /// rather than a field: this service is a singleton, and two golfers
    /// asking at once would otherwise read each other's answer.
    private record BestRound(Integer toPar, Integer holes) {}

    /**
     * The best round in the window against par.
     *
     * <p>Only rounds with a full nine or eighteen of entries: a round
     * abandoned on the 4th is +2 and is not anybody's best round.
     */
    private BestRound bestRound(Long golferId, int limit) {
        var rows = em.createNativeQuery("""
                WITH window_scores AS (
                    SELECT sc.id
                    FROM scores sc
                    JOIN rounds r ON r.id = sc.round_id
                    WHERE sc.golfer_account_id = :golfer
                      AND sc.deleted_at IS NULL
                      AND r.deleted_at IS NULL
                      AND r.status = 'COMPLETED'
                    ORDER BY r.created_at DESC
                    LIMIT :limit
                )
                SELECT sum(e.strokes) - sum(e.par) AS to_par, count(*) AS holes
                FROM score_entries e
                JOIN window_scores w ON w.id = e.score_id
                GROUP BY e.score_id
                HAVING count(*) IN (9, 18)
                ORDER BY sum(e.strokes) - sum(e.par), count(*) DESC
                LIMIT 1
                """)
                .setParameter("golfer", golferId)
                .setParameter("limit", limit)
                .getResultList();
        if (rows.isEmpty()) {
            return new BestRound(null, null);
        }
        Object[] r = (Object[]) rows.get(0);
        return new BestRound(num(r[0]), num(r[1]));
    }

    private List<PerformanceResponse.ParAverage> byPar(Long golferId, int limit) {
        var averages = new ArrayList<PerformanceResponse.ParAverage>();
        for (Object row : em.createNativeQuery("""
                WITH window_scores AS (
                    SELECT sc.id
                    FROM scores sc
                    JOIN rounds r ON r.id = sc.round_id
                    WHERE sc.golfer_account_id = :golfer
                      AND sc.deleted_at IS NULL
                      AND r.deleted_at IS NULL
                      AND r.status = 'COMPLETED'
                    ORDER BY r.created_at DESC
                    LIMIT :limit
                )
                SELECT e.par, count(*), avg(e.strokes), min(e.strokes), max(e.strokes)
                FROM score_entries e
                JOIN window_scores w ON w.id = e.score_id
                GROUP BY e.par
                ORDER BY e.par
                """)
                .setParameter("golfer", golferId)
                .setParameter("limit", limit)
                .getResultList()) {
            Object[] r = (Object[]) row;
            averages.add(new PerformanceResponse.ParAverage(
                    num(r[0]), num(r[1]),
                    BigDecimal.valueOf(((Number) r[2]).doubleValue())
                            .setScale(1, RoundingMode.HALF_UP),
                    num(r[3]), num(r[4])));
        }
        return averages;
    }

    // ─── Arithmetic, kept honest about empty ────────────────────────────────

    private static int num(Object value) {
        return ((Number) value).intValue();
    }

    private static BigDecimal ratio(int numerator, int denominator) {
        return BigDecimal.valueOf(numerator)
                .divide(BigDecimal.valueOf(denominator), 2, RoundingMode.HALF_UP);
    }

    private static BigDecimal percent(int part, int whole) {
        return whole == 0 ? BigDecimal.ZERO
                : BigDecimal.valueOf(part * 100.0 / whole).setScale(0, RoundingMode.HALF_UP);
    }

    /// Null rather than zero where nothing was ever recorded. A golfer who
    /// has never ticked the GIR box has not hit 0% of greens.
    private static BigDecimal percentOrNull(int part, int whole) {
        return whole == 0 ? null : percent(part, whole);
    }
}
