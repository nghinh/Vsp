package vnpt.vsp.api.config;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for what the app is told about satellite imagery.
 *
 * <p>The assertion that matters is the secret-token one. This endpoint exists
 * to hand a credential to every phone that opens the app, which is safe for a
 * Mapbox <em>public</em> token — that is what public tokens are for, and it was
 * already being shipped inside the APK — and catastrophic for a secret one. An
 * operator pasting {@code sk.…} into the wrong line of a config file is an
 * ordinary mistake, and the failure it would cause is silent: imagery would
 * work, so nobody would look, while full account credentials sat on every
 * device.</p>
 */
class BasemapConfigControllerTest {

    private BasemapConfigController controller(String token, String tileUrl, String attribution) {
        return new BasemapConfigController(token, tileUrl, attribution, 0, "", "", 0);
    }

    private BasemapConfigController.BasemapConfigResponse configOf(
            String token, String tileUrl, String attribution) {
        return controller(token, tileUrl, attribution).getBasemapConfig().getBody();
    }

    // ─── The refusal ───────────────────────────────────────────────────────

    @Test
    void aSecretMapboxTokenIsNeverServed() {
        var config = configOf("sk.eyJhbGciOiJIUzI1NiJ9.secret", "", "");

        // Withholding it makes the deployment behave as an unconfigured one:
        // no imagery, plainly stated, which someone will chase. Serving it
        // would work perfectly and quietly leak the account.
        assertThat(config.mapboxAccessToken()).isEmpty();
    }

    @Test
    void aPublicMapboxTokenIsServed() {
        var config = configOf("pk.eyJhbGciOiJIUzI1NiJ9.public", "", "");

        assertThat(config.mapboxAccessToken()).isEqualTo("pk.eyJhbGciOiJIUzI1NiJ9.public");
    }

    // ─── Unconfigured is a valid state ─────────────────────────────────────

    @Test
    void anUnconfiguredDeploymentSaysSoRatherThanFailing() {
        var config = configOf("", "", "");

        // The app's degrade path — measuring over a plain canvas — is the
        // default experience for a deployment that has bought no imagery.
        assertThat(config.mapboxAccessToken()).isEmpty();
        assertThat(config.satelliteTileUrl()).isEmpty();
        assertThat(config.satelliteAttribution()).isEmpty();
    }

    @Test
    void nullConfigurationIsTreatedAsUnset() {
        var config = configOf(null, null, null);

        assertThat(config.mapboxAccessToken()).isEmpty();
        assertThat(config.satelliteTileUrl()).isEmpty();
    }

    @Test
    void surroundingWhitespaceDoesNotBecomeAToken() {
        // A token pasted into YAML with a trailing newline is still a token,
        // and a tile URL that is only spaces is not a provider.
        var config = configOf("  pk.abc  ", "   ", "   ");

        assertThat(config.mapboxAccessToken()).isEqualTo("pk.abc");
        assertThat(config.satelliteTileUrl()).isEmpty();
    }

    // ─── Operator imagery ──────────────────────────────────────────────────

    @Test
    void operatorImageryIsPassedThroughWithItsAttribution() {
        var config = configOf(
                "", "https://tiles.example.vn/{z}/{x}/{y}.jpg", "© Example Imagery");

        // The client refuses to draw imagery it cannot credit, so both halves
        // have to survive the trip.
        assertThat(config.satelliteTileUrl()).isEqualTo("https://tiles.example.vn/{z}/{x}/{y}.jpg");
        assertThat(config.satelliteAttribution()).isEqualTo("© Example Imagery");
    }

    // ─── Zoom ──────────────────────────────────────────────────────────────

    @Test
    void anEndpointsRealZoomCeilingIsPassedOn() {
        var config = new BasemapConfigController("", "https://t/{z}/{y}/{x}", "© X", 19, "", "", 0)
                .getBasemapConfig().getBody();

        // Esri's World Imagery stops near 19. A client that keeps asking past
        // the last level gets 404s and shows nothing at exactly the zoom a
        // golfer uses to look at a green.
        assertThat(config.satelliteMaxZoom()).isEqualTo(19);
    }

    @Test
    void zeroMeansUnsetRatherThanZoomZero() {
        var config = new BasemapConfigController("", "https://t/{z}/{y}/{x}", "© X", 0, "", "", 0)
                .getBasemapConfig().getBody();

        // A literal 0 would tell the client to render one tile for the planet.
        assertThat(config.satelliteMaxZoom()).isNull();
    }

    // ─── The plain basemap ──────────────────────────────────────────────────

    @Test
    void thePlainBasemapIsEmptyUnlessConfigured() {
        // The default, and on purpose. Two components used to hardcode CARTO's
        // dark-matter style; CARTO stopped serving it during a working session
        // and there was no way to point them elsewhere without a release. Empty
        // here means the client draws its own canvas and calls nobody.
        var config = new BasemapConfigController("", "", "", 0, "", "", 0)
                .getBasemapConfig().getBody();

        assertThat(config.baseTileUrl()).isEmpty();
        assertThat(config.baseAttribution()).isEmpty();
        assertThat(config.baseMaxZoom()).isNull();
    }

    @Test
    void thePlainBasemapIsPassedThroughWhenConfigured() {
        var config = new BasemapConfigController(
                "", "", "", 0, "https://tiles/{z}/{x}/{y}.png", "© Nhà cung cấp", 18)
                .getBasemapConfig().getBody();

        assertThat(config.baseTileUrl()).isEqualTo("https://tiles/{z}/{x}/{y}.png");
        assertThat(config.baseAttribution()).isEqualTo("© Nhà cung cấp");
        assertThat(config.baseMaxZoom()).isEqualTo(18);
    }

    @Test
    void aZeroMaxZoomMeansUnsetRatherThanZoomZero() {
        var config = new BasemapConfigController("", "", "", 0, "https://t/{z}/{x}/{y}", "© X", 0)
                .getBasemapConfig().getBody();

        // A literal 0 would tell the client to render one tile for the planet.
        assertThat(config.baseMaxZoom()).isNull();
    }
}
