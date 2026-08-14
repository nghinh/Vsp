package vnpt.vsp.module.bag;

import vnpt.vsp.module.bag.entity.Club;

import java.util.List;

/**
 * The fourteen clubs a bag starts with, and what they carry for nobody in
 * particular.
 *
 * <p>A golfer whose bag is empty gets no club advice at all, and filling in
 * fourteen carry distances before the app is any use is a wall most people do
 * not climb. Starting from a standard set and correcting what is wrong is a
 * far shorter path to advice that fits.
 *
 * <h2>These distances are not anybody's</h2>
 *
 * <p>They are the middle of the range for a men's amateur game, which means
 * they are wrong for almost everyone by some amount — a strong player carries
 * a 7-iron 20 m past this, and a beginner 20 m short of it. That is fine as a
 * starting point and dangerous as a silent fact, which is why every seeded
 * carry is written with {@code carryIsDefault} set and the flag is cleared the
 * moment a golfer edits it.
 *
 * <h2>Why loft, and why a name</h2>
 *
 * <p>{@link Club.ClubType} distinguishes a wood from an iron and stops there,
 * so eight irons in a bag are eight rows all reading IRON. Loft is the physical
 * fact that separates them, and it is what the standard set is keyed on.
 *
 * <p>The name is derived from that loft rather than stored, because the number
 * stamped on the sole is a marketing convention — one maker's 7-iron is
 * another's 6 — while the loft is the club.
 */
public final class StandardBag {

    private StandardBag() {}

    /**
     * One club of the standard set.
     *
     * @param carryMeters what it carries for the middle of the men's amateur
     *                    game, in metres, which is the canonical unit
     *                    everywhere in this database
     */
    public record Standard(Club.ClubType type, double loft, double carryMeters, String name) {}

    /// Ordered longest first, which is the order a bag is read in.
    private static final List<Standard> CLUBS = List.of(
            new Standard(Club.ClubType.DRIVER,  10.5, 200, "Driver"),
            new Standard(Club.ClubType.WOOD,    15.0, 185, "Gỗ 3"),
            new Standard(Club.ClubType.WOOD,    18.0, 172, "Gỗ 5"),
            new Standard(Club.ClubType.HYBRID,  21.0, 163, "Hybrid 4"),
            new Standard(Club.ClubType.IRON,    24.0, 155, "Sắt 4"),
            new Standard(Club.ClubType.IRON,    27.0, 146, "Sắt 5"),
            new Standard(Club.ClubType.IRON,    30.0, 137, "Sắt 6"),
            new Standard(Club.ClubType.IRON,    34.0, 128, "Sắt 7"),
            new Standard(Club.ClubType.IRON,    38.0, 117, "Sắt 8"),
            new Standard(Club.ClubType.IRON,    42.0, 106, "Sắt 9"),
            new Standard(Club.ClubType.WEDGE,   46.0,  95, "Pitching wedge"),
            new Standard(Club.ClubType.WEDGE,   50.0,  84, "Gap wedge"),
            new Standard(Club.ClubType.WEDGE,   54.0,  70, "Sand wedge"),
            // No carry: a putter is not a club anything is hit with, and giving
            // it a distance would put it in the running for an approach shot.
            new Standard(Club.ClubType.PUTTER,   3.0,   0, "Gậy putt"));

    public static List<Standard> clubs() {
        return CLUBS;
    }

    /**
     * What to call a club, from the loft rather than from the type.
     *
     * <p>Without this the advice says "IRON" for eight different clubs, which
     * tells a golfer nothing. Falls back to the type where a loft is absent or
     * unlike anything in the standard set — a golfer's own 2-iron should read
     * as an iron rather than be forced into the nearest name.
     */
    public static String nameFor(Club.ClubType type, Double loft) {
        if (loft == null) {
            return vietnameseType(type);
        }
        Standard nearest = null;
        double closest = Double.MAX_VALUE;
        for (Standard club : CLUBS) {
            if (club.type() != type) {
                continue;
            }
            double gap = Math.abs(club.loft() - loft);
            if (gap < closest) {
                closest = gap;
                nearest = club;
            }
        }
        // Two degrees is about the gap between neighbouring irons in a set, so
        // anything further out is a club the standard set does not describe.
        return nearest != null && closest <= 2.0 ? nearest.name() : vietnameseType(type);
    }

    private static String vietnameseType(Club.ClubType type) {
        return switch (type) {
            case DRIVER -> "Driver";
            case WOOD -> "Gỗ";
            case HYBRID -> "Hybrid";
            case IRON -> "Sắt";
            case WEDGE -> "Wedge";
            case PUTTER -> "Gậy putt";
        };
    }
}
