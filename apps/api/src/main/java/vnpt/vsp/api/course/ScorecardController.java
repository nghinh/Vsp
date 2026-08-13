package vnpt.vsp.api.course;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.CacheControl;
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
import vnpt.vsp.module.correction.ScorecardPhotoStore;
import vnpt.vsp.module.correction.dto.ScorecardSubmissionRequest;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.course.dto.ScorecardDto;
import vnpt.vsp.module.course.ScorecardQueryService;
import vnpt.vsp.module.round.repository.RoundRepository;

import java.io.IOException;
import java.time.Duration;
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
    private final ScorecardPhotoStore scorecardPhotoStore;
    private final RoundRepository roundRepository;
    private final ObjectMapper objectMapper;

    public ScorecardController(
            ScorecardCorrectionService scorecardCorrectionService,
            ScorecardQueryService scorecardQueryService,
            ScorecardOcrService scorecardOcrService,
            ScorecardPhotoStore scorecardPhotoStore,
            RoundRepository roundRepository,
            ObjectMapper objectMapper) {
        this.scorecardCorrectionService = scorecardCorrectionService;
        this.scorecardQueryService = scorecardQueryService;
        this.scorecardOcrService = scorecardOcrService;
        this.scorecardPhotoStore = scorecardPhotoStore;
        this.roundRepository = roundRepository;
        this.objectMapper = objectMapper;
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
     * <p>Nothing is queued: the answer goes back to the phone as a draft for
     * the golfer to check against the card in their hand, and only then does
     * it become a SCORECARD correction for an admin to review. Two human
     * checks, the same as a card typed by hand.
     *
     * <p>The photograph itself is kept, and its URL comes back as
     * {@code photoUrl} for the app to hand straight to the submission. It used
     * to be discarded here, which left the reviewer approving eighteen pars
     * and ninety yardages with nothing behind them but the golfer's typing —
     * and left the published card indistinguishable from a table someone
     * generated, which is the failure this project has already paid for once.
     * Storing it after the read rather than before means a photograph that
     * turned out not to be a scorecard leaves nothing behind.
     */
    @PostMapping(value = "/courses/{courseId}/scorecard-corrections/extract",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<String> extract(
            Authentication authentication,
            @PathVariable Long courseId,
            @RequestPart("image") MultipartFile image) throws IOException {

        Long reporterId = (Long) authentication.getPrincipal();
        String mediaType = image.getContentType();

        // Logged before it is judged. This used to run after validateImage, so
        // a refused photograph left no trace at all: the phone was sending
        // application/octet-stream for months and the only evidence anywhere
        // was a golfer looking at "Request validation failed" on a screen.
        log.info("POST /courses/{}/scorecard-corrections/extract - reporterId={}, {} bytes, type={}",
                courseId, reporterId, image.getSize(), mediaType);

        validateImage(image);

        String card = scorecardOcrService.extractCourse(image.getBytes(), mediaType);
        String photoUrl = scorecardPhotoStore.store(image.getBytes(), mediaType);
        // For the phones that do not yet read photoUrl back. Without this,
        // evidence would only start being kept once every installed app had
        // been replaced, and every card submitted in between would be
        // unverifiable for good.
        scorecardPhotoStore.remember(reporterId, courseId, photoUrl);

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .body(withPhotoUrl(card, photoUrl));
    }

    /**
     * The card the reader produced, plus where its photograph now lives.
     *
     * <p>Null when the deployment keeps no photographs, and null is honest: the
     * app then submits without an evidence URL exactly as it did before, rather
     * than sending a path that would 404 in the reviewer's face.
     */
    private String withPhotoUrl(String card, String photoUrl) {
        if (photoUrl == null) {
            return card;
        }
        try {
            ObjectNode node = (ObjectNode) objectMapper.readTree(card);
            node.put("photoUrl", photoUrl);
            return objectMapper.writeValueAsString(node);
        } catch (Exception e) {
            // The card was read; losing the URL is worth less than the card.
            log.warn("The card was read but its photograph URL could not be attached", e);
            return card;
        }
    }

    /**
     * A photograph a card was read from.
     *
     * <p>Open, like {@code /packages/**}: an {@code <img src>} in the review
     * portal carries no bearer token, and neither would a CDN. What stands in
     * for the token is the name — a photograph is addressed by the SHA-256 of
     * its own bytes, so it can only be fetched by someone who was already given
     * the URL by the reader or the correction it is attached to.
     */
    @GetMapping("/scorecard-photos/{name}")
    public ResponseEntity<byte[]> photo(@PathVariable String name) {
        return scorecardPhotoStore.read(name)
                .map(photo -> ResponseEntity.ok()
                        .contentType(MediaType.parseMediaType(photo.mediaType()))
                        // Content-addressed, so the bytes at a name never
                        // change and the portal need not ask twice.
                        .cacheControl(CacheControl.maxAge(Duration.ofDays(365)).cachePublic())
                        .body(photo.data()))
                .orElseGet(() -> ResponseEntity.notFound().build());
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

        log.info("POST /rounds/{}/scores/extract - accountId={}, {} bytes, type={}",
                roundId, accountId, image.getSize(), image.getContentType());

        String mediaType = validateImage(image);

        // The round is checked before the photograph is sent anywhere. Reading
        // a card costs a call to a metered gateway and takes half a minute, so
        // an id nobody owns has to stop here rather than after the bill.
        roundRepository.findByIdAndGolferAccountIdAndDeletedAtIsNull(roundId, accountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROUND_001));

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
