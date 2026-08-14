package vnpt.vsp.api.course;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.ai.HoleAdviceService;
import vnpt.vsp.module.ai.dto.HoleAdviceResponse;

/**
 * What one golfer should know standing on one tee.
 *
 * <p>Authenticated and per-golfer by design: the answer is built from this
 * account's own scoring record on this hole and the clubs in their own bag, so
 * there is no such thing as a shared answer to cache publicly.
 */
@RestController
@Validated
public class HoleAdviceController {

    private static final Logger log = LoggerFactory.getLogger(HoleAdviceController.class);

    private final HoleAdviceService holeAdviceService;

    public HoleAdviceController(HoleAdviceService holeAdviceService) {
        this.holeAdviceService = holeAdviceService;
    }

    @GetMapping("/courses/{courseId}/holes/{holeNumber}/advice")
    public HoleAdviceResponse advice(
            Authentication authentication,
            @PathVariable Long courseId,
            // A course is nine or eighteen holes. Anything else is a
            // mistyped URL, and it should say so rather than reach the
            // database and come back as "course not found".
            @PathVariable @Min(1) @Max(18) int holeNumber,
            @RequestParam(required = false) String tee) {

        Long golferId = (Long) authentication.getPrincipal();
        log.info("GET /courses/{}/holes/{}/advice - golfer={}, tee={}",
                courseId, holeNumber, golferId, tee);

        return holeAdviceService.advise(courseId, holeNumber, tee, golferId);
    }
}
