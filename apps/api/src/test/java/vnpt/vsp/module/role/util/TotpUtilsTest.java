package vnpt.vsp.module.role.util;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for {@link TotpUtils}, against RFC 6238's own vectors rather than
 * against itself.
 *
 * <p>These secrets are Base32 because that is what an {@code otpauth://} URI can
 * carry. They used to be Base64, which is not a difference an assertion like
 * "generateCode(s) equals verifyCode(s)" can see — the pair agrees with itself
 * whatever the encoding — but it is the whole difference to an authenticator
 * app, which Base32-decodes the URI and would derive a different key. Enrolment
 * could not be completed with a real app.
 */
class TotpUtilsTest {

    /**
     * RFC 6238 Appendix B: the seed is the ASCII "12345678901234567890", which is
     * Base32 GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ. At T = 59 seconds the SHA-1
     * 8-digit code is 94287082, so the 6-digit truncation is 287082.
     */
    private static final String RFC_SECRET = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";

    @Test
    void generateCode_matchesTheRfc6238TestVector() {
        // T = 59s, so the time-step index is 59 / 30 = 1.
        assertEquals("287082", TotpUtils.generateCode(RFC_SECRET, 1L));
    }

    @Test
    void generateCode_matchesFurtherRfc6238TestVectors() {
        // 1111111109 -> step 37037036, 8-digit 07081804
        assertEquals("081804", TotpUtils.generateCode(RFC_SECRET, 1111111109L / 30));
        // 1111111111 -> step 37037037, 8-digit 14050471
        assertEquals("050471", TotpUtils.generateCode(RFC_SECRET, 1111111111L / 30));
        // 1234567890 -> step 41152263, 8-digit 89005924
        assertEquals("005924", TotpUtils.generateCode(RFC_SECRET, 1234567890L / 30));
    }

    @Test
    void base32_decodesTheRfcSeedToItsAsciiBytes() {
        assertArrayEquals("12345678901234567890".getBytes(StandardCharsets.US_ASCII),
                TotpUtils.base32Decode(RFC_SECRET));
    }

    @Test
    void base32_roundTripsArbitraryBytes() {
        byte[] data = new byte[]{0, 1, 2, (byte) 0x80, (byte) 0xFF, 42, 7, (byte) 0xAB};
        for (int len = 1; len <= data.length; len++) {
            byte[] slice = java.util.Arrays.copyOf(data, len);
            String encoded = TotpUtils.base32Encode(slice);
            assertTrue(encoded.matches("[A-Z2-7]*"), "not Base32: " + encoded);
            assertArrayEquals(slice, TotpUtils.base32Decode(encoded), "round trip failed at length " + len);
        }
    }

    @Test
    void base32Decode_toleratesPaddingWhitespaceAndLowercase() {
        // All three are things a user pastes out of a setup screen.
        byte[] expected = TotpUtils.base32Decode(RFC_SECRET);
        assertArrayEquals(expected, TotpUtils.base32Decode(RFC_SECRET.toLowerCase()));
        assertArrayEquals(expected, TotpUtils.base32Decode("  " + RFC_SECRET + "  "));
        assertArrayEquals(expected, TotpUtils.base32Decode(RFC_SECRET + "======"));
    }

    @Test
    void base32Decode_rejectsCharactersOutsideTheAlphabet() {
        // "1", "8", "9", "+", "/" are all absent from the Base32 alphabet — and
        // "+" and "/" are exactly what a Base64 secret would have smuggled in.
        assertThrows(IllegalArgumentException.class, () -> TotpUtils.base32Decode("ABC1"));
        assertThrows(IllegalArgumentException.class, () -> TotpUtils.base32Decode("AB+D"));
        assertThrows(IllegalArgumentException.class, () -> TotpUtils.base32Decode("AB/D"));
    }

    @Test
    void generateSecret_isBase32AndCarries160Bits() {
        String secret = TotpUtils.generateSecret();

        assertTrue(secret.matches("[A-Z2-7]{32}"), "not a 32-character Base32 secret: " + secret);
        assertEquals(20, TotpUtils.base32Decode(secret).length);
        assertNotEquals(secret, TotpUtils.generateSecret(), "secrets must not repeat");
    }

    @Test
    void verifyCode_acceptsTheCurrentCode_andRejectsAWrongOne() {
        String secret = TotpUtils.generateSecret();

        assertTrue(TotpUtils.verifyCode(secret, TotpUtils.generateCode(secret)));

        String current = TotpUtils.generateCode(secret);
        assertFalse(TotpUtils.verifyCode(secret, current.equals("000000") ? "111111" : "000000"));
    }

    @Test
    void verifyCode_acceptsOneStepOfDrift_butNotTwo() {
        String secret = TotpUtils.generateSecret();
        long now = System.currentTimeMillis() / 1000 / 30;

        assertTrue(TotpUtils.verifyCode(secret, TotpUtils.generateCode(secret, now - 1)));
        assertTrue(TotpUtils.verifyCode(secret, TotpUtils.generateCode(secret, now + 1)));
        assertFalse(TotpUtils.verifyCode(secret, TotpUtils.generateCode(secret, now - 3)));
        assertFalse(TotpUtils.verifyCode(secret, TotpUtils.generateCode(secret, now + 3)));
    }

    @Test
    void verifyCode_rejectsMalformedInput_withoutThrowing() {
        String secret = TotpUtils.generateSecret();

        assertFalse(TotpUtils.verifyCode(secret, null));
        assertFalse(TotpUtils.verifyCode(secret, ""));
        assertFalse(TotpUtils.verifyCode(secret, "12345"));
        assertFalse(TotpUtils.verifyCode(secret, "1234567"));
    }

    /**
     * The URI an authenticator app scans must carry the secret in the alphabet
     * that app will decode, and must survive URL-encoding of the labels.
     */
    @Test
    void provisioningUri_isScannable() {
        String secret = TotpUtils.generateSecret();

        String uri = TotpUtils.getProvisioningUri(secret, "13", "VSP Admin");

        assertTrue(uri.startsWith("otpauth://totp/"), uri);
        assertTrue(uri.contains("secret=" + secret), uri);
        assertTrue(uri.contains("algorithm=SHA1"), uri);
        assertTrue(uri.contains("digits=6"), uri);
        assertTrue(uri.contains("period=30"), uri);
        // The space in the issuer must not arrive raw.
        assertFalse(uri.contains("VSP Admin"), uri);
    }
}
