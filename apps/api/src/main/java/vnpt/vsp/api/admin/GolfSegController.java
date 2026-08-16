package vnpt.vsp.api.admin;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.geometry.golfseg.GolfSegImportService;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import java.util.Map;

/**
 * Tracing a hole with the trained segmentation model.
 *
 * <p>Admin-only. It is a GPU call and it writes proposals across a hole, and
 * — until the model is retrained on imagery this operator licences for
 * automated extraction — what it produces is research output rather than
 * something to publish.
 */
@RestController
@Validated
public class GolfSegController {

    private static final Logger log = LoggerFactory.getLogger(GolfSegController.class);

    private final GolfSegImportService importService;

    public GolfSegController(GolfSegImportService importService) {
        this.importService = importService;
    }

    @PostMapping("/admin/courses/{courseId}/holes/{holeNumber}/geometry/golfseg")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public Map<String, Object> trace(Authentication authentication,
                                     @PathVariable Long courseId,
                                     @PathVariable @Min(1) @Max(18) int holeNumber) {
        String requestedBy = String.valueOf(authentication.getPrincipal());
        log.info("POST /admin/courses/{}/holes/{}/geometry/golfseg - {}",
                courseId, holeNumber, requestedBy);
        return Map.of("courseId", courseId, "holeNumber", holeNumber,
                "filed", importService.traceHole(courseId, holeNumber, requestedBy));
    }

    /**
     * Files a FeatureCollection somebody else traced.
     *
     * <p>The vision service runs on a GPU host this API cannot reach, and
     * tracing is a batch job rather than something on a request path — so the
     * geometry arrives rather than being fetched. Same filing rules either
     * way: the confidence floor, the area bounds golf actually has, and a
     * place below anything a person drew.
     */
    @PostMapping("/admin/courses/{courseId}/holes/{holeNumber}/geometry/ingest")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public Map<String, Object> ingest(Authentication authentication,
                                      @PathVariable Long courseId,
                                      @PathVariable @Min(1) @Max(18) int holeNumber,
                                      @RequestBody JsonNode featureCollection) {
        String requestedBy = String.valueOf(authentication.getPrincipal());
        log.info("POST /admin/courses/{}/holes/{}/geometry/ingest - {}",
                courseId, holeNumber, requestedBy);
        return Map.of("courseId", courseId, "holeNumber", holeNumber,
                "filed", importService.ingest(courseId, holeNumber,
                        featureCollection, requestedBy));
    }
}
