package vnpt.vsp.module.identity.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Header;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.Locator;
import io.jsonwebtoken.ProtectedHeader;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.security.Key;
import java.time.Duration;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.Optional;
import java.util.Set;

/**
 * Verifies Google and Apple identity tokens and extracts their claims.
 *
 * <p>A social identity token is a bearer of someone's account. Until this class
 * was rewritten it was read, not verified: both methods split the compact JWT on
 * {@code '.'}, base64-decoded the middle segment and believed whatever JSON came
 * out. The signature was never checked against anything, the audience was never
 * looked at, {@code exp} was never compared to the clock, and Apple's issuer
 * check was {@code issuer.contains("apple")} — which
 * {@code "https://apple.attacker.example"} satisfies. Anyone who could reach
 * {@code POST /auth/google} could hand over a token they had typed themselves,
 * naming any {@code sub} and any {@code email}, and
 * {@code IdentityServiceImpl.authenticateWithGoogle} would link that subject to
 * the matching account and mint real VSP tokens for it. That is account takeover
 * of every account on the platform, by email address, with no secret required.
 * The Apple method's javadoc claimed it verified the signature against Apple's
 * JWKS; it did not.
 *
 * <p>What is checked now, for both providers:
 * <ol>
 *   <li>the JWS signature, against the key the provider publishes under the
 *       token's {@code kid} at its JWKS endpoint (see {@link JwkSource});</li>
 *   <li>{@code iss} against the issuers configured for that provider;</li>
 *   <li>{@code aud} against the client ids configured for this environment — a
 *       token minted for a different application is a valid token, and without
 *       this check it would be accepted here;</li>
 *   <li>{@code exp}/{@code nbf}, with a small configured clock skew;</li>
 *   <li>{@code sub}, which must be present — it is the account key.</li>
 * </ol>
 *
 * <p>Every failure returns {@link Optional#empty()}, which the caller turns into
 * {@code VSP-ERR-AUTH-014}/{@code -015}. There is no path that returns claims
 * from a token whose signature was not checked: an unconfigured provider, an
 * unreachable key set and an unknown {@code kid} all refuse. Social login that
 * is switched off is an inconvenience; social login that trusts unverified
 * tokens is a breach.
 *
 * <p>Per PRD Section 8.1: Google Sign-In and Apple Sign-In authentication.
 */
@Service
public class SocialTokenValidatorService {

    private static final Logger log = LoggerFactory.getLogger(SocialTokenValidatorService.class);

    /** Represents validated claims from a social identity provider. */
    public record SocialTokenClaims(
            String subject,
            String email,
            String displayName,
            String provider
    ) {}

    /**
     * One provider's trust anchors: where its keys live, who it claims to be,
     * and which client ids of ours it is allowed to have minted a token for.
     */
    private record Provider(String name, String jwksUri, Set<String> issuers, Set<String> audiences) {

        boolean isConfigured() {
            return !jwksUri.isBlank() && !issuers.isEmpty() && !audiences.isEmpty();
        }
    }

    private final JwkSource jwkSource;
    private final Provider google;
    private final Provider apple;
    private final long clockSkewSeconds;

    public SocialTokenValidatorService(
            JwkSource jwkSource,
            @Value("${vsp.auth.social.google.jwks-uri:https://www.googleapis.com/oauth2/v3/certs}")
            String googleJwksUri,
            @Value("${vsp.auth.social.google.issuers:https://accounts.google.com,accounts.google.com}")
            String googleIssuers,
            @Value("${vsp.auth.social.google.client-ids:}")
            String googleClientIds,
            @Value("${vsp.auth.social.apple.jwks-uri:https://appleid.apple.com/auth/keys}")
            String appleJwksUri,
            @Value("${vsp.auth.social.apple.issuers:https://appleid.apple.com}")
            String appleIssuers,
            @Value("${vsp.auth.social.apple.client-ids:}")
            String appleClientIds,
            @Value("${vsp.auth.social.clock-skew:PT1M}")
            Duration clockSkew) {

        this.jwkSource = jwkSource;
        this.google = new Provider("GOOGLE", googleJwksUri, split(googleIssuers), split(googleClientIds));
        this.apple = new Provider("APPLE", appleJwksUri, split(appleIssuers), split(appleClientIds));
        this.clockSkewSeconds = clockSkew.toSeconds();

        warnIfUnconfigured(google, "vsp.auth.social.google.client-ids");
        warnIfUnconfigured(apple, "vsp.auth.social.apple.client-ids");
    }

    /**
     * Verify a Google ID token and extract its claims.
     *
     * @param idToken the Google ID token from the client
     * @return the verified claims, or empty if the token is not genuine, not
     *         ours, not current, or cannot be checked at all
     */
    public Optional<SocialTokenClaims> validateGoogleToken(String idToken) {
        return verify(google, idToken).flatMap(claims -> {
            String email = claims.get("email", String.class);
            if (email == null || email.isBlank()) {
                log.warn("Google ID token carries no email claim");
                return Optional.empty();
            }
            // The account is matched to an existing one by email, so an
            // unverified address would let a Google account created for
            // someone else's address claim their VSP account.
            if (!isTrue(claims.get("email_verified"))) {
                log.warn("Google ID token for {} is not email_verified", maskEmail(email));
                return Optional.empty();
            }
            return Optional.of(new SocialTokenClaims(
                    claims.getSubject(), email, claims.get("name", String.class), "GOOGLE"));
        });
    }

    /**
     * Verify an Apple identity token and extract its claims.
     *
     * <p>Apple omits {@code email} on every sign-in after the first, and the
     * name never appears in the identity token at all, so both are optional
     * here — {@code sub} is what identifies the account.
     *
     * @param idToken the Apple identity token from the client
     * @return the verified claims, or empty if the token is not genuine, not
     *         ours, not current, or cannot be checked at all
     */
    public Optional<SocialTokenClaims> validateAppleToken(String idToken) {
        return verify(apple, idToken).flatMap(claims -> {
            String email = claims.get("email", String.class);
            if (email != null && !email.isBlank() && !isTrue(claims.get("email_verified"))) {
                log.warn("Apple identity token for {} is not email_verified", maskEmail(email));
                return Optional.empty();
            }
            return Optional.of(new SocialTokenClaims(
                    claims.getSubject(), email, claims.get("name", String.class), "APPLE"));
        });
    }

    /**
     * The whole check: signature, issuer, audience, expiry, subject.
     *
     * <p>The key locator is what makes the signature check real. It answers only
     * with keys the provider publishes, so a token signed with a key of the
     * caller's own choosing has nothing to verify against and jjwt refuses it —
     * as it refuses an {@code alg: none} token, which carries no signature to
     * check and is the shape this method has to be proof against above all
     * others.
     */
    private Optional<Claims> verify(Provider provider, String idToken) {
        if (idToken == null || idToken.isBlank()) {
            return Optional.empty();
        }
        if (!provider.isConfigured()) {
            log.error("{} sign-in is not configured (no client id / issuer / JWKS uri) — refusing the token. "
                    + "Set vsp.auth.social.{}.client-ids for this environment.",
                    provider.name(), provider.name().toLowerCase());
            return Optional.empty();
        }
        try {
            Jws<Claims> jws = Jwts.parser()
                    .keyLocator(keyLocator(provider))
                    .clockSkewSeconds(clockSkewSeconds)
                    .build()
                    .parseSignedClaims(idToken);

            Claims claims = jws.getPayload();

            String issuer = claims.getIssuer();
            if (issuer == null || !provider.issuers().contains(issuer)) {
                log.warn("{} token issuer {} is not one of {}", provider.name(), issuer, provider.issuers());
                return Optional.empty();
            }

            Set<String> audience = claims.getAudience();
            if (audience == null || audience.stream().noneMatch(provider.audiences()::contains)) {
                log.warn("{} token audience {} is not a client id of this deployment",
                        provider.name(), audience);
                return Optional.empty();
            }

            String subject = claims.getSubject();
            if (subject == null || subject.isBlank()) {
                log.warn("{} token carries no subject", provider.name());
                return Optional.empty();
            }

            log.info("{} token verified for subject {} (kid={})",
                    provider.name(), subject, jws.getHeader().getKeyId());
            return Optional.of(claims);

        } catch (JwtException e) {
            // Bad signature, alg: none, expired, malformed, or no key for the
            // kid — all of them mean the same thing to the caller.
            log.warn("{} token rejected: {}", provider.name(), e.getMessage());
            return Optional.empty();
        } catch (Exception e) {
            log.warn("{} token verification failed: {}", provider.name(), e.toString());
            return Optional.empty();
        }
    }

    private Locator<Key> keyLocator(Provider provider) {
        return new Locator<>() {
            @Override
            public Key locate(Header header) {
                String keyId = header instanceof ProtectedHeader protectedHeader
                        ? protectedHeader.getKeyId()
                        : null;
                return jwkSource.findKey(provider.jwksUri(), keyId)
                        .map(Key.class::cast)
                        .orElseThrow(() -> new io.jsonwebtoken.security.SignatureException(
                                "No published " + provider.name() + " signing key for kid=" + keyId));
            }
        };
    }

    /** {@code email_verified} arrives as a boolean from Google and, historically, as a string from Apple. */
    private static boolean isTrue(Object claim) {
        return Boolean.TRUE.equals(claim) || "true".equals(String.valueOf(claim));
    }

    private static Set<String> split(String commaSeparated) {
        if (commaSeparated == null || commaSeparated.isBlank()) {
            return Set.of();
        }
        return Arrays.stream(commaSeparated.split(","))
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new));
    }

    private void warnIfUnconfigured(Provider provider, String property) {
        if (!provider.isConfigured()) {
            log.warn("{} sign-in is disabled: {} is not set, so every {} token will be refused.",
                    provider.name(), property, provider.name());
        }
    }

    private static String maskEmail(String email) {
        if (email == null || !email.contains("@")) return "****";
        int atIndex = email.indexOf("@");
        if (atIndex < 2) return "****";
        return email.substring(0, 2) + "****" + email.substring(atIndex);
    }
}
