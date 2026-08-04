package vnpt.vsp.api.weather;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.error.FeatureRestrictedException;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.tournament.TournamentPolicyService;
import vnpt.vsp.module.weather.WeatherService;
import vnpt.vsp.module.weather.dto.WeatherSnapshotDto;

import java.util.UUID;

/**
 * REST controller for weather adjustment endpoints.
 * Per Story 7.4 Slice E: Backend API enforcement.
 *
 * Endpoints that check tournament policy before returning restricted data:
 * - GET /weather/adjustment — wind adjustment data (gated by windAdjustmentEnabled)
 */
@RestController
@RequestMapping("/weather")
public class WeatherAdjustmentController {

    private static final Logger log = LoggerFactory.getLogger(WeatherAdjustmentController.class);

    private final WeatherService weatherService;
    private final RoundRepository roundRepository;
    private final TournamentPolicyService tournamentPolicyService;

    public WeatherAdjustmentController(
            WeatherService weatherService,
            RoundRepository roundRepository,
            TournamentPolicyService tournamentPolicyService) {
        this.weatherService = weatherService;
        this.roundRepository = roundRepository;
        this.tournamentPolicyService = tournamentPolicyService;
    }

    /**
     * Get wind adjustment data for a round.
     *
     * Per Story 7.4 Slice E:
     * - Validates the round's tournament policy
     * - Returns 403 with FEATURE_RESTRICTED if wind adjustment is disabled
     *
     * @param roundId the round UUID to check tournament policy for
     * @param lat latitude for weather data
     * @param lng longitude for weather data
     * @return 200 with weather data, or 403 with FeatureRestrictedError
     */
    @GetMapping("/adjustment")
    public ResponseEntity<WeatherSnapshotDto> getWindAdjustment(
            @RequestParam UUID roundId,
            @RequestParam Double lat,
            @RequestParam Double lng) {

        log.info("GET /weather/adjustment roundId={} lat={} lng={}", roundId, lat, lng);

        // Throws FeatureRestrictedException (403) if wind adjustment is disabled
        enforceWindAdjustmentEnabled(roundId);

        WeatherSnapshotDto snapshot = weatherService.getWeather(lat, lng);

        HttpHeaders headers = new HttpHeaders();
        headers.add("X-Weather-Source",
                snapshot.getResponseSource() != null ? snapshot.getResponseSource() : snapshot.getProvider());

        return ResponseEntity.ok().headers(headers).body(snapshot);
    }

    /**
     * Enforces that wind adjustment is enabled for the given round's tournament policy.
     *
     * @param roundId the round UUID
     * @throws FeatureRestrictedException if wind adjustment is disabled (403)
     */
    private void enforceWindAdjustmentEnabled(UUID roundId) {
        Round round = roundRepository.findById(roundId).orElse(null);
        if (round == null) {
            // No round = casual/practice = no restrictions
            return;
        }

        UUID policyId = round.getTournamentPolicyId();
        if (policyId == null) {
            // No policy = casual/practice = no restrictions
            return;
        }

        boolean isEnabled = tournamentPolicyService.isFeatureEnabled(policyId, "windAdjustmentEnabled");
        if (!isEnabled) {
            log.warn("Wind adjustment is restricted for round {} (policy {})", roundId, policyId);
            throw new FeatureRestrictedException(
                    "windAdjustmentEnabled",
                    "Wind adjustment is disabled in tournament mode"
            );
        }
    }
}
