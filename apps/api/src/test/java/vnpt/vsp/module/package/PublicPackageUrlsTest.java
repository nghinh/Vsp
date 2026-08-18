package vnpt.vsp.module.pkg;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The manifest a phone downloads must name a host the phone can reach.
 *
 * <p>Read from the live API on 17 August 2026, Long Biên's Đường A:
 * {@code "tilesUrl": "http://localhost:8080/packages/1351/1.106.3/tiles/tiles.pmtiles"}.
 * On a phone, localhost is the phone. The build-time default was never
 * overridden in production and every manifest in the database carries it.</p>
 */
class PublicPackageUrlsTest {

    @AfterEach
    void clearRequest() {
        RequestContextHolder.resetRequestAttributes();
    }

    private static void arrivingAt(String scheme, String host, int port) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setScheme(scheme);
        request.setServerName(host);
        request.setServerPort(port);
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
    }

    @Test
    void aStoredLocalhostUrlIsServedOnTheHostTheClientReached() {
        arrivingAt("https", "vps-api.vnteki.com", 443);

        String rehosted = new PublicPackageUrls("").rehost(
                "http://localhost:8080/packages/1351/1.106.3/tiles/tiles.pmtiles");

        assertThat(rehosted).isEqualTo(
                "https://vps-api.vnteki.com/packages/1351/1.106.3/tiles/tiles.pmtiles");
    }

    @Test
    void theConfiguredCdnWinsOverTheRequest() {
        // A deployment with a CDN in front knows something the request does
        // not: that the files are not served from the API at all.
        arrivingAt("https", "vps-api.vnteki.com", 443);

        String rehosted = new PublicPackageUrls("https://cdn.vnptgolf.vn/").rehost(
                "http://localhost:8080/packages/1351/1.106.3/geometry");

        assertThat(rehosted).isEqualTo(
                "https://cdn.vnptgolf.vn/packages/1351/1.106.3/geometry");
    }

    @Test
    void outsideARequestNothingIsInvented() {
        // A scheduled rebuild has no client to answer. Guessing a host here
        // would write a wrong one into a row that outlives the guess.
        String stored = "http://localhost:8080/packages/1351/1.106.3/geometry";

        assertThat(new PublicPackageUrls("").rehost(stored)).isEqualTo(stored);
    }

    @Test
    void aUrlThatIsNotAPackageUrlIsLeftAlone() {
        arrivingAt("https", "vps-api.vnteki.com", 443);

        // This is a rehost, not a licence to rewrite arbitrary links.
        assertThat(new PublicPackageUrls("").rehost("https://osm.org/copyright"))
                .isEqualTo("https://osm.org/copyright");
    }

    @Test
    void nothingIsMadeOutOfNothing() {
        assertThat(new PublicPackageUrls("").rehost(null)).isNull();
        assertThat(new PublicPackageUrls("").rehost("")).isEmpty();
    }
}
