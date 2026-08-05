package vnpt.vsp.api.course;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.api.idempotency.Idempotent;
import vnpt.vsp.module.correction.GeometryCorrectionService;
import vnpt.vsp.module.correction.dto.GeometryCorrectionRequest;
import vnpt.vsp.module.correction.dto.GeometryCorrectionResponse;

/**
 * Golfer-facing endpoint for reporting that a hole's geometry is wrong.
 *
 * <p>Counterpart to {@code /admin/corrections}, which is where the resulting
 * rows are reviewed. Both write the same {@code course_corrections} table.</p>
 *
 * <ul>
 *   <li>POST /courses/{courseId}/geometry-corrections — submit a layer correction</li>
 * </ul>
 *
 * <p>Requires an {@code Idempotency-Key} header, matching every other write
 * endpoint the mobile client retries: the app queues corrections offline and
 * replays them when the network returns, so the same report will arrive twice.</p>
 */
@RestController
@RequestMapping("/courses/{courseId}/geometry-corrections")
public class GeometryCorrectionController {

    private static final Logger log = LoggerFactory.getLogger(GeometryCorrectionController.class);

    private final GeometryCorrectionService geometryCorrectionService;

    public GeometryCorrectionController(GeometryCorrectionService geometryCorrectionService) {
        this.geometryCorrectionService = geometryCorrectionService;
    }

    /**
     * Submits a geometry correction for one layer of one hole.
     *
     * @param authentication the authenticated golfer (principal is the account ID)
     * @param courseId       the course the hole belongs to
     * @param request        layer, proposed shape, GPS accuracy, optional note
     * @return 201 with the stored correction and its corroboration outcome
     */
    @PostMapping
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<GeometryCorrectionResponse> submitGeometryCorrection(
            Authentication authentication,
            @PathVariable Long courseId,
            @Valid @RequestBody GeometryCorrectionRequest request) {

        Long reporterId = (Long) authentication.getPrincipal();
        log.info("POST /courses/{}/geometry-corrections - reporterId={}, holeId={}, layer={}",
                courseId, reporterId, request.getHoleId(), request.getLayer());

        GeometryCorrectionResponse response =
                geometryCorrectionService.submitGeometryCorrection(courseId, reporterId, request);

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}
