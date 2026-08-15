package vnpt.vsp.api.round;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.ai.RoundRecapService;
import vnpt.vsp.module.ai.dto.RoundRecapResponse;

import java.util.UUID;

/**
 * The round as the message that goes to the flight's Zalo.
 *
 * <p>A GET, because it writes nothing: the facts are read off the golfer's
 * own score rows and the sentence is cached. Reachable by anyone who played
 * in the round — the service checks that, not this controller.
 */
@RestController
public class RoundRecapController {

    private static final Logger log = LoggerFactory.getLogger(RoundRecapController.class);

    private final RoundRecapService roundRecapService;

    public RoundRecapController(RoundRecapService roundRecapService) {
        this.roundRecapService = roundRecapService;
    }

    @GetMapping("/rounds/{roundId}/recap")
    public RoundRecapResponse recap(
            Authentication authentication,
            @PathVariable UUID roundId) {

        Long golferId = (Long) authentication.getPrincipal();
        log.info("GET /rounds/{}/recap - golfer={}", roundId, golferId);

        return roundRecapService.recap(roundId, golferId);
    }
}
