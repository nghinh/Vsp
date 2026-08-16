package vnpt.vsp.api.round;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.round.HoleHistoryService;

import java.util.Map;
import java.util.UUID;

/**
 * A golfer's own record of one hole: what they scored, and what they learned.
 *
 * <p>Everything here is scoped to the caller in the service's own SQL rather
 * than checked by a guard first. There is no account id in any path, so there
 * is nothing to tamper with — a golfer cannot ask for somebody else's notes
 * because the query has no way to express the question.
 */
@RestController
@Validated
public class HoleHistoryController {

    private static final Logger log = LoggerFactory.getLogger(HoleHistoryController.class);

    private final HoleHistoryService historyService;

    public HoleHistoryController(HoleHistoryService historyService) {
        this.historyService = historyService;
    }

    @GetMapping("/courses/{courseId}/holes/{holeNumber}/my-history")
    public Map<String, Object> history(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable @Min(1) @Max(18) int holeNumber) {

        Long golferId = (Long) authentication.getPrincipal();
        return historyService.forHole(golferId, courseId, holeNumber);
    }

    @PostMapping("/courses/{courseId}/holes/{holeNumber}/notes")
    public Map<String, Object> addNote(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable @Min(1) @Max(18) int holeNumber,
            @RequestBody Map<String, String> body) {

        Long golferId = (Long) authentication.getPrincipal();
        // The round is optional and unvalidated on purpose: it is provenance,
        // not authorisation. A note whose round id is wrong is still the
        // golfer's note about the hole, and refusing it would lose what they
        // wrote to protect a field nothing reads for a decision.
        UUID roundId = null;
        String raw = body.get("roundId");
        if (raw != null && !raw.isBlank()) {
            try {
                roundId = UUID.fromString(raw.trim());
            } catch (IllegalArgumentException ignored) {
                roundId = null;
            }
        }
        log.info("POST /courses/{}/holes/{}/notes - golfer {}",
                courseId, holeNumber, golferId);
        return historyService.addNote(golferId, courseId, holeNumber,
                body.get("note"), roundId);
    }

    @DeleteMapping("/hole-notes/{noteId}")
    public ResponseEntity<Void> deleteNote(Authentication authentication,
                                           @PathVariable long noteId) {
        Long golferId = (Long) authentication.getPrincipal();
        return historyService.deleteNote(golferId, noteId)
                ? ResponseEntity.noContent().build()
                : ResponseEntity.notFound().build();
    }
}
