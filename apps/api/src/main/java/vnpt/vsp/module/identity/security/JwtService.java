package vnpt.vsp.module.identity.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Date;

/**
 * Service for JWT token generation and validation.
 * Per Architecture Section 12: OAuth/OIDC-compatible identity, short-lived access tokens.
 */
@Service
public class JwtService {

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);

    private static final String ACCESS_TOKEN_SUBJECT = "access";
    private static final String REFRESH_TOKEN_SUBJECT = "refresh";

    @Value("${security.jwt.secret}")
    private String jwtSecret;

    @Value("${security.jwt.access-token-expiration-ms:3600000}")  // 1 hour default
    private long accessTokenExpirationMs;

    @Value("${security.jwt.refresh-token-expiration-ms:604800000}")  // 7 days default
    private long refreshTokenExpirationMs;

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Generate an access token for the given golfer account ID.
     */
    public String generateAccessToken(Long golferAccountId) {
        return generateToken(golferAccountId, ACCESS_TOKEN_SUBJECT, accessTokenExpirationMs);
    }

    /**
     * Generate a refresh token for the given golfer account ID.
     */
    public String generateRefreshToken(Long golferAccountId) {
        return generateToken(golferAccountId, REFRESH_TOKEN_SUBJECT, refreshTokenExpirationMs);
    }

    private String generateToken(Long golferAccountId, String subject, long expirationMs) {
        Instant now = Instant.now();
        Instant expiration = now.plusMillis(expirationMs);

        return Jwts.builder()
                .subject(String.valueOf(golferAccountId))
                .claim("type", subject)
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiration))
                .signWith(getSigningKey())
                .compact();
    }

    /**
     * Validate a token and return the golfer account ID if valid.
     * Returns null if the token is invalid or expired.
     */
    public Long validateToken(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(getSigningKey())
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();

            String subject = claims.getSubject();
            return Long.parseLong(subject);
        } catch (JwtException | NumberFormatException e) {
            log.debug("Invalid JWT token: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Get the expiration time for access tokens in seconds.
     */
    public int getAccessTokenExpirationSeconds() {
        return (int) (accessTokenExpirationMs / 1000);
    }

    /**
     * Check if a token is an access token.
     */
    public boolean isAccessToken(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(getSigningKey())
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return ACCESS_TOKEN_SUBJECT.equals(claims.get("type", String.class));
        } catch (JwtException e) {
            return false;
        }
    }

    /**
     * Check if a token is a refresh token.
     */
    public boolean isRefreshToken(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(getSigningKey())
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return REFRESH_TOKEN_SUBJECT.equals(claims.get("type", String.class));
        } catch (JwtException e) {
            return false;
        }
    }

    /**
     * Compute SHA-256 hash of a token for storage.
     * The raw token is never stored; only its hash is persisted.
     */
    public String hashToken(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(token.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }

    /**
     * Get the refresh token expiration duration in milliseconds.
     */
    public long getRefreshTokenExpirationMs() {
        return refreshTokenExpirationMs;
    }
}
