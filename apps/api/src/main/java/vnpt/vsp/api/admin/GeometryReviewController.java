package vnpt.vsp.api.admin;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.course.GeometryReviewService;
import vnpt.vsp.module.course.dto.CorrectParRequest;
import vnpt.vsp.module.course.dto.CorrectParResponse;
import vnpt.vsp.module.course.dto.GeometryReviewSummary;
import vnpt.vsp.module.course.dto.VerifyGeometryRequest;
import vnpt.vsp.module.course.dto.VerifyGeometryResponse;

/**
 * Review of imported course geometry.
 *
 * <p>Everything the OSM pipeline imports lands as PENDING_REVIEW, and the mobile
 * app refuses to draw a strategic map or run automatic hole detection against
 * anything short of VERIFIED. These two endpoints are the only way a hole ever
 * crosses that line, and crossing it is a claim a person makes — so the write
 * is restricted to course administrators and every call is audited with the
 * reviewer's name.</p>
 *
 * <ul>
 *   <li>{@code GET  /admin/courses/{courseId}/geometry/review} — what is waiting</li>
 *   <li>{@code POST /admin/courses/{courseId}/geometry/verify} — confirm holes</li>
 * </ul>
 */
@RestController
@RequestMapping("/admin/courses/{courseId}/geometry")
public class GeometryReviewController {

    private static final Logger log = LoggerFactory.getLogger(GeometryReviewController.class);

    private final GeometryReviewService reviewService;

    public GeometryReviewController(GeometryReviewService reviewService) {
        this.reviewService = reviewService;
    }

    /**
     * What is waiting to be reviewed on this course.
     *
     * <p>Readable by an auditor as well as an administrator: seeing what the
     * app does and does not trust is exactly what an auditor is for.</p>
     */
    @GetMapping("/review")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN', 'AUDITOR')")
    public ResponseEntity<GeometryReviewSummary> getReview(@PathVariable Long courseId) {
        return ResponseEntity.ok(reviewService.getReviewSummary(courseId));
    }

    /**
     * Confirms that the named holes' coordinates are right.
     *
     * <p>Not open to an auditor: reading what the app trusts is a different act
     * from deciding it.</p>
     */
    @PostMapping("/verify")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<VerifyGeometryResponse> verify(
            Authentication authentication,
            @PathVariable Long courseId,
            @Valid @RequestBody VerifyGeometryRequest request) {

        String reviewer = authentication.getName();
        log.info("POST /admin/courses/{}/geometry/verify - reviewer={}, holes={}",
                courseId, reviewer, request.holeNumbers().size());

        return ResponseEntity.ok(reviewService.verify(courseId, request, reviewer));
    }

    /**
     * Sets par on the named holes from the course's scorecard.
     *
     * <p>Same roles as verification and for the same reason — this changes what
     * every golfer's over/under-par figure is measured against — but a separate
     * endpoint, because reading a scorecard and checking coordinates on a map
     * are different claims and the audit trail should not merge them.</p>
     */
    @PostMapping("/par")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<CorrectParResponse> correctPar(
            Authentication authentication,
            @PathVariable Long courseId,
            @Valid @RequestBody CorrectParRequest request) {

        String reviewer = authentication.getName();
        log.info("POST /admin/courses/{}/geometry/par - reviewer={}, holes={}",
                courseId, reviewer, request.holes().size());

        return ResponseEntity.ok(reviewService.correctPar(courseId, request, reviewer));
    }
}
