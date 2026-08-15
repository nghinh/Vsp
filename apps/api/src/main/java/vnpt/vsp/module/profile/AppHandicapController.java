package vnpt.vsp.module.profile;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;

/**
 * The handicap this app can vouch for.
 */
@RestController
public class AppHandicapController {

    private final AppHandicapService service;

    public AppHandicapController(AppHandicapService service) {
        this.service = service;
    }

    public record AppHandicapResponse(
            BigDecimal handicap, int roundsCounted, int roundsNeeded) {}

    @GetMapping("/golfers/me/app-handicap")
    public AppHandicapResponse mine(Authentication auth) {
        var result = service.compute((Long) auth.getPrincipal());
        return new AppHandicapResponse(
                result.handicap(), result.roundsCounted(),
                AppHandicapService.MIN_ROUNDS);
    }
}
