package vnpt.vsp.module.pkg;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * Rewrites the URLs in a stored manifest onto a host the caller can reach.
 *
 * <p><strong>Why.</strong> {@code PackageGenerationService} writes absolute
 * URLs into the manifest row at build time, from
 * {@code vsp.packages.base-url}, whose default is
 * {@code http://localhost:8080/packages}. Nothing sets it in production, so
 * every manifest the live API serves says its tiles and geometry live at
 * {@code http://localhost:8080} — and on a phone, localhost is the phone.
 * Long Biên's manifest says exactly that today.</p>
 *
 * <p>The mobile client happens to survive it: it ignores these two fields and
 * builds file URLs from its own API base. That is luck, not design, and it
 * does not extend to the watch apps, the portal, or anything reading the
 * manifest as published. A URL that is wrong is wrong whether or not today's
 * reader looks at it.</p>
 *
 * <p><strong>At serve time, not build time.</strong> Rewriting when the
 * manifest is read fixes every package already sitting in the database —
 * Long Biên's among them — without rebuilding anything. Fixing the generator
 * alone would leave every existing row pointing at localhost until someone
 * rebuilt it, and nobody was going to.</p>
 *
 * <p>Where {@code vsp.packages.base-url} is configured it wins, because a
 * deployment with a CDN in front knows better than the request does. With no
 * configuration the origin the client actually reached is used, which is
 * right behind a tunnel and right on a laptop.</p>
 */
@Component
public class PublicPackageUrls {

    /** The path segment every package URL is anchored on. */
    private static final String ANCHOR = "/packages";

    private final String configuredBase;

    public PublicPackageUrls(
            @Value("${vsp.packages.public-base-url:}") String configuredBase) {
        this.configuredBase = trimSlash(configuredBase);
    }

    /**
     * The same URL, on a host the caller can reach.
     *
     * <p>Anything that is not a package URL is returned untouched: this is a
     * rehost, not a rewrite of arbitrary links.</p>
     */
    public String rehost(String stored) {
        if (stored == null || stored.isBlank()) {
            return stored;
        }
        int anchor = stored.indexOf(ANCHOR + "/");
        if (anchor < 0) {
            return stored;
        }
        String base = base();
        return base == null ? stored : base + stored.substring(anchor);
    }

    /**
     * Origin to serve from, or null when there is nothing better than what is
     * already stored.
     *
     * <p>Null rather than a guess when called outside a request — a scheduled
     * rebuild has no client to answer and must not invent one.</p>
     */
    private String base() {
        if (!configuredBase.isEmpty()) {
            return configuredBase;
        }
        if (RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes) {
            return trimSlash(ServletUriComponentsBuilder.fromCurrentContextPath()
                    .build()
                    .toUriString());
        }
        return null;
    }

    private static String trimSlash(String value) {
        if (value == null) {
            return "";
        }
        String trimmed = value.trim();
        while (trimmed.endsWith("/")) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
        }
        return trimmed;
    }
}
