package vnpt.vsp.api.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Tells the app where its satellite imagery comes from.
 *
 * <p><strong>Why this is served rather than compiled in.</strong> The client
 * reads its imagery provider from {@code --dart-define} values baked into the
 * binary. That works, and it is why no build that exists today has imagery: a
 * define cannot be changed for an app already installed on a golfer's phone, so
 * switching satellite on for a pilot meant shipping a new release, and
 * switching it off after a billing surprise meant shipping another one. Serving
 * the same three values makes the provider an operational setting with a
 * revocation path.</p>
 *
 * <p><strong>On handing a token to a client.</strong> A Mapbox <em>public</em>
 * token (<code>pk.</code>) is designed to be distributed in client software and
 * is restricted by URL and scope at Mapbox's end; shipping it in the binary was
 * already distributing it, to anyone willing to unzip an APK. Serving it to
 * authenticated callers is no weaker and can be rotated in a config change. A
 * <em>secret</em> token (<code>sk.</code>) is a different thing entirely and is
 * refused below — an operator who pastes one into the wrong field would
 * otherwise hand full account credentials to every phone that opened the app.
 * </p>
 *
 * <p>Unset by default. An unconfigured deployment answers "none configured",
 * the app says so plainly, and the measuring tool keeps working over a plain
 * canvas — the same honest degrade as before.</p>
 */
@RestController
@RequestMapping("/config")
public class BasemapConfigController {

    private static final Logger log = LoggerFactory.getLogger(BasemapConfigController.class);

    /** Mapbox tokens meant for client distribution begin with this. */
    private static final String PUBLIC_TOKEN_PREFIX = "pk.";

    /** Mapbox tokens that must never leave the server begin with this. */
    private static final String SECRET_TOKEN_PREFIX = "sk.";

    private final String mapboxAccessToken;
    private final String satelliteTileUrl;
    private final String satelliteAttribution;
    private final Integer satelliteMaxZoom;

    /**
     * The plain basemap the geometry editor draws over when imagery is off.
     *
     * Configured rather than compiled in, and empty by default. The editor used
     * to hardcode CARTO's dark-matter style; CARTO stopped serving it partway
     * through a working session and the editor had no basemap, no error and no
     * alternative. A tool whose availability depends on a third party nobody
     * chose, agreed terms with, or can swap out is a tool that stops working on
     * someone else's schedule.
     *
     * Left empty, the client draws its own flat dark canvas and makes no
     * network request at all. That is the right default for tracing: the shapes
     * matter, the streets behind them do not.
     */
    private final String baseTileUrl;
    private final String baseAttribution;
    private final Integer baseMaxZoom;

    public BasemapConfigController(
            @Value("${vsp.basemap.mapbox-access-token:}") String mapboxAccessToken,
            @Value("${vsp.basemap.satellite-tile-url:}") String satelliteTileUrl,
            @Value("${vsp.basemap.satellite-attribution:}") String satelliteAttribution,
            @Value("${vsp.basemap.satellite-max-zoom:0}") int satelliteMaxZoom,
            @Value("${vsp.basemap.base-tile-url:}") String baseTileUrl,
            @Value("${vsp.basemap.base-attribution:}") String baseAttribution,
            @Value("${vsp.basemap.base-max-zoom:0}") int baseMaxZoom) {
        this.mapboxAccessToken = mapboxAccessToken == null ? "" : mapboxAccessToken.trim();
        this.satelliteTileUrl = satelliteTileUrl == null ? "" : satelliteTileUrl.trim();
        this.satelliteAttribution = satelliteAttribution == null ? "" : satelliteAttribution.trim();
        // 0 means "unset". Most imagery services stop short of the client's
        // default of 22 — Esri's World Imagery tops out near 19 — and a client
        // that keeps asking past the last level gets 404s and a blank map at
        // exactly the zoom a golfer uses to look at a green.
        this.satelliteMaxZoom = satelliteMaxZoom > 0 ? satelliteMaxZoom : null;

        this.baseTileUrl = baseTileUrl == null ? "" : baseTileUrl.trim();
        this.baseAttribution = baseAttribution == null ? "" : baseAttribution.trim();
        this.baseMaxZoom = baseMaxZoom > 0 ? baseMaxZoom : null;
    }

    @GetMapping("/basemap")
    public ResponseEntity<BasemapConfigResponse> getBasemapConfig() {
        return ResponseEntity.ok(new BasemapConfigResponse(
                publishableToken(),
                satelliteTileUrl,
                satelliteAttribution,
                satelliteMaxZoom,
                baseTileUrl,
                baseAttribution,
                baseMaxZoom));
    }

    /**
     * The Mapbox token, or nothing when it is not one we may hand out.
     *
     * <p>A secret token is dropped rather than served. The deployment then
     * behaves exactly as an unconfigured one — no imagery, plainly stated —
     * which is a visible failure an operator will chase, unlike a credential
     * quietly copied onto every device.</p>
     */
    private String publishableToken() {
        if (mapboxAccessToken.isEmpty()) {
            return "";
        }
        if (mapboxAccessToken.startsWith(SECRET_TOKEN_PREFIX)) {
            log.error("vsp.basemap.mapbox-access-token is a SECRET token (sk.) and will not be "
                    + "served to clients. Configure a public token (pk.) instead. Satellite "
                    + "imagery stays disabled until this is corrected.");
            return "";
        }
        if (!mapboxAccessToken.startsWith(PUBLIC_TOKEN_PREFIX)) {
            log.warn("vsp.basemap.mapbox-access-token does not look like a Mapbox public token "
                    + "(expected a 'pk.' prefix). Serving it as configured.");
        }
        return mapboxAccessToken;
    }

    /**
     * What the client needs to resolve an imagery provider.
     *
     * <p>Deliberately the same three inputs the build-time defines carry, so the
     * client resolves them with the logic it already has and tests — including
     * its refusal to display operator imagery that arrives without attribution.
     * </p>
     */
    public record BasemapConfigResponse(
            String mapboxAccessToken,
            String satelliteTileUrl,
            String satelliteAttribution,
            Integer satelliteMaxZoom,
            /** The non-imagery basemap. Empty means "the client draws its own". */
            String baseTileUrl,
            String baseAttribution,
            Integer baseMaxZoom) {}
}
