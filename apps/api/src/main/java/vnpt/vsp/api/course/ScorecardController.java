package vnpt.vsp.api.course;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.idempotency.Idempotent;
import vnpt.vsp.module.correction.ScorecardCorrectionService;
import vnpt.vsp.module.correction.dto.ScorecardSubmissionRequest;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.course.dto.ScorecardDto;
import vnpt.vsp.module.course.ScorecardQueryService;

import java.util.List;
import java.util.Map;

/**
 * The club's printed card: golfers send it in, everyone reads it back.
 *
 * <p>Stroke index is on the card and in no open dataset, and without it no
 * net score can be worked out. There is no supplier to buy it from, so the
 * golfer standing on the first tee with the card in their hand is the source
 * — reviewed before it counts, like every other correction.
 */
@RestController
public class ScorecardController {

    private static final Logger log = LoggerFactory.getLogger(ScorecardController.class);

    private final ScorecardCorrectionService scorecardCorrectionService;
    private final ScorecardQueryService scorecardQueryService;

    public ScorecardController(
            ScorecardCorrectionService scorecardCorrectionService,
            ScorecardQueryService scorecardQueryService) {
        this.scorecardCorrectionService = scorecardCorrectionService;
        this.scorecardQueryService = scorecardQueryService;
    }

    /** Submit a card for review. */
    @PostMapping("/courses/{courseId}/scorecard-corrections")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<Map<String, Object>> submit(
            Authentication authentication,
            @PathVariable Long courseId,
            @Valid @RequestBody ScorecardSubmissionRequest request) {

        Long reporterId = (Long) authentication.getPrincipal();
        log.info("POST /courses/{}/scorecard-corrections - reporterId={}, holes={}",
                courseId, reporterId, request.holes().size());

        CourseCorrection saved = scorecardCorrectionService.submit(courseId, reporterId, request);

        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
                "correctionId", saved.getId(),
                "status", saved.getStatus().name()));
    }

    /** Every published card at this club. */
    @GetMapping("/facilities/{facilityId}/scorecards")
    public List<ScorecardDto> byFacility(@PathVariable Long facilityId) {
        return scorecardQueryService.byFacility(facilityId);
    }
}
