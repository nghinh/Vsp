package vnpt.vsp.api.admin;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.geometry.osm.OsmCourseImportService;

import java.util.Map;

/**
 * Pulling a course's shapes from OpenStreetMap.
 *
 * <p>Admin-only, though not for the reason the satellite trace is: this costs
 * nothing per call. It is restricted because it writes proposals across every
 * hole of a course at once, and because each call is a request against a
 * public service that a loop would get this deployment banned from.
 */
@RestController
public class OsmImportController {

    private static final Logger log = LoggerFactory.getLogger(OsmImportController.class);

    private final OsmCourseImportService importService;

    public OsmImportController(OsmCourseImportService importService) {
        this.importService = importService;
    }

    @PostMapping("/admin/courses/{courseId}/geometry/osm-import")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public Map<String, Object> importFromOsm(Authentication authentication,
                                             @PathVariable Long courseId) {
        String requestedBy = String.valueOf(authentication.getPrincipal());
        log.info("POST /admin/courses/{}/geometry/osm-import - {}", courseId, requestedBy);
        return importService.importCourse(courseId, requestedBy);
    }
}
