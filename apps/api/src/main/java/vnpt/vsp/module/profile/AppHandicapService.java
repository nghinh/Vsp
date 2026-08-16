package vnpt.vsp.module.profile;

import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;

/**
 * A handicap computed from the rounds this app has actually seen.
 *
 * <p>Most Vietnamese golfers hold no VGA handicap — both accounts on this very
 * deployment have none — and without one the two features that need a handicap
 * fall silent: stroke allocation in the hole advice, and giving strokes in a
 * game. A flight then negotiates numbers on the first tee from memory, which
 * is exactly the argument a handicap exists to end.
 *
 * <h2>What this is and is not</h2>
 *
 * <p>It is a <em>society handicap</em>: the average of the best differentials
 * over recent rounds, scaled to eighteen holes. It is deliberately not the
 * World Handicap System — WHS needs course rating and slope on every round,
 * and most of this country's tees carry no rating yet. Where the profile holds
 * a real handicap, that always wins; this fills the silence, and says on the
 * response what it was computed from.
 */
@Service
public class AppHandicapService {

    /// Fewer rounds than this is a guess, not a handicap.
    static final int MIN_ROUNDS = 3;

    /// The window and the cut, WHS-shaped: best 8 of the last 20.
    static final int WINDOW = 20;
    static final int BEST = 8;

    private final EntityManager em;

    public AppHandicapService(EntityManager em) {
        this.em = em;
    }

    public record AppHandicap(BigDecimal handicap, int roundsCounted) {}

    /**
     * The best-差 average, or null while there are not enough rounds.
     *
     * <p>A differential is the round's strokes over par, a nine scaled to an
     * eighteen. Only rounds with a full nine or eighteen of entries count — a
     * round abandoned on the 5th says nothing about ability.
     *
     * <p>And only rounds that are finished, undeleted, and marked as
     * counting. All three were missing: an abandoned round with nine holes
     * entered, a round the golfer deleted, and every round played as practice
     * all moved this number. The golfer was offered a "Tập luyện" choice on
     * the setup screen and it changed nothing — there was no column behind
     * it, so there was nothing to filter on.
     */
    @Transactional(readOnly = true)
    public AppHandicap compute(Long golferAccountId) {
        @SuppressWarnings("unchecked")
        List<Object[]> rows = em.createNativeQuery("""
                SELECT count(*) AS holes,
                       sum(e.strokes) - sum(e.par) AS over_par
                FROM scores sc
                JOIN score_entries e ON e.score_id = sc.id
                JOIN rounds r ON r.id = sc.round_id
                WHERE sc.golfer_account_id = :golfer
                  AND sc.deleted_at IS NULL
                  AND r.deleted_at IS NULL
                  AND r.status = 'COMPLETED'
                  AND r.counts_toward_handicap
                GROUP BY sc.id, r.created_at
                HAVING count(*) IN (9, 18)
                ORDER BY r.created_at DESC
                LIMIT :window
                """)
                .setParameter("golfer", golferAccountId)
                .setParameter("window", WINDOW)
                .getResultList();

        List<Double> differentials = new ArrayList<>();
        for (Object[] r : rows) {
            int holes = ((Number) r[0]).intValue();
            double overPar = ((Number) r[1]).doubleValue();
            differentials.add(holes == 9 ? overPar * 2 : overPar);
        }
        BigDecimal handicap = fromDifferentials(differentials);
        return new AppHandicap(handicap, differentials.size());
    }

    /**
     * Pure arithmetic, separated so the test can hold it still.
     *
     * <p>Best {@link #BEST} of what there is, averaged, floored at zero — a
     * society handicap does not go plus, because "plus" claims better than
     * scratch and this data cannot support that claim.
     */
    static BigDecimal fromDifferentials(List<Double> differentials) {
        if (differentials.size() < MIN_ROUNDS) {
            return null;
        }
        List<Double> sorted = new ArrayList<>(differentials);
        sorted.sort(Double::compare);
        int take = Math.min(BEST, sorted.size());
        double sum = 0;
        for (int i = 0; i < take; i++) {
            sum += sorted.get(i);
        }
        double average = Math.max(0, sum / take);
        return BigDecimal.valueOf(average).setScale(1, RoundingMode.HALF_UP);
    }
}
