package vnpt.vsp.module.identity.service;

import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PublicKey;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * What a social identity token has to survive to become a VSP session.
 *
 * <p>These tests exist because the previous implementation ran none of them:
 * it base64-decoded the token's payload and returned whatever claims it found.
 * Every "rejected" case below — an unsigned token, a token signed with a key
 * the attacker generated, a token minted for another application, a token that
 * expired last year, {@code iss: https://apple.attacker.example} — was accepted,
 * and each one is a working account takeover of any account whose email address
 * the attacker knows.
 *
 * <p>The provider's key is generated here rather than fetched, so the tests
 * describe the verification and not Google's uptime. That is the whole reason
 * {@link JwkSource} is an interface.
 */
class SocialTokenValidatorServiceTest {

    private static final String GOOGLE_JWKS = "https://jwks.test/google";
    private static final String APPLE_JWKS = "https://jwks.test/apple";
    private static final String GOOGLE_ISSUER = "https://accounts.google.com";
    private static final String APPLE_ISSUER = "https://appleid.apple.com";
    private static final String GOOGLE_CLIENT_ID = "vsp-google-client.apps.googleusercontent.com";
    private static final String APPLE_CLIENT_ID = "vn.vnpt.vsp";
    private static final String KID = "vsp-test-key";

    /** The provider's keypair: the private half signs, the public half is published. */
    private static KeyPair providerKeys;
    /** A keypair the provider never published — an attacker's own. */
    private static KeyPair attackerKeys;

    @BeforeAll
    static void generateKeys() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        providerKeys = generator.generateKeyPair();
        attackerKeys = generator.generateKeyPair();
    }

    /** A key source that publishes exactly the provider's key, under {@link #KID}. */
    private static JwkSource publishing(PublicKey key) {
        return (jwksUri, keyId) -> KID.equals(keyId) ? Optional.of(key) : Optional.empty();
    }

    /** A key source that can reach nothing — the provider is down, or DNS is. */
    private static final JwkSource UNREACHABLE = (jwksUri, keyId) -> Optional.empty();

    private static SocialTokenValidatorService validator(JwkSource keys) {
        return validator(keys, GOOGLE_CLIENT_ID, APPLE_CLIENT_ID);
    }

    private static SocialTokenValidatorService validator(JwkSource keys,
                                                        String googleClientIds,
                                                        String appleClientIds) {
        return new SocialTokenValidatorService(
                keys,
                GOOGLE_JWKS, GOOGLE_ISSUER + ",accounts.google.com", googleClientIds,
                APPLE_JWKS, APPLE_ISSUER, appleClientIds,
                Duration.ofMinutes(1));
    }

    /**
     * A well-formed token, which individual tests then spoil one field at a
     * time: a null {@code signingKey} produces the unsigned {@code alg: none}
     * shape, everything else is a genuine RS256 signature.
     */
    private static String token(java.security.PrivateKey signingKey,
                                String kid,
                                String issuer,
                                String audience,
                                String subject,
                                Instant expiry,
                                Map<String, Object> extraClaims) {
        var builder = Jwts.builder()
                .header().keyId(kid).and()
                .issuer(issuer)
                .subject(subject)
                .issuedAt(Date.from(Instant.now().minusSeconds(30)))
                .expiration(Date.from(expiry));
        if (audience != null) {
            builder = builder.audience().add(audience).and();
        }
        extraClaims.forEach(builder::claim);
        return signingKey == null
                ? builder.compact()                       // alg: none — no signature at all
                : builder.signWith(signingKey, Jwts.SIG.RS256).compact();
    }

    private static String googleToken() {
        return token(providerKeys.getPrivate(), KID, GOOGLE_ISSUER, GOOGLE_CLIENT_ID, "google-subject-1",
                Instant.now().plusSeconds(600),
                Map.of("email", "golfer@example.com", "email_verified", true, "name", "Real Golfer"));
    }

    private static String appleToken() {
        return token(providerKeys.getPrivate(), KID, APPLE_ISSUER, APPLE_CLIENT_ID, "apple-subject-1",
                Instant.now().plusSeconds(600),
                Map.of("email", "golfer@example.com", "email_verified", "true"));
    }

    @Nested
    @DisplayName("A genuine token")
    class Genuine {

        @Test
        @DisplayName("Google: signed by the provider, for this client, unexpired — accepted")
        void googleTokenIsAccepted() {
            Optional<SocialTokenValidatorService.SocialTokenClaims> claims =
                    validator(publishing(providerKeys.getPublic())).validateGoogleToken(googleToken());

            assertThat(claims).isPresent();
            assertThat(claims.get().subject()).isEqualTo("google-subject-1");
            assertThat(claims.get().email()).isEqualTo("golfer@example.com");
            assertThat(claims.get().displayName()).isEqualTo("Real Golfer");
            assertThat(claims.get().provider()).isEqualTo("GOOGLE");
        }

        @Test
        @DisplayName("Apple: accepted, and its email_verified may be the string \"true\"")
        void appleTokenIsAccepted() {
            Optional<SocialTokenValidatorService.SocialTokenClaims> claims =
                    validator(publishing(providerKeys.getPublic())).validateAppleToken(appleToken());

            assertThat(claims).isPresent();
            assertThat(claims.get().subject()).isEqualTo("apple-subject-1");
            assertThat(claims.get().provider()).isEqualTo("APPLE");
        }

        @Test
        @DisplayName("Apple omits the email on every sign-in after the first — still accepted")
        void appleTokenWithoutEmailIsAccepted() {
            String noEmail = token(providerKeys.getPrivate(), KID, APPLE_ISSUER, APPLE_CLIENT_ID,
                    "apple-subject-1", Instant.now().plusSeconds(600), Map.of());

            var claims = validator(publishing(providerKeys.getPublic())).validateAppleToken(noEmail);

            assertThat(claims).isPresent();
            assertThat(claims.get().email()).isNull();
        }

        @Test
        @DisplayName("The second of the deployment's client ids is also ours")
        void anySecondClientIdIsAccepted() {
            var service = validator(publishing(providerKeys.getPublic()),
                    "vsp-ios.apps.googleusercontent.com," + GOOGLE_CLIENT_ID, APPLE_CLIENT_ID);

            assertThat(service.validateGoogleToken(googleToken())).isPresent();
        }
    }

    @Nested
    @DisplayName("A forged token")
    class Forged {

        /**
         * The exact attack the old implementation permitted: type a JWT, do not
         * sign it, name any account you like.
         */
        @Test
        @DisplayName("An unsigned token (alg: none) is refused")
        void unsignedTokenIsRefused() {
            String unsigned = token(null, KID, GOOGLE_ISSUER, GOOGLE_CLIENT_ID, "victim-subject",
                    Instant.now().plusSeconds(600),
                    Map.of("email", "victim@example.com", "email_verified", true));

            assertThat(validator(publishing(providerKeys.getPublic())).validateGoogleToken(unsigned))
                    .isEmpty();
        }

        @Test
        @DisplayName("A token signed with the attacker's own key is refused")
        void tokenSignedWithAnUnpublishedKeyIsRefused() {
            String forged = token(attackerKeys.getPrivate(), KID, GOOGLE_ISSUER, GOOGLE_CLIENT_ID,
                    "victim-subject", Instant.now().plusSeconds(600),
                    Map.of("email", "victim@example.com", "email_verified", true));

            assertThat(validator(publishing(providerKeys.getPublic())).validateGoogleToken(forged))
                    .isEmpty();
        }

        @Test
        @DisplayName("A token naming a kid the provider does not publish is refused")
        void unknownKeyIdIsRefused() {
            String forged = token(attackerKeys.getPrivate(), "attacker-kid", GOOGLE_ISSUER,
                    GOOGLE_CLIENT_ID, "victim-subject", Instant.now().plusSeconds(600),
                    Map.of("email", "victim@example.com", "email_verified", true));

            assertThat(validator(publishing(providerKeys.getPublic())).validateGoogleToken(forged))
                    .isEmpty();
        }

        @Test
        @DisplayName("Payload-only garbage is refused rather than parsed")
        void garbageIsRefused() {
            var service = validator(publishing(providerKeys.getPublic()));

            assertThat(service.validateGoogleToken("not.a.jwt")).isEmpty();
            assertThat(service.validateGoogleToken("")).isEmpty();
            assertThat(service.validateGoogleToken(null)).isEmpty();
            assertThat(service.validateAppleToken("eyJhbGciOiJub25lIn0.e30.")).isEmpty();
        }
    }

    @Nested
    @DisplayName("A genuine token that is not ours to accept")
    class NotOurs {

        @Test
        @DisplayName("A token minted for another application is refused")
        void wrongAudienceIsRefused() {
            String otherApp = token(providerKeys.getPrivate(), KID, GOOGLE_ISSUER,
                    "someone-elses-app.apps.googleusercontent.com", "google-subject-1",
                    Instant.now().plusSeconds(600),
                    Map.of("email", "golfer@example.com", "email_verified", true));

            assertThat(validator(publishing(providerKeys.getPublic())).validateGoogleToken(otherApp))
                    .isEmpty();
        }

        @Test
        @DisplayName("A token with no audience at all is refused")
        void missingAudienceIsRefused() {
            String noAudience = token(providerKeys.getPrivate(), KID, GOOGLE_ISSUER, null,
                    "google-subject-1", Instant.now().plusSeconds(600),
                    Map.of("email", "golfer@example.com", "email_verified", true));

            assertThat(validator(publishing(providerKeys.getPublic())).validateGoogleToken(noAudience))
                    .isEmpty();
        }

        /**
         * The old Apple check was {@code issuer.contains("apple")}, which this
         * issuer satisfies.
         */
        @Test
        @DisplayName("iss: https://apple.attacker.example is refused")
        void issuerMerelyContainingAppleIsRefused() {
            String impostor = token(providerKeys.getPrivate(), KID, "https://apple.attacker.example",
                    APPLE_CLIENT_ID, "apple-subject-1", Instant.now().plusSeconds(600), Map.of());

            assertThat(validator(publishing(providerKeys.getPublic())).validateAppleToken(impostor))
                    .isEmpty();
        }

        @Test
        @DisplayName("An expired token is refused")
        void expiredTokenIsRefused() {
            String expired = token(providerKeys.getPrivate(), KID, GOOGLE_ISSUER, GOOGLE_CLIENT_ID,
                    "google-subject-1", Instant.now().minusSeconds(3600),
                    Map.of("email", "golfer@example.com", "email_verified", true));

            assertThat(validator(publishing(providerKeys.getPublic())).validateGoogleToken(expired))
                    .isEmpty();
        }

        @Test
        @DisplayName("A Google token whose email is not verified is refused — the email is what links accounts")
        void unverifiedEmailIsRefused() {
            String unverified = token(providerKeys.getPrivate(), KID, GOOGLE_ISSUER, GOOGLE_CLIENT_ID,
                    "google-subject-1", Instant.now().plusSeconds(600),
                    Map.of("email", "victim@example.com", "email_verified", false));

            assertThat(validator(publishing(providerKeys.getPublic())).validateGoogleToken(unverified))
                    .isEmpty();
        }
    }

    @Nested
    @DisplayName("When the check cannot be made, it fails closed")
    class FailsClosed {

        @Test
        @DisplayName("A token the provider really signed is refused if its key set is unreachable")
        void unreachableKeySetRefusesAGenuineToken() {
            assertThat(validator(UNREACHABLE).validateGoogleToken(googleToken())).isEmpty();
            assertThat(validator(UNREACHABLE).validateAppleToken(appleToken())).isEmpty();
        }

        @Test
        @DisplayName("A provider with no configured client id refuses every token, however genuine")
        void unconfiguredProviderRefusesEverything() {
            var service = validator(publishing(providerKeys.getPublic()), "", "");

            assertThat(service.validateGoogleToken(googleToken())).isEmpty();
            assertThat(service.validateAppleToken(appleToken())).isEmpty();
        }
    }
}
