package vnpt.vsp.module.profile;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.profile.dto.GolferPerformanceResponse;

/**
 * The golfer's own record, counted from their own rounds.
 *
 * <p>{@code window} is a number of recent rounds — the app offers all of
 * them, the last twenty and the last five, which are the three ways a golfer
 * asks the question: how do I play, how am I playing, how did today go.
 */
@RestController
@Validated
public class GolferPerformanceController {

    private final GolferPerformanceService performanceService;

    public GolferPerformanceController(GolferPerformanceService performanceService) {
        this.performanceService = performanceService;
    }

    @GetMapping("/golfers/me/performance")
    public GolferPerformanceResponse performance(
            Authentication authentication,
            @RequestParam(required = false) @Min(1) @Max(500) Integer window) {

        Long golferId = (Long) authentication.getPrincipal();
        return performanceService.compute(golferId, window);
    }
}
