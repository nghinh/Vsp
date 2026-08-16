package vnpt.vsp.module.geometry.osm;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Arrays;
import java.util.List;

/**
 * Asking OpenStreetMap what is inside a bounding box.
 *
 * <p>Overpass is a public service run on donations. Everything here is shaped
 * by that: one request per course rather than per hole, a long timeout instead
 * of a retry storm, and an identifying user agent so an operator with a
 * complaint has somebody to complain to. A client that hammers it gets the
 * whole deployment banned by IP.
 */
@Service
public class OverpassClient {

    private static final Logger log = LoggerFactory.getLogger(OverpassClient.class);

    /// How long to wait after being turned away before asking again. The
    /// public instances allow two queries at a time per address and answer
    /// 429 to the third; importing three courses in a row hits that every
    /// time, and the cure is to wait rather than to ask harder.
    private static final Duration BACKOFF = Duration.ofSeconds(12);

    private static final int ATTEMPTS = 3;

    private final List<String> endpoints;
    private final Duration timeout;
    private final String userAgent;
    private final HttpClient http;

    public OverpassClient(
            @Value("${vsp.osm.overpass-url:https://overpass-api.de/api/interpreter,https://overpass.kumi.systems/api/interpreter}")
            String endpoints,
            @Value("${vsp.osm.timeout-seconds:120}") int timeoutSeconds,
            @Value("${vsp.osm.user-agent:VSP-golf/1.0 (course geometry import)}")
            String userAgent) {
        this.endpoints = endpoints == null ? List.of()
                : Arrays.stream(endpoints.split(","))
                        .map(String::trim)
                        .filter(url -> !url.isEmpty())
                        .toList();
        this.timeout = Duration.ofSeconds(Math.max(30, timeoutSeconds));
        this.userAgent = userAgent;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(15))
                .followRedirects(HttpClient.Redirect.NORMAL)
                .build();
    }

    public boolean isConfigured() {
        return !endpoints.isEmpty();
    }

    /**
     * Every golf feature and every body of water in the box, with geometry.
     *
     * @return the raw Overpass JSON, or null when the service could not be
     *         reached — which is a reason to leave the existing drafts alone,
     *         not to delete them and import nothing.
     */
    public String fetchGolfFeatures(double south, double west,
                                    double north, double east) {
        if (!isConfigured()) {
            return null;
        }
        // `out geom` returns each way's coordinates inline. Without it the
        // answer is node ids and a second round trip to resolve them.
        // What is deliberately not asked for: `highway`.
        //
        // Only 7 of 73 courses have a cart path on file, and the obvious
        // reading was that this query is too narrow — a cart path is a
        // service road, so ask for service roads. Checked against OSM at
        // three of the courses with none, that reading is wrong and the fix
        // would be actively harmful. Tam Đảo, The Bluffs and Heron Lake carry
        // no `golf` tag of any kind: what is inside their bounding boxes is
        // 36, 1 and 20 ways tagged `highway=residential` and 19, 18 and 28
        // tagged `highway=service` — the housing estate and its streets.
        // Buffered 60 m as cart paths, those would draw a boundary around the
        // neighbourhood, which is the one thing the boundary exists to keep
        // out.
        //
        // Where a course *is* mapped the existing filter already finds the
        // paths: Long Biên has 16 ways tagged `golf=cartpath`. The ceiling is
        // OpenStreetMap's coverage of Vietnamese golf, not this string.
        //
        // Two additions that are safe and were missing:
        //
        //   * `golf_cart` — a way a buggy may use, mapped without reaching for
        //     `golf=cartpath`. Every one of Long Biên's 16 carries it too, so
        //     it costs nothing where the tag is already right and catches the
        //     mapper who used only one of the two.
        //   * relations — a golf feature mapped as a multipolygon was invisible
        //     to a query that asks only for ways. A green with a bunker cut out
        //     of it is exactly that shape.
        String query = """
                [out:json][timeout:%d];
                (
                  way["golf"](%f,%f,%f,%f);
                  way["golf_cart"](%f,%f,%f,%f);
                  relation["golf"](%f,%f,%f,%f);
                  way["natural"="water"](%f,%f,%f,%f);
                );
                out geom;
                """.formatted(timeout.toSeconds(),
                south, west, north, east,
                south, west, north, east,
                south, west, north, east,
                south, west, north, east);

        // Round-robin across the mirrors, then wait and go round again. Being
        // turned away is the expected answer, not the exceptional one.
        for (int attempt = 0; attempt < ATTEMPTS; attempt++) {
            for (String endpoint : endpoints) {
                String body = ask(endpoint, query);
                if (body != null) {
                    return body;
                }
            }
            if (attempt < ATTEMPTS - 1 && !sleep()) {
                return null;
            }
        }
        log.warn("Overpass turned away {} attempt(s) for the box {},{} to {},{}",
                ATTEMPTS, south, west, north, east);
        return null;
    }

    /// One query against one mirror, or null for any reason at all.
    private String ask(String endpoint, String query) {
        try {
            var request = HttpRequest.newBuilder(URI.create(endpoint))
                    .timeout(timeout)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .header("User-Agent", userAgent)
                    .POST(HttpRequest.BodyPublishers.ofString(
                            "data=" + URLEncoder.encode(query, StandardCharsets.UTF_8)))
                    .build();
            HttpResponse<String> response =
                    http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                log.info("Overpass at {} answered {}", endpoint, response.statusCode());
                return null;
            }
            return response.body();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        } catch (Exception e) {
            log.info("Overpass at {} could not be reached: {}", endpoint, e.getMessage());
            return null;
        }
    }

    /// False when the wait was interrupted, which means give up rather than
    /// carry on ignoring the interrupt.
    private boolean sleep() {
        try {
            Thread.sleep(BACKOFF.toMillis());
            return true;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        }
    }
}
