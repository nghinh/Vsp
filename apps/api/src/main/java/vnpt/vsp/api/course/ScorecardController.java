package vnpt.vsp.api.course;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.idempotency.Idempotent;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.correction.ScorecardCorrectionService;
import vnpt.vsp.module.correction.ScorecardOcrService;
import vnpt.vsp.module.correction.dto.ScorecardSubmissionRequest;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.course.dto.ScorecardDto;
import vnpt.vsp.module.course.ScorecardQueryService;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

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

    /// A card photographed at the tee, not a scan: cap it where a phone
    /// photo lands rather than where the model would start to struggle.
    private static final long MAX_IMAGE_BYTES = 8L * 1024 * 1024;

    private static final Set<String> ALLOWED_IMAGE_TYPES =
            Set.of("image/jpeg", "image/png", "image/webp");

    private final ScorecardCorrectionService scorecardCorrectionService;
    private final ScorecardQueryService scorecardQueryService;
    private final ScorecardOcrService scorecardOcrService;

    public ScorecardController(
            ScorecardCorrectionService scorecardCorrectionService,
            ScorecardQueryService scorecardQueryService,
            ScorecardOcrService scorecardOcrService) {
        this.scorecardCorrectionService = scorecardCorrectionService;
        this.scorecardQueryService = scorecardQueryService;
        this.scorecardOcrService = scorecardOcrService;
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

    /**
     * Read a photograph of the club's card and hand back what it says.
     *
     * <p>Nothing is stored and nothing is queued: the answer goes back to the
     * phone as a draft for the golfer to check against the card in their
     * hand, and only then does it become a SCORECARD correction for an admin
     * to review. Two human checks, the same as a card typed by hand.
     */
    @PostMapping(value = "/courses/{courseId}/scorecard-corrections/extract",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<String> extract(
            Authentication authentication,
            @PathVariable Long courseId,
            @RequestPart("image") MultipartFile image) throws IOException {

        Long reporterId = (Long) authentication.getPrincipal();
        String mediaType = image.getContentType();

        validateImage(image);

        log.info("POST /courses/{}/scorecard-corrections/extract - reporterId={}, {} bytes",
                courseId, reporterId, image.getSize());

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .body(scorecardOcrService.extractCourse(image.getBytes(), mediaType));
    }

    /**
     * Read the strokes a golfer wrote on their card by hand.
     *
     * <p>Returns a draft, exactly like the course reader: the app shows the
     * numbers next to the photograph, the golfer corrects what the model got
     * wrong, and only then does the app post them to the ordinary score sync.
     * Nothing here writes a score — a misread stroke that saved itself would
     * be indistinguishable from one the golfer took.
     */
    @PostMapping(value = "/rounds/{roundId}/scores/extract",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<String> extractScores(
            Authentication authentication,
            @PathVariable UUID roundId,
            @RequestPart("image") MultipartFile image) throws IOException {

        Long accountId = (Long) authentication.getPrincipal();
        String mediaType = validateImage(image);

        log.info("POST /rounds/{}/scores/extract - accountId={}, {} bytes",
                roundId, accountId, image.getSize());

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .body(scorecardOcrService.extractScores(image.getBytes(), mediaType));
    }

    /** Every published card at this club. */
    @GetMapping("/facilities/{facilityId}/scorecards")
    public List<ScorecardDto> byFacility(@PathVariable Long facilityId) {
        return scorecardQueryService.byFacility(facilityId);
    }

    /// What a phone camera can hand us, and nothing else: the model bills by
    /// the image, so an accidental video frame or a 40 MB raw file should be
    /// refused here rather than sent.
    private String validateImage(MultipartFile image) {
        String mediaType = image.getContentType();
        if (image.isEmpty() || mediaType == null || !ALLOWED_IMAGE_TYPES.contains(mediaType)) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                    Map.of("image", "send a JPEG, PNG or WebP photograph of the card"));
        }
        if (image.getSize() > MAX_IMAGE_BYTES) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                    Map.of("image", "the photograph is larger than 8 MB"));
        }
        return mediaType;
    }
}
