package vnpt.vsp.module.course.dto;

import java.util.List;

/**
 * What is waiting to be reviewed on one course.
 *
 * @param courseId    the course
 * @param courseName  its name, so the portal need not fetch it separately
 * @param holes       every hole, reviewed or not, newest state
 * @param pendingHoles how many carry PENDING_REVIEW coordinates
 * @param verifiedHoles how many a person has already confirmed
 * @param unverifiedHoles how many still hold coordinates nobody digitised —
 *                        these cannot be verified, only replaced
 * @param holeParTotal    par summed across the holes
 * @param courseParTotal  par the course itself advertises, or null when it
 *                        does not. The two disagreeing is the sharpest signal
 *                        this page has: a course's total par is a published
 *                        fact, so a mismatch means at least one hole's par is
 *                        still wrong — including holes whose par is individually
 *                        plausible and therefore flagged by nothing else.
 */
public record GeometryReviewSummary(
        Long courseId,
        String courseName,
        List<HoleReviewItem> holes,
        int pendingHoles,
        int verifiedHoles,
        int unverifiedHoles,
        int holeParTotal,
        Integer courseParTotal
) {

    /**
     * One hole as a reviewer sees it.
     *
     * @param holeNumber      1-18
     * @param par             par from the scorecard
     * @param lengthMeters    measured along the imported way, not tee-to-green
     * @param source          e.g. {@code osm:way/1017320363} or {@code SEED}
     * @param accuracyClass   PRD §9.4 class
     * @param verificationStatus UNVERIFIED / PENDING_REVIEW / VERIFIED
     * @param hasCoordinates  false when the hole has no tee or green point
     * @param greens          imported greens attached to this hole
     * @param bunkers         imported bunkers
     * @param teeBoxes        imported tee boxes
     * @param reviewable      true when there is real geometry here to confirm
     * @param parMatchesLength false when this par is impossible for a hole of
     *                        this length. Par came from the seed script and the
     *                        OSM import replaced the length without touching
     *                        it, so the two now contradict each other on 42 of
     *                        the 100 matched holes — and every over/under-par
     *                        number on the scorecard is arithmetic against par.
     * @param suggestedPar    the par this length would ordinarily carry, when
     *                        the recorded one is impossible. A prompt for a
     *                        reviewer holding the scorecard, never applied on
     *                        its own: par is a scorecard fact, and no
     *                        measurement can settle whether a 380 m hole is a
     *                        long par 4 or a short par 5.
     */
    public record HoleReviewItem(
            Integer holeNumber,
            Integer par,
            Double lengthMeters,
            String source,
            String accuracyClass,
            String verificationStatus,
            boolean hasCoordinates,
            long greens,
            long bunkers,
            long teeBoxes,
            boolean reviewable,
            boolean parMatchesLength,
            Integer suggestedPar
    ) {}
}
