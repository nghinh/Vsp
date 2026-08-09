package vnpt.vsp.module.course;

import vnpt.vsp.module.course.dto.CorrectParRequest;
import vnpt.vsp.module.course.dto.CorrectParResponse;
import vnpt.vsp.module.course.dto.GeometryReviewSummary;
import vnpt.vsp.module.course.dto.VerifyGeometryRequest;
import vnpt.vsp.module.course.dto.VerifyGeometryResponse;

/**
 * Turns imported geometry into geometry the app is willing to draw.
 *
 * <p>Everything the OSM pipeline writes lands as
 * {@code D_UNVERIFIED_COMMUNITY / PENDING_REVIEW}, on purpose: it is real
 * geometry from a source nobody at VSP has checked. The mobile app's provenance
 * gate requires VERIFIED before it will draw a strategic map or let automatic
 * hole detection score a position, so until a person confirms it, four courses
 * with 18/18 holes of genuine coordinates are treated exactly like the 831
 * holes a seed script invented.</p>
 *
 * <p>That gate is not something to route around. This service is the other side
 * of it: a named human looks at a hole and says the coordinates are right, and
 * that assertion is what flips the status. Verification is per hole and carries
 * a note, because "I checked these eighteen holes" is a claim about eighteen
 * holes and the audit trail should be able to name who made it.</p>
 */
public interface GeometryReviewService {

    /**
     * What is waiting to be reviewed on a course.
     *
     * <p>Per hole: where its coordinates came from, how long it plays, and how
     * many greens, bunkers and tee boxes were imported alongside it — enough
     * for a reviewer to know whether a hole is worth opening on the map, and to
     * spot the ones that arrived with nothing.</p>
     */
    GeometryReviewSummary getReviewSummary(Long courseId);

    /**
     * Marks the named holes, and the geometry attached to them, as verified.
     *
     * <p>Only holes actually listed in the request are touched: verifying a
     * whole course in one click would make the status mean "somebody pressed a
     * button" rather than "somebody looked". Holes whose coordinates are still
     * the seed's invention are refused outright — there is nothing there to
     * confirm, and marking them verified is precisely the lie this whole gate
     * exists to prevent.</p>
     *
     * @param courseId course being reviewed
     * @param request  the holes the reviewer confirms, and why
     * @param reviewer username recorded in the audit trail
     */
    VerifyGeometryResponse verify(Long courseId, VerifyGeometryRequest request, String reviewer);

    /**
     * Sets par on the named holes from the course's scorecard.
     *
     * <p>Par was written by the same seed script that invented the coordinates,
     * and the OSM import replaced every length with a measured one while
     * leaving par untouched — so on 42 of the 100 matched holes the two now
     * contradict each other, and every over/under-par figure a golfer reads is
     * arithmetic against the wrong number.</p>
     *
     * <p>A measurement cannot settle par: two 380 m holes can legitimately be a
     * par 4 and a par 5. So this takes the reviewer's numbers, applies them, and
     * records where they still disagree with the measured length rather than
     * refusing them — a person holding the card outranks a rule of thumb, but a
     * card and a measurement that disagree mean one of them is wrong and
     * somebody should know.</p>
     *
     * @param courseId course being corrected
     * @param request  the holes and their par, and where the reviewer got them
     * @param reviewer username recorded in the audit trail
     */
    CorrectParResponse correctPar(Long courseId, CorrectParRequest request, String reviewer);
}
