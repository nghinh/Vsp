package vnpt.vsp.api.admin;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.geometry.vision.CourseMappingService;

import java.util.Map;
import java.util.UUID;

/**
 * Starting and watching a satellite trace of a whole course.
 *
 * <p>Admin-only: eighteen holes is eighteen metered model calls, and what
 * comes back is work for a reviewer rather than something a golfer sees.
 */
@RestController
public class CourseMappingController {

    private final CourseMappingService mappingService;

    public CourseMappingController(CourseMappingService mappingService) {
        this.mappingService = mappingService;
    }

    @PostMapping("/admin/courses/{courseId}/geometry/analyze")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public Map<String, Object> analyze(Authentication authentication,
                                       @PathVariable Long courseId) {
        UUID jobId = mappingService.request(courseId,
                String.valueOf(authentication.getPrincipal()));
        return mappingService.status(jobId);
    }

    @GetMapping("/admin/courses/{courseId}/geometry/analyze/{jobId}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN', 'AUDITOR')")
    public Map<String, Object> status(@PathVariable Long courseId,
                                      @PathVariable UUID jobId) {
        return mappingService.status(jobId);
    }
}
