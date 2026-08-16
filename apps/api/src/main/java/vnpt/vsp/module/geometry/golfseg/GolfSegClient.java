package vnpt.vsp.module.geometry.golfseg;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

/**
 * Asking the vision service to trace a hole.
 *
 * <p>The models are PyTorch and this is Spring Boot, so they do not share a
 * process — §55. This is the whole of the contract: coordinates out, GeoJSON
 * back, and nothing about tiles, weights or CUDA on this side of it.
 *
 * <p>Unconfigured or unreachable is not an error worth propagating. A hole
 * without a traced fairway is the state every hole was in yesterday; a golfer
 * whose map fails to open because a GPU box is rebooting is a regression. So
 * this returns null and the caller carries on with whatever else it has.
 */
@Service
public class GolfSegClient {

    private static final Logger log = LoggerFactory.getLogger(GolfSegClient.class);

    private final String baseUrl;
    private final Duration timeout;
    private final ObjectMapper objectMapper;
    private final HttpClient http;

    public GolfSegClient(
            @Value("${vsp.golfseg.base-url:}") String baseUrl,
            @Value("${vsp.golfseg.timeout-seconds:90}") int timeoutSeconds,
            ObjectMapper objectMapper) {
        this.baseUrl = baseUrl == null ? "" : baseUrl.trim().replaceAll("/+$", "");
        this.timeout = Duration.ofSeconds(Math.max(10, timeoutSeconds));
        this.objectMapper = objectMapper;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    /// True when this deployment has a vision service to call.
    public boolean isConfigured() {
        return !baseUrl.isEmpty();
    }

    /**
     * The hole's shapes as a GeoJSON FeatureCollection, or null.
     *
     * <p>Null covers every reason the service could not answer — not
     * configured, not reachable, no model loaded, imagery refused. They are
     * one case to the caller because the response is the same in all of them:
     * keep what you already had.
     */
    public JsonNode traceHole(long courseId, int holeNumber,
                              double teeLat, double teeLng,
                              double greenLat, double greenLng) {
        if (!isConfigured()) {
            return null;
        }
        String body = """
                {"courseId": %d, "holeNumber": %d,
                 "teeLat": %f, "teeLng": %f,
                 "greenLat": %f, "greenLng": %f}
                """.formatted(courseId, holeNumber, teeLat, teeLng,
                greenLat, greenLng);
        try {
            var request = HttpRequest.newBuilder(URI.create(baseUrl + "/trace/hole"))
                    .timeout(timeout)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            HttpResponse<String> response =
                    http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                log.info("Golf vision service answered {} for course {} hole {}",
                        response.statusCode(), courseId, holeNumber);
                return null;
            }
            return objectMapper.readTree(response.body());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        } catch (Exception e) {
            log.info("Golf vision service unreachable: {}", e.getMessage());
            return null;
        }
    }
}
