package vnpt.vsp.module.tournament.scoring;

import java.util.ArrayList;
import java.util.List;

/**
 * One outing's rules, as data.
 *
 * Every number the "Thể lệ thi đấu" sheet states lives here rather than in the
 * scoring code: the division boundaries, the handicap cap, how far under a
 * handicap counts, which windows the countback uses, the daily-CAP scale, how
 * many prizes each division gets, which holes carry a technical prize, and
 * whether a golfer may hold more than one.
 *
 * They belong here because they change. The club's own two sheets already
 * disagree — the rules page writes "Nhóm A: HDC từ 0 đến 25" while the flight
 * sheet's footer says "A: 0-26" — and the outing before this one ran seven
 * flights instead of eleven. A rule compiled into a comparator is a rule that
 * needs a release when the club changes its mind in the week before an event.
 *
 * {@link #vnptItSpringOuting2026()} is the 19/04/2026 sheet transcribed. It is
 * a starting point to copy and edit, not a default anybody is stuck with.
 */
public record OutingRules(
        /** Par for each hole, in play order. Length fixes the round. */
        int[] holePars,
        /** Divisions, in the order they should be presented. */
        List<Division> divisions,
        /** Handicaps above the threshold play off the capped value. Null to not cap. */
        HandicapCap handicapCap,
        /**
         * The best a player may be judged relative to their handicap, or null
         * for no floor. Negative: −3 means "cắt đến âm 3".
         */
        Integer judgingFloor,
        /**
         * Countback windows, in the order they are tried — each is a count of
         * holes taken from the end of the round. The sheet gives 9, 6, 3, 1.
         */
        List<Integer> countbackWindows,
        /** The daily-CAP scale, as bands over par. */
        List<CapBand> dailyCapBands,
        /** Technical prizes and the holes they are contested on. */
        List<TechnicalPrizeSpec> technicalPrizes,
        /** "Mỗi Golfer nhận tối đa 01 giải". False lets a golfer hold several. */
        boolean onePrizePerPlayer) {

    public OutingRules {
        if (holePars == null || holePars.length == 0) {
            throw new IllegalArgumentException("holePars is required");
        }
        if (divisions == null || divisions.isEmpty()) {
            throw new IllegalArgumentException("at least one division is required");
        }
        if (countbackWindows == null) countbackWindows = List.of();
        if (dailyCapBands == null) dailyCapBands = List.of();
        if (technicalPrizes == null) technicalPrizes = List.of();

        for (int w : countbackWindows) {
            if (w < 1 || w > holePars.length) {
                throw new IllegalArgumentException(
                        "countback window " + w + " does not fit a " + holePars.length + "-hole round");
            }
        }
        for (TechnicalPrizeSpec spec : technicalPrizes) {
            for (int hole : spec.holes()) {
                if (hole < 1 || hole > holePars.length) {
                    throw new IllegalArgumentException(
                            spec.code() + " names hole " + hole + " on a " + holePars.length + "-hole course");
                }
            }
        }
    }

    /** Holes in the round. */
    public int holeCount() {
        return holePars.length;
    }

    /** Par for the whole course. */
    public int coursePar() {
        int sum = 0;
        for (int p : holePars) sum += p;
        return sum;
    }

    /** Par for a hole, 1-based as an organiser would say it. */
    public int parAt(int holeNumber) {
        return holePars[holeNumber - 1];
    }

    /** Every hole of the given par, 1-based — for defaulting technical prizes. */
    public List<Integer> holesWithPar(int par) {
        List<Integer> holes = new ArrayList<>();
        for (int i = 0; i < holePars.length; i++) {
            if (holePars[i] == par) holes.add(i + 1);
        }
        return holes;
    }

    /** The handicap a player is judged off, after the cap. */
    public int playingHandicap(double declaredHandicap) {
        int hdc = (int) Math.round(declaredHandicap);
        return handicapCap == null ? hdc : handicapCap.apply(hdc);
    }

    /** The division a handicap falls in, or null when it falls outside them all. */
    public Division divisionFor(int playingHandicap) {
        return divisions.stream()
                .filter(d -> d.contains(playingHandicap))
                .findFirst()
                .orElse(null);
    }

    /** The division with this code, or null. */
    public Division division(String code) {
        return divisions.stream()
                .filter(d -> d.code().equalsIgnoreCase(code))
                .findFirst()
                .orElse(null);
    }

    // ─── Pieces ─────────────────────────────────────────────────────────────

    /**
     * A prize group.
     *
     * "CLB chia 2 Nhóm theo HDC hiện tại: Nhóm A (HDC 0–25), Nhóm B (26–35)",
     * each with "01 giải nhất, 01 giải nhì, 01 giải ba".
     */
    public record Division(
            String code,
            String name,
            int minHandicap,
            int maxHandicap,
            /** Prize titles in rank order — the size of this list is how many prizes the division has. */
            List<String> prizeTitles) {

        public Division {
            if (minHandicap > maxHandicap) {
                throw new IllegalArgumentException(
                        "division " + code + " has min " + minHandicap + " above max " + maxHandicap);
            }
            if (prizeTitles == null) prizeTitles = List.of();
        }

        public boolean contains(int handicap) {
            return handicap >= minHandicap && handicap <= maxHandicap;
        }

        public int prizeCount() {
            return prizeTitles.size();
        }
    }

    /**
     * "Các Golfers HDC trên 36 sẽ cắt về 35."
     *
     * Two numbers, not one, because the sheet uses two: the threshold is 36 and
     * the value played off is 35, so a handicap of exactly 36 is not capped.
     * Reading that as a single clamp at 35 would quietly change one player's
     * division.
     */
    public record HandicapCap(int above, int playOff) {
        public int apply(int handicap) {
            return handicap > above ? playOff : handicap;
        }
    }

    /**
     * One band of the daily-CAP scale, in strokes over par for a single hole.
     *
     * Bounds are inclusive; null is open-ended. The club's scale is flat across
     * par, bogey and double bogey, which is why this is a list of bands and not
     * a formula.
     */
    public record CapBand(Integer minOverPar, Integer maxOverPar, int adjustment) {
        public boolean contains(int overPar) {
            return (minOverPar == null || overPar >= minOverPar)
                    && (maxOverPar == null || overPar <= maxOverPar);
        }
    }

    /** What a technical prize rewards. */
    public enum TechnicalKind {
        /** Closest to the hole wins — the smallest measurement. */
        NEAREST_TO_PIN,
        /** Furthest wins — the largest measurement. */
        LONGEST_DRIVE
    }

    /**
     * A technical prize and the holes it is played for.
     *
     * The holes are listed rather than derived from par: "04 giải Nearest to
     * the pin ở 4 hố Par 3" happens to match every par 3 on this course, but a
     * course with five par 3s would then hand out five prizes, and the club
     * budgeted for four.
     */
    public record TechnicalPrizeSpec(
            String code,
            String label,
            TechnicalKind kind,
            List<Integer> holes,
            /** Unit the measurement is recorded in, for display: "m", "gậy putter". */
            String unit) {

        public TechnicalPrizeSpec {
            if (holes == null) holes = List.of();
        }
    }

    // ─── The 19/04/2026 sheet ───────────────────────────────────────────────

    /**
     * VNPT-IT Golf Club — Chào hè 2026, Thanh Lanh Valley, 19/04/2026.
     *
     * Transcribed from "The le thi dau". The division boundaries follow the
     * rules page (A 0–25, B 26–35), which is also what the flight sheet's own
     * assignments do — every golfer listed at 25 is in A and every one at 26 is
     * in B, so the footer reading "A: 0-26" is a stale label, not the rule.
     *
     * The pars are Long Thành Championship's real card as the database holds
     * it: par 71, with par 3s on 4, 8, 12 and 16.
     *
     * Note what that does to the technical prizes. The rules say "04 giải
     * Longest drive ở 4 hố Par 5", and this course has three par 5s — 2, 7 and
     * 17. Deriving the holes from par would have silently handed out three
     * prizes where the club budgeted four, so they are listed explicitly and
     * the organiser decides which fourth hole, if any, carries the prize.
     */
    public static OutingRules vnptItSpringOuting2026() {
        int[] pars = {4, 5, 4, 3, 4, 4, 5, 3, 4, 4, 4, 3, 4, 4, 4, 3, 5, 4};

        return new OutingRules(
                pars,
                List.of(
                        new Division("A", "Nhóm A", 0, 25,
                                List.of("Nhất — Best Net", "Nhì — First Runner Up", "Ba — Second Runner Up")),
                        new Division("B", "Nhóm B", 26, 35,
                                List.of("Nhất — Best Net", "Nhì — First Runner Up", "Ba — Second Runner Up"))),
                new HandicapCap(36, 35),
                -3,
                List.of(9, 6, 3, 1),
                List.of(
                        new CapBand(null, -2, -2),   // eagle or better
                        new CapBand(-1, -1, -1),     // birdie
                        new CapBand(0, 2, 0),        // par, bogey, double bogey
                        new CapBand(3, 3, 1),        // triple bogey
                        new CapBand(4, 4, 2),
                        new CapBand(5, null, 3)),
                List.of(
                        new TechnicalPrizeSpec("NTP", "Nearest to the pin",
                                TechnicalKind.NEAREST_TO_PIN, List.of(4, 8, 12, 16), "m"),
                        // Three, not four: the course has three par 5s.
                        new TechnicalPrizeSpec("LD", "Longest drive",
                                TechnicalKind.LONGEST_DRIVE, List.of(2, 7, 17), "m")),
                true);
    }
}
