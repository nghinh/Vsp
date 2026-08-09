package vnpt.vsp.module.course;

import java.math.BigDecimal;
import java.util.Optional;

/**
 * Whether a hole's par can be true given how long the hole is.
 *
 * <p><strong>Why this exists.</strong> Par came from the same seed script that
 * invented the coordinates, and it survived the OSM import untouched — the
 * import replaced every length with a measured one and left par alone. So Long
 * Thành ships a par 5 of 326 m and a par 4 of 476 m, and every over/under-par
 * number on the scorecard is computed from those. A golfer reading "+2" cannot
 * tell it is arithmetic against a fiction.</p>
 *
 * <p><strong>Where the bounds come from.</strong> The USGA and R&amp;A publish
 * yardage guidelines for assigning par; the bands below are the outer bounds of
 * those, widened so an unusual-but-real hole is not called wrong. They are
 * deliberately loose: this flags the impossible, not the surprising.</p>
 *
 * <p><strong>How they were checked.</strong> Against OpenStreetMap, which
 * carries its own {@code par} tag for 90 of the 100 holes this project has
 * matched to real ways. On those 90, OSM's par falls inside the band implied by
 * the measured length 88 times; the seeded par manages 58. The rule agrees with
 * an independent source far more often than the data it is judging, which is
 * the evidence for using it at all.</p>
 *
 * <p><strong>What it does not do.</strong> It does not change anybody's par.
 * A suggestion here is a prompt for a reviewer holding the course's scorecard,
 * because par is a scorecard fact and no measurement can settle it: two 380 m
 * holes can legitimately be a par 4 and a par 5. Replacing one unverified
 * number with another and calling it fixed would repeat the mistake that
 * produced the seed.</p>
 */
public final class ParPlausibility {

    private ParPlausibility() {}

    /** A hole of this par is never longer than this, in metres. */
    private static final double PAR_3_MAX = 260;

    /** Below this a par 4 is really a long par 3. */
    private static final double PAR_4_MIN = 200;

    /** Above this a par 4 is really a par 5. */
    private static final double PAR_4_MAX = 470;

    /** Below this a par 5 is really a par 4. */
    private static final double PAR_5_MIN = 380;

    /** Below this a par 6 is really a par 5. Par 6 holes are rare and long. */
    private static final double PAR_6_MIN = 520;

    /**
     * True when [par] is possible for a hole of [lengthMeters].
     *
     * <p>Unknown inputs are plausible: this exists to flag a contradiction, and
     * there is no contradiction in a number nobody recorded.</p>
     */
    public static boolean isPlausible(Integer par, BigDecimal lengthMeters) {
        if (par == null || lengthMeters == null) {
            return true;
        }
        double length = lengthMeters.doubleValue();
        if (length <= 0) {
            return true;
        }
        return switch (par) {
            case 3 -> length <= PAR_3_MAX;
            case 4 -> length >= PAR_4_MIN && length <= PAR_4_MAX;
            case 5 -> length >= PAR_5_MIN;
            case 6 -> length >= PAR_6_MIN;
            // A par outside 3–6 is not a golf hole's par, and saying "that is
            // fine" would hide it. Saying "that is wrong" is the point.
            default -> false;
        };
    }

    /**
     * The par this length would ordinarily carry.
     *
     * <p>Only offered when the recorded par is impossible — a reviewer with the
     * scorecard needs a starting point, not a second opinion on a hole that is
     * already consistent. Empty when the length is unknown, because a
     * suggestion with nothing behind it is a guess wearing a number.</p>
     */
    public static Optional<Integer> suggestFor(BigDecimal lengthMeters) {
        if (lengthMeters == null) {
            return Optional.empty();
        }
        double length = lengthMeters.doubleValue();
        if (length <= 0) {
            return Optional.empty();
        }
        if (length <= PAR_3_MAX) {
            return Optional.of(3);
        }
        if (length <= PAR_4_MAX) {
            return Optional.of(4);
        }
        if (length < PAR_6_MIN) {
            return Optional.of(5);
        }
        return Optional.of(6);
    }

    /**
     * A suggestion for a hole whose par contradicts its length, or empty when
     * nothing needs changing.
     */
    public static Optional<Integer> suggestionFor(Integer par, BigDecimal lengthMeters) {
        if (isPlausible(par, lengthMeters)) {
            return Optional.empty();
        }
        return suggestFor(lengthMeters).filter(suggested -> !suggested.equals(par));
    }
}
