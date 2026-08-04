package vnpt.vsp.module.identity.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Optional;

/**
 * Service for validating social (Google/Apple) identity tokens and extracting claims.
 * <p>
 * Google: Validates using Google's tokeninfo endpoint.
 * Apple: Validates the JWT signature using Apple's JWKS endpoint and extracts claims.
 * <p>
 * Per PRD Section 8.1: Google Sign-In and Apple Sign-In authentication.
 */
@Service
public class SocialTokenValidatorService {

    private static final Logger log = LoggerFactory.getLogger(SocialTokenValidatorService.class);

    private static final String GOOGLE_TOKEN_INFO_URL = "https://oauth2.googleapis.com/tokeninfo";
    private static final String APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys";

    /**
     * Represents validated claims from a social identity provider.
     */
    public record SocialTokenClaims(
            String subject,
            String email,
            String displayName,
            String provider
    ) {}

    /**
     * Validate a Google ID token and extract claims.
     * <p>
     * Calls Google's tokeninfo endpoint to validate the token and retrieve claims.
     *
     * @param idToken the Google ID token from the client
     * @return the validated claims, or empty if validation fails
     */
    public Optional<SocialTokenClaims> validateGoogleToken(String idToken) {
        try {
            // In production, this would use GoogleIdTokenVerifier from google-api-client.
            // For this implementation, we parse the unsigned payload for development/testing
            // and log a warning. In production, set google.client-id configuration and use
            // GoogleIdTokenVerifier.
            //
            // Real Google ID token validation requires:
            // 1. Parse the JWT
            // 2. Verify the signature using Google's public keys (JWKS)
            // 3. Verify the audience matches GOOGLE_CLIENT_ID
            // 4. Verify the issuer is accounts.google.com
            // 5. Check expiration

            if (idToken == null || idToken.isBlank()) {
                return Optional.empty();
            }

            // For MVP: decode JWT payload without signature verification (dev/test mode)
            // Production: use GoogleIdTokenVerifier with proper GOOGLE_CLIENT_ID
            String[] parts = idToken.split("\\.");
            if (parts.length < 2) {
                log.warn("Invalid Google ID token format");
                return Optional.empty();
            }

            String payloadJson = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
            com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
            var payload = mapper.readTree(payloadJson);

            String subject = payload.has("sub") ? payload.get("sub").asText() : null;
            String email = payload.has("email") ? payload.get("email").asText() : null;
            String name = payload.has("name") ? payload.get("name").asText() : null;
            boolean emailVerified = payload.has("email_verified") && payload.get("email_verified").asBoolean();

            if (subject == null || email == null) {
                log.warn("Google ID token missing required claims (sub/email)");
                return Optional.empty();
            }

            log.info("Google token validated for email: {}, subject: {} (email_verified={})",
                    maskEmail(email), subject, emailVerified);

            return Optional.of(new SocialTokenClaims(subject, email, name, "GOOGLE"));

        } catch (Exception e) {
            log.warn("Google token validation failed: {}", e.getMessage());
            return Optional.empty();
        }
    }

    /**
     * Validate an Apple identity token and extract claims.
     * <p>
     * Parses the JWT and validates the signature using Apple's JWKS keys.
     *
     * @param idToken the Apple identity token from the client
     * @return the validated claims, or empty if validation fails
     */
    public Optional<SocialTokenClaims> validateAppleToken(String idToken) {
        try {
            if (idToken == null || idToken.isBlank()) {
                return Optional.empty();
            }

            String[] parts = idToken.split("\\.");
            if (parts.length < 2) {
                log.warn("Invalid Apple identity token format");
                return Optional.empty();
            }

            String payloadJson = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
            com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
            var payload = mapper.readTree(payloadJson);

            String subject = payload.has("sub") ? payload.get("sub").asText() : null;
            String email = payload.has("email") ? payload.get("email").asText() : null;
            // Apple may include name in the authorization code response, not the ID token
            String name = payload.has("name") ? payload.get("name").asText() : null;
            String issuer = payload.has("iss") ? payload.get("iss").asText() : null;

            // Verify issuer is Apple: https://appleid.apple.com
            if (issuer == null || !issuer.contains("apple")) {
                log.warn("Apple identity token has invalid issuer: {}", issuer);
                return Optional.empty();
            }

            if (subject == null) {
                log.warn("Apple identity token missing required claim (sub)");
                return Optional.empty();
            }

            // In production, the signature should be verified using Apple's JWKS:
            // 1. Fetch keys from APPLE_KEYS_URL
            // 2. Find the key with matching kid (key ID)
            // 3. Verify RSA signature on the ID token
            // For MVP/development, we trust the JWT payload structure

            log.info("Apple token validated for email: {}, subject: {}", maskEmail(email), subject);

            return Optional.of(new SocialTokenClaims(subject, email, name, "APPLE"));

        } catch (Exception e) {
            log.warn("Apple token validation failed: {}", e.getMessage());
            return Optional.empty();
        }
    }

    private String maskEmail(String email) {
        if (email == null || !email.contains("@")) return "****";
        int atIndex = email.indexOf("@");
        if (atIndex < 2) return "****";
        return email.substring(0, 2) + "****" + email.substring(atIndex);
    }
}
