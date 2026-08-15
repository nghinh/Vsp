package vnpt.vsp.api.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.ai.HoleAdviceService;
import vnpt.vsp.module.ai.dto.CourseStrategyResponse;

/**
 * The whole card as one golfer should play it — the page a caddie would
 * pencil before the round.
 *
 * <p>Per-golfer like the per-hole advice, and for the same reason: the shot
 * allocation, the net pars and the club picks are built from this account's
 * handicap and bag. Facts only, no model call — see the service.
 */
@RestController
public class CourseStrategyController {

    private static final Logger log = LoggerFactory.getLogger(CourseStrategyController.class);

    private final HoleAdviceService holeAdviceService;

    public CourseStrategyController(HoleAdviceService holeAdviceService) {
        this.holeAdviceService = holeAdviceService;
    }

    @GetMapping("/courses/{courseId}/strategy")
    public CourseStrategyResponse strategy(
            Authentication authentication,
            @PathVariable Long courseId,
            // Names the second nine when the round is two nines from
            // different courses; its holes come back numbered 10–18.
            @RequestParam(required = false) Long backNineCourseId,
            @RequestParam(required = false) String tee) {

        Long golferId = (Long) authentication.getPrincipal();
        log.info("GET /courses/{}/strategy - golfer={}, backNine={}, tee={}",
                courseId, golferId, backNineCourseId, tee);

        return holeAdviceService.strategy(courseId, backNineCourseId, tee, golferId);
    }
}
