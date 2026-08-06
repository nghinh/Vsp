package vnpt.vsp.module.identity.service;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PublicKey;
import java.security.interfaces.RSAPublicKey;
import java.time.Duration;
import java.util.Base64;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The JWKS fetcher, against a key set served over a real socket.
 *
 * <p>The behaviour that matters for security is in the failure cases: an
 * endpoint that answers 500, a {@code kid} nobody publishes, and a host that
 * cannot be reached all have to end in "no key", because the caller reads "no
 * key" as "refuse the token". Anything else here reintroduces the defect this
 * class was written to close.
 */
class HttpJwkSourceTest {

    private HttpServer server;
    private String jwksUri;
    private KeyPair keyPair;
    private final AtomicInteger fetches = new AtomicInteger();
    private volatile int statusCode = 200;
    private volatile String body;

    @BeforeEach
    void startServer() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        keyPair = generator.generateKeyPair();
        body = jwks("published-kid", (RSAPublicKey) keyPair.getPublic());

        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/keys", exchange -> {
            fetches.incrementAndGet();
            byte[] payload = body.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(statusCode, payload.length);
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(payload);
            }
        });
        server.start();
        jwksUri = "http://127.0.0.1:" + server.getAddress().getPort() + "/keys";
    }

    @AfterEach
    void stopServer() {
        server.stop(0);
    }

    private HttpJwkSource source() {
        return new HttpJwkSource(Duration.ofHours(1), Duration.ofMinutes(1), Duration.ofSeconds(2));
    }

    @Test
    @DisplayName("A published key is fetched and matches the provider's public key")
    void publishedKeyIsFetched() {
        Optional<PublicKey> key = source().findKey(jwksUri, "published-kid");

        assertThat(key).isPresent();
        assertThat(key.get()).isEqualTo(keyPair.getPublic());
    }

    @Test
    @DisplayName("The key set is fetched once and then served from cache")
    void keySetIsCached() {
        HttpJwkSource source = source();

        source.findKey(jwksUri, "published-kid");
        source.findKey(jwksUri, "published-kid");
        source.findKey(jwksUri, "published-kid");

        assertThat(fetches.get()).isEqualTo(1);
    }

    @Test
    @DisplayName("An unknown kid yields no key — and is not retried on every request")
    void unknownKeyIdYieldsNothing() {
        HttpJwkSource source = source();

        assertThat(source.findKey(jwksUri, "kid-nobody-published")).isEmpty();
        assertThat(source.findKey(jwksUri, "kid-nobody-published")).isEmpty();

        // One fetch: the first miss refreshes, the second is inside
        // min-refresh-interval, so an invented kid cannot be used to make this
        // application hammer the provider.
        assertThat(fetches.get()).isEqualTo(1);
    }

    @Test
    @DisplayName("An endpoint answering 500 yields no key")
    void serverErrorYieldsNothing() {
        statusCode = 500;

        assertThat(source().findKey(jwksUri, "published-kid")).isEmpty();
    }

    @Test
    @DisplayName("An unreachable endpoint yields no key rather than an exception")
    void unreachableEndpointYieldsNothing() {
        server.stop(0);

        assertThat(source().findKey(jwksUri, "published-kid")).isEmpty();
    }

    @Test
    @DisplayName("A malformed key set yields no key")
    void malformedKeySetYieldsNothing() {
        body = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"published-kid\"}]}";

        assertThat(source().findKey(jwksUri, "published-kid")).isEmpty();
    }

    @Test
    @DisplayName("A blank JWKS uri — an unconfigured provider — yields no key")
    void blankUriYieldsNothing() {
        assertThat(source().findKey("", "published-kid")).isEmpty();
        assertThat(source().findKey(null, "published-kid")).isEmpty();
    }

    @Test
    @DisplayName("A token with no kid resolves only when the provider publishes exactly one key")
    void missingKeyIdResolvesOnlyWhenUnambiguous() {
        assertThat(source().findKey(jwksUri, null)).isPresent();

        body = "{\"keys\":[" + jwk("kid-a", (RSAPublicKey) keyPair.getPublic()) + ","
                + jwk("kid-b", (RSAPublicKey) keyPair.getPublic()) + "]}";

        assertThat(source().findKey(jwksUri, null)).isEmpty();
    }

    private static String jwks(String kid, RSAPublicKey key) {
        return "{\"keys\":[" + jwk(kid, key) + "]}";
    }

    private static String jwk(String kid, RSAPublicKey key) {
        Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
        return "{\"kty\":\"RSA\",\"use\":\"sig\",\"alg\":\"RS256\",\"kid\":\"" + kid + "\","
                + "\"n\":\"" + encoder.encodeToString(key.getModulus().toByteArray()) + "\","
                + "\"e\":\"" + encoder.encodeToString(key.getPublicExponent().toByteArray()) + "\"}";
    }
}
