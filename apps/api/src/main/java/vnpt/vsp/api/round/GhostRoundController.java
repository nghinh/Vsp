package vnpt.vsp.api.round;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.round.GhostRoundService;
import vnpt.vsp.module.round.dto.GhostRoundResponse;

/**
 * The ghost an active round races: this golfer's best completed round on the
 * same course pairing.
 *
 * <p>204 rather than 404 when there is none — a first round on a course has
 * no ghost, and the app treats that as "nothing to show", not an error.
 */
@RestController
public class GhostRoundController {

    private final GhostRoundService ghostRoundService;

    public GhostRoundController(GhostRoundService ghostRoundService) {
        this.ghostRoundService = ghostRoundService;
    }

    @GetMapping("/courses/{courseId}/ghost")
    public ResponseEntity<GhostRoundResponse> ghost(
            Authentication authentication,
            @PathVariable Long courseId,
            @RequestParam(required = false) Long backNineCourseId) {

        Long golferId = (Long) authentication.getPrincipal();
        GhostRoundResponse ghost =
                ghostRoundService.ghost(courseId, backNineCourseId, golferId);
        return ghost == null ? ResponseEntity.noContent().build()
                : ResponseEntity.ok(ghost);
    }
}
