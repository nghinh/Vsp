package vnpt.vsp.module.role.util;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;

/**
 * RFC 6238 TOTP implementation using HMAC-SHA1.
 * <p>
 * Generates 6-digit time-based one-time passwords compatible with
 * Google Authenticator, Authy, and similar TOTP apps.
 * <p>
 * Per Story 2.5 AC-2: Admin accounts require MFA.
 * Per RFC 6238: SHA-1, 6-digit code, 30-second window.
 * <p>
 * Secrets are Base32 (RFC 4648, unpadded) because that is the only encoding the
 * {@code otpauth://} URI can carry: its {@code secret=} parameter is defined as
 * Base32, and every authenticator app Base32-decodes it. These secrets used to be
 * Base64, which puts characters outside the Base32 alphabet — lowercase letters,
 * {@code +}, {@code /}, {@code =} — into the URI, so no authenticator app could
 * derive the same key and no code it displayed could ever be accepted. Enrolment
 * was therefore impossible to complete even once the flow allowed it.
 */
public final class TotpUtils {

    private static final String HMAC_ALGORITHM = "HmacSHA1";
    private static final int TIME_STEP_SECONDS = 30;
    private static final int CODE_DIGITS = 6;
    private static final int[] DIGITS_POWER = {1, 10, 100, 1000, 10000, 100000, 1000000};

    private TotpUtils() {}

    /**
     * Generates a Base32-encoded random secret suitable for TOTP setup.
     *
     * @return a 32-character Base32-encoded secret (160 bits of entropy)
     */
    public static String generateSecret() {
        byte[] bytes = new byte[20]; // 160 bits
        new java.security.SecureRandom().nextBytes(bytes);
        return base32Encode(bytes);
    }

    /**
     * Generates the current TOTP code for the given Base32-encoded secret.
     * Uses the current system time and allows ±1 time window for clock drift.
     *
     * @param secret Base32-encoded secret
     * @return 6-digit TOTP code as a string (zero-padded)
     */
    public static String generateCode(String secret) {
        return generateCode(secret, System.currentTimeMillis() / 1000 / TIME_STEP_SECONDS);
    }

    /**
     * Generates the TOTP code for a specific time step.
     *
     * @param secret       Base32-encoded secret
     * @param timeStepIndex the time step index (Unix seconds / 30)
     * @return 6-digit TOTP code as a string (zero-padded)
     */
    public static String generateCode(String secret, long timeStepIndex) {
        byte[] key = base32Decode(secret);
        byte[] data = ByteBuffer.allocate(8).putLong(timeStepIndex).array();
        return computeHmac(key, data);
    }

    /**
     * Verifies a TOTP code against a secret, allowing ±1 time window for clock drift.
     *
     * @param secret          Base32-encoded secret
     * @param providedCode    the 6-digit code to verify
     * @return true if the code is valid for the current time window
     */
    public static boolean verifyCode(String secret, String providedCode) {
        if (providedCode == null || providedCode.length() != CODE_DIGITS) {
            return false;
        }
        long currentTimeStep = System.currentTimeMillis() / 1000 / TIME_STEP_SECONDS;
        // Allow ±1 window for clock drift
        for (long offset = -1; offset <= 1; offset++) {
            String expected = generateCode(secret, currentTimeStep + offset);
            if (constantTimeEquals(expected, providedCode)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Returns the TOTP provisioning URI (otpauth://) for QR code generation.
     *
     * @param secret  Base32-encoded secret
     * @param account the golfer account identifier (e.g. email or phone)
     * @param issuer  the application name
     * @return an otpauth:// URI
     */
    public static String getProvisioningUri(String secret, String account, String issuer) {
        return String.format(
                "otpauth://totp/%s:%s?secret=%s&issuer=%s&algorithm=SHA1&digits=%d&period=%d",
                urlEncode(issuer),
                urlEncode(account),
                secret,
                urlEncode(issuer),
                CODE_DIGITS,
                TIME_STEP_SECONDS
        );
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    private static String computeHmac(byte[] key, byte[] data) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(key, HMAC_ALGORITHM));
            byte[] hash = mac.doFinal(data);
            int offset = hash[hash.length - 1] & 0x0F;
            int binary = ((hash[offset] & 0x7F) << 24)
                    | ((hash[offset + 1] & 0xFF) << 16)
                    | ((hash[offset + 2] & 0xFF) << 8)
                    | (hash[offset + 3] & 0xFF);
            int otp = binary % DIGITS_POWER[CODE_DIGITS];
            return String.format("%0" + CODE_DIGITS + "d", otp);
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new RuntimeException("TOTP computation failed", e);
        }
    }

    /**
     * Constant-time string comparison to prevent timing attacks.
     */
    private static boolean constantTimeEquals(String a, String b) {
        if (a.length() != b.length()) {
            return false;
        }
        int result = 0;
        for (int i = 0; i < a.length(); i++) {
            result |= a.charAt(i) ^ b.charAt(i);
        }
        return result == 0;
    }

    private static String urlEncode(String value) {
        try {
            return java.net.URLEncoder.encode(value, "UTF-8");
        } catch (java.io.UnsupportedEncodingException e) {
            return value;
        }
    }

    // ─── Base32 (RFC 4648), the encoding otpauth:// requires ──────────────────

    private static final String BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    /** Encodes without padding; authenticator apps accept and prefer unpadded. */
    static String base32Encode(byte[] data) {
        StringBuilder out = new StringBuilder((data.length * 8 + 4) / 5);
        int buffer = 0;
        int bitsLeft = 0;
        for (byte b : data) {
            buffer = (buffer << 8) | (b & 0xFF);
            bitsLeft += 8;
            while (bitsLeft >= 5) {
                out.append(BASE32_ALPHABET.charAt((buffer >> (bitsLeft - 5)) & 0x1F));
                bitsLeft -= 5;
            }
        }
        if (bitsLeft > 0) {
            out.append(BASE32_ALPHABET.charAt((buffer << (5 - bitsLeft)) & 0x1F));
        }
        return out.toString();
    }

    /** Tolerates padding, whitespace and lowercase — all of which users paste. */
    static byte[] base32Decode(String encoded) {
        if (encoded == null) {
            throw new IllegalArgumentException("secret must not be null");
        }
        String clean = encoded.trim().replace("=", "").replace(" ", "").toUpperCase(java.util.Locale.ROOT);
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream(clean.length() * 5 / 8);
        int buffer = 0;
        int bitsLeft = 0;
        for (int i = 0; i < clean.length(); i++) {
            int value = BASE32_ALPHABET.indexOf(clean.charAt(i));
            if (value < 0) {
                throw new IllegalArgumentException("not a Base32 secret: illegal character at index " + i);
            }
            buffer = (buffer << 5) | value;
            bitsLeft += 5;
            if (bitsLeft >= 8) {
                out.write((buffer >> (bitsLeft - 8)) & 0xFF);
                bitsLeft -= 8;
            }
        }
        return out.toByteArray();
    }
}
