package vnpt.vsp.api.admin;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.geometry.vision.HoleGeometryVisionService;

import java.util.Map;

/**
 * Tracing a hole's shapes from the operator's satellite imagery.
 *
 * <p>Files proposals in the draft queue for a human to review; it writes
 * nothing a golfer can see. Admin-only for the same reason the imagery is
 * licensed and the model is metered: each call costs money and produces work
 * for a reviewer.
 */
@RestController
@Validated
public class HoleGeometryVisionController {

    private static final Logger log =
            LoggerFactory.getLogger(HoleGeometryVisionController.class);

    private final HoleGeometryVisionService visionService;

    public HoleGeometryVisionController(HoleGeometryVisionService visionService) {
        this.visionService = visionService;
    }

    @PostMapping("/admin/courses/{courseId}/holes/{holeNumber}/geometry/detect")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public Map<String, Integer> detect(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable @Min(1) @Max(18) int holeNumber) {

        String requestedBy = String.valueOf(authentication.getPrincipal());
        log.info("Satellite geometry detection requested for course {} hole {} by {}",
                courseId, holeNumber, requestedBy);

        return visionService.detect(courseId, holeNumber, requestedBy);
    }
}
