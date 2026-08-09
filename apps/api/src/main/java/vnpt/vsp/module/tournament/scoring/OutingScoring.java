package vnpt.vsp.module.tournament.scoring;

import vnpt.vsp.module.tournament.scoring.OutingRules.Division;
import vnpt.vsp.module.tournament.scoring.OutingRules.TechnicalKind;
import vnpt.vsp.module.tournament.scoring.OutingRules.TechnicalPrizeSpec;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * The outing's prize rules, applied.
 *
 * Every number this needs comes from {@link OutingRules}; nothing about a
 * particular club is written down here. What lives here is the *shape* of the
 * rules — that a net score is gross minus handicap, that a countback compares
 * the tail of a round, that a prize skips a player who already has one — and
 * those are the parts that do not change between outings.
 *
 * It matters that this is separable and testable. The results are computed once
 * in a club house, minutes before they are read out; a wrong winner is not a
 * bug that shows up in staging.
 */
public final class OutingScoring {

    private final OutingRules rules;

    public OutingScoring(OutingRules rules) {
        if (rules == null) throw new IllegalArgumentException("rules are required");
        this.rules = rules;
    }

    public OutingRules rules() {
        return rules;
    }

    // ─── Input ──────────────────────────────────────────────────────────────

    /**
     * One player's card.
     *
     * {@code holeScores} may be null or partly zero: on the day the totals
     * arrive before the hole detail does, and a leaderboard that waits for all
     * eighteen numbers from all forty-four players is a leaderboard nobody
     * sees. Where the holes are absent, {@code grossTotal} carries the round
     * and the countback cannot run for that player — {@link Ranked#countbackAvailable()}
     * says so rather than inventing zeros, which would rank an unfinished card
     * first.
     */
    public record Card(
            String playerRef,
            String displayName,
            String divisionCode,
            int playingHandicap,
            Integer grossTotal,
            int[] holeScores,
            /** Reported birdies, used only when the holes are absent. */
            Integer reportedBirdies,
            /** Reported eagles, used only when the holes are absent. */
            Integer reportedEagles) {}

    /** A measured technical-prize entry — metres to the pin, or metres driven. */
    public record TechnicalEntry(String playerRef, int holeNumber, double measurement) {}

    // ─── Output ─────────────────────────────────────────────────────────────

    /** A player's place in their division. */
    public record Ranked(
            Card card,
            Integer gross,
            Integer net,
            Integer judgingScore,
            int rank,
            /** The division's prize title for this rank, or null outside the prizes. */
            String prizeTitle,
            boolean countbackAvailable,
            boolean tiedAndUnresolved,
            Integer dailyCapAdjustment,
            int birdies,
            int eagles) {}

    /** A technical prize that found a winner. */
    public record TechnicalAward(
            String prizeCode,
            String prizeLabel,
            int holeNumber,
            String playerRef,
            double measurement,
            String unit) {}

    /** Everything the prize table needs, computed together. */
    public record Results(
            Map<String, List<Ranked>> byDivision,
            List<TechnicalAward> technicalAwards) {}

    // ─── Per-card arithmetic ────────────────────────────────────────────────

    /** True when every hole of the round carries a score. */
    public boolean hasEveryHole(Card card) {
        if (card.holeScores() == null || card.holeScores().length != rules.holeCount()) return false;
        for (int s : card.holeScores()) {
            if (s <= 0) return false;
        }
        return true;
    }

    /** The round's gross: the holes when they are all in, otherwise the entered total. */
    public Integer gross(Card card) {
        if (hasEveryHole(card)) {
            int sum = 0;
            for (int s : card.holeScores()) sum += s;
            return sum;
        }
        return card.grossTotal();
    }

    /** Gross minus playing handicap. Null while the round has no gross. */
    public Integer net(Card card) {
        Integer gross = gross(card);
        return gross == null ? null : gross - card.playingHandicap();
    }

    /**
     * The number a prize is judged on: net relative to par, floored.
     *
     * Negative is good, and {@link OutingRules#judgingFloor()} is as good as a
     * player is allowed to be counted.
     */
    public Integer judgingScore(Card card) {
        Integer net = net(card);
        if (net == null) return null;
        int diff = net - rules.coursePar();
        Integer floor = rules.judgingFloor();
        return floor == null ? diff : Math.max(diff, floor);
    }

    /**
     * The last {@code holes} holes of a round, summed.
     *
     * Null when any of them is missing — a partial window cannot be compared
     * against a complete one.
     */
    public Integer countback(Card card, int holes) {
        int[] scores = card.holeScores();
        if (scores == null || scores.length != rules.holeCount()) return null;
        int sum = 0;
        for (int i = rules.holeCount() - holes; i < rules.holeCount(); i++) {
            if (scores[i] <= 0) return null;
            sum += scores[i];
        }
        return sum;
    }

    /**
     * The day's handicap adjustment, on the club's configured scale.
     *
     * Each hole's strokes over par is looked up in {@link OutingRules#dailyCapBands()}
     * and the adjustments are summed. A hole whose result falls in no band
     * contributes nothing, which is the only safe reading of a gap.
     */
    public Integer dailyCapAdjustment(Card card) {
        if (!hasEveryHole(card)) return null;

        int total = 0;
        for (int i = 0; i < rules.holeCount(); i++) {
            int overPar = card.holeScores()[i] - rules.holePars()[i];
            total += rules.dailyCapBands().stream()
                    .filter(b -> b.contains(overPar))
                    .findFirst()
                    .map(OutingRules.CapBand::adjustment)
                    .orElse(0);
        }
        return total;
    }

    /**
     * Holes played exactly one under par.
     *
     * Counted from the card where the holes are there. Where they are not —
     * the fast path, where a round is one number — there is nothing to count,
     * so the figure the flight reported is used instead. A partly filled card
     * falls back too: counting the birdies in the six holes somebody happened
     * to type would understate the round.
     */
    public int birdies(Card card) {
        if (hasEveryHole(card)) return countHoles(card, d -> d == -1);
        return card.reportedBirdies() == null ? 0 : Math.max(card.reportedBirdies(), 0);
    }

    /** Holes played two or more under par. Same fallback as {@link #birdies}. */
    public int eagles(Card card) {
        if (hasEveryHole(card)) return countHoles(card, d -> d <= -2);
        return card.reportedEagles() == null ? 0 : Math.max(card.reportedEagles(), 0);
    }

    private int countHoles(Card card, java.util.function.IntPredicate overPar) {
        int[] scores = card.holeScores();
        if (scores == null || scores.length != rules.holeCount()) return 0;
        int n = 0;
        for (int i = 0; i < rules.holeCount(); i++) {
            if (scores[i] > 0 && overPar.test(scores[i] - rules.holePars()[i])) n++;
        }
        return n;
    }

    // ─── Ranking ────────────────────────────────────────────────────────────

    /**
     * Rank one division, applying the tie-breaks in the configured order.
     *
     * A player with no gross yet sorts last and keeps a place, so the board can
     * show the flights still out rather than hiding them.
     */
    public List<Ranked> rankDivision(String divisionCode, List<Card> cards) {
        Division division = rules.division(divisionCode);
        List<String> prizeTitles = division == null ? List.of() : division.prizeTitles();

        List<Card> sorted = new ArrayList<>(cards);
        sorted.sort(order());

        List<Ranked> out = new ArrayList<>(sorted.size());
        for (int i = 0; i < sorted.size(); i++) {
            Card c = sorted.get(i);

            // Tied means every configured tie-break came out level: the pair is
            // genuinely inseparable and the BTC has to choose. Saying so is the
            // point — ordering them by whoever was imported first would hand
            // out a prize on an accident of spreadsheet row order.
            boolean tiedAbove = i > 0 && order().compare(sorted.get(i - 1), c) == 0;
            boolean tiedBelow = i < sorted.size() - 1 && order().compare(c, sorted.get(i + 1)) == 0;

            // No prize for a card with no score, whatever rank the sort gave it.
            String title = (gross(c) != null && i < prizeTitles.size()) ? prizeTitles.get(i) : null;

            out.add(new Ranked(
                    c,
                    gross(c),
                    net(c),
                    judgingScore(c),
                    i + 1,
                    title,
                    hasEveryHole(c),
                    tiedAbove || tiedBelow,
                    dailyCapAdjustment(c),
                    birdies(c),
                    eagles(c)));
        }
        return out;
    }

    /**
     * Judging score, then handicap, then each countback window in turn.
     *
     * "Trường hợp golfer có cùng tổng gậy thì golfer có HDC thấp hơn sẽ thắng.
     * Trường hợp tổng điểm và HDC bằng nhau, áp dụng cách tính Đếm ngược."
     */
    private Comparator<Card> order() {
        Comparator<Card> c = Comparator
                .comparing(this::judgingScore, nullsLast())
                .thenComparingInt(Card::playingHandicap);
        for (int window : rules.countbackWindows()) {
            final int w = window;
            c = c.thenComparing(card -> countback(card, w), nullsLast());
        }
        return c;
    }

    /** Lower is better, and a missing value sorts last rather than first. */
    private static Comparator<Integer> nullsLast() {
        return Comparator.nullsLast(Comparator.naturalOrder());
    }

    // ─── Technical prizes ───────────────────────────────────────────────────

    /**
     * Award one technical prize's holes.
     *
     * "BTC sẽ chọn 4 golfer có thành tích tốt nhất ở 4 hố par 3 và par 5, xét
     * theo hố trước và chưa nhận giải khác" — so this walks the prize's holes
     * in the configured order and, at each one, awards to the best measurement
     * among players who have not already won something. A player who tops two
     * holes takes the earlier one and the later hole passes to the next best.
     *
     * @param alreadyAwarded players already holding a prize. Pass the division
     *                       winners in first: the rules put group prizes ahead
     *                       of technical ones. Ignored entirely when
     *                       {@link OutingRules#onePrizePerPlayer()} is false.
     */
    public List<TechnicalAward> allocate(
            TechnicalPrizeSpec spec,
            List<TechnicalEntry> entries,
            Set<String> alreadyAwarded) {

        Set<String> taken = rules.onePrizePerPlayer()
                ? new LinkedHashSet<>(alreadyAwarded)
                : new LinkedHashSet<>();

        Map<Integer, List<TechnicalEntry>> byHole = new LinkedHashMap<>();
        for (int hole : spec.holes()) {
            byHole.put(hole, new ArrayList<>());
        }
        for (TechnicalEntry e : entries) {
            List<TechnicalEntry> onHole = byHole.get(e.holeNumber());
            // An entry on a hole this prize is not played for is not an error
            // worth failing the whole prize table over; it just does not count.
            if (onHole != null) onHole.add(e);
        }

        Comparator<TechnicalEntry> best = spec.kind() == TechnicalKind.NEAREST_TO_PIN
                ? Comparator.comparingDouble(TechnicalEntry::measurement)
                : Comparator.comparingDouble(TechnicalEntry::measurement).reversed();

        List<TechnicalAward> awards = new ArrayList<>();
        for (Map.Entry<Integer, List<TechnicalEntry>> hole : byHole.entrySet()) {
            hole.getValue().stream()
                    .filter(e -> !taken.contains(e.playerRef()))
                    .min(best)
                    .ifPresent(winner -> {
                        if (rules.onePrizePerPlayer()) taken.add(winner.playerRef());
                        awards.add(new TechnicalAward(
                                spec.code(), spec.label(), hole.getKey(),
                                winner.playerRef(), winner.measurement(), spec.unit()));
                    });
        }
        return awards;
    }

    // ─── The whole prize table ──────────────────────────────────────────────

    /**
     * Rank every division and award every technical prize, in the right order.
     *
     * The order is itself a rule: "BTC ưu tiên trao giải cho cá nhân đạt thành
     * tích tại mục I (Giải CLB) trước", so the division winners are settled
     * first and are then excluded from the technical prizes.
     */
    public Results compute(List<Card> cards, List<TechnicalEntry> technicalEntries) {
        Map<String, List<Ranked>> byDivision = new LinkedHashMap<>();
        Set<String> awarded = new LinkedHashSet<>();

        for (Division division : rules.divisions()) {
            List<Card> inDivision = cards.stream()
                    .filter(c -> division.code().equalsIgnoreCase(c.divisionCode()))
                    .toList();

            List<Ranked> ranked = rankDivision(division.code(), inDivision);
            byDivision.put(division.code(), ranked);

            ranked.stream()
                    .filter(r -> r.prizeTitle() != null)
                    .forEach(r -> awarded.add(r.card().playerRef()));
        }

        List<TechnicalAward> technical = new ArrayList<>();
        for (TechnicalPrizeSpec spec : rules.technicalPrizes()) {
            List<TechnicalAward> forSpec = allocate(spec, technicalEntries, awarded);
            technical.addAll(forSpec);
            forSpec.forEach(a -> awarded.add(a.playerRef()));
        }

        return new Results(byDivision, technical);
    }
}
