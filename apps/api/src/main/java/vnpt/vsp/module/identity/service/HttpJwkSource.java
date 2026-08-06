package vnpt.vsp.module.identity.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigInteger;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.RSAPublicKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Fetches and caches an identity provider's JWKS key set over HTTPS.
 *
 * <p>Caching is not an optimisation here, it is what keeps a sign-in from
 * depending on a third party being reachable at that instant: keys are fetched
 * once and reused for {@link #cacheTtl}, and a key set that is still held is
 * preferred over a failed refresh. Providers rotate keys on the order of days,
 * so a cached set is the normal case and a fetch is the exception.
 *
 * <p>A {@code kid} that is not in the cached set triggers at most one refetch
 * per {@link #minRefreshInterval}, which is what makes rotation land without
 * letting a caller who invents key ids turn every request into an outbound
 * fetch.
 *
 * <p>When the key set cannot be fetched at all and nothing is cached, this
 * returns empty and the token is refused. That is deliberate: the alternative —
 * accepting a token whose signature nobody checked — is the defect this class
 * exists to close.
 */
@Component
public class HttpJwkSource implements JwkSource {

    private static final Logger log = LoggerFactory.getLogger(HttpJwkSource.class);

    private final HttpClient httpClient;
    private final ObjectMapper mapper = new ObjectMapper();
    private final Map<String, KeySet> cache = new ConcurrentHashMap<>();

    private final Duration cacheTtl;
    private final Duration minRefreshInterval;
    private final Duration requestTimeout;

    public HttpJwkSource(
            @Value("${vsp.auth.social.jwks.cache-ttl:PT1H}") Duration cacheTtl,
            @Value("${vsp.auth.social.jwks.min-refresh-interval:PT1M}") Duration minRefreshInterval,
            @Value("${vsp.auth.social.jwks.request-timeout:PT5S}") Duration requestTimeout) {
        this.cacheTtl = cacheTtl;
        this.minRefreshInterval = minRefreshInterval;
        this.requestTimeout = requestTimeout;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(requestTimeout)
                .followRedirects(HttpClient.Redirect.NEVER)
                .build();
    }

    @Override
    public Optional<PublicKey> findKey(String jwksUri, String keyId) {
        if (jwksUri == null || jwksUri.isBlank()) {
            return Optional.empty();
        }
        KeySet cached = cache.get(jwksUri);
        Optional<PublicKey> hit = select(cached, keyId);
        if (hit.isPresent() && !cached.isStale(cacheTtl)) {
            return hit;
        }
        // Either nothing cached, or the cached set is stale, or it does not hold
        // this kid — the provider may have rotated. Refetch, but not more often
        // than minRefreshInterval, so an unknown kid cannot be used as a lever
        // to make this application hammer the provider.
        if (cached == null || cached.olderThan(minRefreshInterval)) {
            KeySet fetched = fetch(jwksUri);
            if (fetched != null) {
                cache.put(jwksUri, fetched);
                return select(fetched, keyId);
            }
        }
        // The refresh failed or was suppressed. A key we already hold is still
        // a key the provider published, so prefer it over refusing; holding
        // nothing means refusing.
        return hit;
    }

    private Optional<PublicKey> select(KeySet keySet, String keyId) {
        if (keySet == null) {
            return Optional.empty();
        }
        if (keyId != null && !keyId.isBlank()) {
            return Optional.ofNullable(keySet.keys().get(keyId));
        }
        // A token with no kid is only unambiguous if the provider publishes one
        // key. Guessing among several would mean trying each, which is how a
        // signature check turns into an oracle.
        return keySet.keys().size() == 1
                ? keySet.keys().values().stream().findFirst()
                : Optional.empty();
    }

    private KeySet fetch(String jwksUri) {
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(jwksUri))
                    .timeout(requestTimeout)
                    .header("Accept", "application/json")
                    .GET()
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                log.warn("JWKS fetch from {} returned HTTP {}", jwksUri, response.statusCode());
                return null;
            }
            Map<String, PublicKey> keys = parse(response.body());
            if (keys.isEmpty()) {
                log.warn("JWKS at {} held no usable keys", jwksUri);
                return null;
            }
            log.info("Fetched {} signing key(s) from {}", keys.size(), jwksUri);
            return new KeySet(keys, Instant.now());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.warn("JWKS fetch from {} interrupted", jwksUri);
            return null;
        } catch (Exception e) {
            log.warn("JWKS fetch from {} failed: {}", jwksUri, e.toString());
            return null;
        }
    }

    /** Parses a JWKS document into the RSA keys it publishes, by {@code kid}. */
    private Map<String, PublicKey> parse(String body) throws Exception {
        Map<String, PublicKey> keys = new LinkedHashMap<>();
        JsonNode root = mapper.readTree(body);
        JsonNode jwks = root.path("keys");
        if (!jwks.isArray()) {
            return keys;
        }
        for (JsonNode jwk : jwks) {
            String kty = jwk.path("kty").asText("");
            String use = jwk.path("use").asText("sig");
            if (!"RSA".equals(kty) || !"sig".equals(use)) {
                continue;
            }
            String kid = jwk.path("kid").asText(null);
            String modulus = jwk.path("n").asText(null);
            String exponent = jwk.path("e").asText(null);
            if (kid == null || modulus == null || exponent == null) {
                continue;
            }
            try {
                keys.put(kid, rsaKey(modulus, exponent));
            } catch (Exception e) {
                log.warn("Skipping unusable JWK {}: {}", kid, e.toString());
            }
        }
        return keys;
    }

    private static PublicKey rsaKey(String modulus, String exponent) throws Exception {
        Base64.Decoder decoder = Base64.getUrlDecoder();
        BigInteger n = new BigInteger(1, decoder.decode(modulus));
        BigInteger e = new BigInteger(1, decoder.decode(exponent));
        return KeyFactory.getInstance("RSA").generatePublic(new RSAPublicKeySpec(n, e));
    }

    /** One provider's key set and when it was fetched. */
    private record KeySet(Map<String, PublicKey> keys, Instant fetchedAt) {

        boolean isStale(Duration ttl) {
            return fetchedAt.plus(ttl).isBefore(Instant.now());
        }

        boolean olderThan(Duration interval) {
            return fetchedAt.plus(interval).isBefore(Instant.now());
        }
    }
}
