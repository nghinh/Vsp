package vnpt.vsp.api.weather;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.weather.WeatherService;
import vnpt.vsp.module.weather.dto.WeatherSnapshotDto;

import java.util.Map;
import java.util.UUID;

/**
 * REST controller for the /weather endpoint.
 * Per Story 7.1 Wave 1: GET /weather?lat={lat}&lng={lng}
 * Per Story 7.4: Wind adjustment endpoint with tournament feature restriction check.
 *
 * <p>Response headers:
 * <ul>
 *   <li>X-Weather-Source — provider display name</li>
 *   <li>X-Weather-Cached-At — ISO-8601 timestamp when cached (null if fresh)</li>
 *   <li>X-Weather-Fresh-Until — ISO-8601 timestamp when data is still fresh</li>
 *   <li>X-Weather-Stale — "true" if served from stale cache</li>
 * </ul>
 *
 * <p>Error responses:
 * <ul>
 *   <li>400 — invalid lat/lng coordinates</li>
 *   <li>502 — provider down + no cache</li>
 *   <li>500 — internal error</li>
 * </ul>
 */
@RestController
@RequestMapping("/weather")
@Validated
public class WeatherController {

    private final WeatherService weatherService;

    public WeatherController(WeatherService weatherService) {
        this.weatherService = weatherService;
    }

    /**
     * Get current weather snapshot for the given coordinates.
     *
     * @param lat latitude (-90 to 90)
     * @param lng longitude (-180 to 180)
     * @return WeatherSnapshotDto with X-Weather-* response headers
     */
    @GetMapping
    public ResponseEntity<WeatherSnapshotDto> getWeather(
            @RequestParam @Min(-90) @Max(90) Double lat,
            @RequestParam @Min(-180) @Max(180) Double lng) {

        if (lat == null || lng == null) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_002, "lat or lng");
        }

        WeatherSnapshotDto snapshot = weatherService.getWeather(lat, lng);

        HttpHeaders headers = new HttpHeaders();
        headers.add("X-Weather-Source", snapshot.getResponseSource() != null
                ? snapshot.getResponseSource() : snapshot.getProvider());
        headers.add("X-Weather-Stale", String.valueOf(snapshot.isStale()));

        if (snapshot.getCachedAt() != null) {
            headers.add("X-Weather-Cached-At", snapshot.getCachedAt().toString());
        }
        if (snapshot.getFreshUntil() != null) {
            headers.add("X-Weather-Fresh-Until", snapshot.getFreshUntil().toString());
        }

        // Cache-Control: 30 min (1800s) as specified in slice plan
        headers.add(HttpHeaders.CACHE_CONTROL, "max-age=1800, stale-while-revalidate=60");

        return ResponseEntity.ok()
                .headers(headers)
                .body(snapshot);
    }
}
