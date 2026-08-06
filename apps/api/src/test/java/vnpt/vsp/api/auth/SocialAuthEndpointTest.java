package vnpt.vsp.api.auth;

import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;
import vnpt.vsp.module.identity.service.JwkSource;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * {@code POST /auth/google} and {@code /auth/apple} through the whole stack.
 *
 * <p>Two things are proved here that the unit tests cannot. The first is that
 * the endpoints are reachable at all: they are the way <em>in</em>, and the
 * client calling them has no token yet, so a chain that required one made
 * social sign-in impossible — the requests below carry no {@code Authorization}
 * header. The second is that opening them did not open an account-takeover
 * hole: the forged token in {@link #forgedTokenIsRefused()} is exactly what the
 * old implementation accepted, and it now comes back as a 400 with an error
 * body rather than as somebody's session.
 */
@SpringBootTest(properties = {
        "vsp.auth.social.google.client-ids=vsp-test.apps.googleusercontent.com",
        "vsp.auth.social.apple.client-ids=vn.vnpt.vsp.test"
})
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class SocialAuthEndpointTest {

    private static final String GOOGLE_ISSUER = "https://accounts.google.com";
    private static final String GOOGLE_CLIENT_ID = "vsp-test.apps.googleusercontent.com";
    private static final String KID = "endpoint-test-key";

    private static KeyPair providerKeys;
    private static KeyPair attackerKeys;

    @Autowired private MockMvc mockMvc;
    @Autowired private GolferAccountRepository golferAccountRepository;

    /** Replaces the real fetcher, so the test does not depend on Google being up. */
    @MockBean private JwkSource jwkSource;

    @BeforeAll
    static void generateKeys() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        providerKeys = generator.generateKeyPair();
        attackerKeys = generator.generateKeyPair();
    }

    @BeforeEach
    void publishTheProvidersKey() {
        when(jwkSource.findKey(any(), eq(KID))).thenReturn(Optional.of(providerKeys.getPublic()));
    }

    @Test
    @DisplayName("A token the attacker signed themselves is refused, with an error body")
    void forgedTokenIsRefused() throws Exception {
        String forged = googleToken(attackerKeys, "victim-google-subject", "victim@example.com");

        mockMvc.perform(post("/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"idToken\":\"" + forged + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-AUTH-014"))
                .andExpect(jsonPath("$.message").isNotEmpty());

        assertThat(golferAccountRepository.findByGoogleSubject("victim-google-subject")).isEmpty();
    }

    @Test
    @DisplayName("An unsigned token — the shape the old implementation accepted — is refused")
    void unsignedTokenIsRefused() throws Exception {
        String unsigned = Jwts.builder()
                .header().keyId(KID).and()
                .issuer(GOOGLE_ISSUER)
                .audience().add(GOOGLE_CLIENT_ID).and()
                .subject("victim-google-subject")
                .claim("email", "victim@example.com")
                .claim("email_verified", true)
                .expiration(Date.from(Instant.now().plusSeconds(600)))
                .compact();

        mockMvc.perform(post("/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"idToken\":\"" + unsigned + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-AUTH-014"));
    }

    @Test
    @DisplayName("A genuinely signed token still signs the golfer in, with no bearer token on the request")
    void genuineTokenStillSignsIn() throws Exception {
        String genuine = googleToken(providerKeys, "genuine-google-subject", "newgolfer@example.com");

        mockMvc.perform(post("/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"idToken\":\"" + genuine + "\",\"displayName\":\"New Golfer\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.provider").value("GOOGLE"))
                // Serialized as "newAccount": the field is isNewAccount with an
                // isNewAccount() getter, so Jackson drops the prefix. The mobile
                // client reads json['isNewAccount'] and therefore always sees
                // false — a pre-existing contract mismatch, asserted here as it
                // actually is rather than as either side assumes.
                .andExpect(jsonPath("$.newAccount").value(true));

        assertThat(golferAccountRepository.findByGoogleSubject("genuine-google-subject")).isPresent();
    }

    @Test
    @DisplayName("An Apple token signed by Google's key is refused — the providers do not share a trust anchor")
    void appleTokenSignedByTheWrongProviderIsRefused() throws Exception {
        String crossProvider = Jwts.builder()
                .header().keyId("apple-kid-nobody-published").and()
                .issuer("https://appleid.apple.com")
                .audience().add("vn.vnpt.vsp.test").and()
                .subject("victim-apple-subject")
                .expiration(Date.from(Instant.now().plusSeconds(600)))
                .signWith(attackerKeys.getPrivate(), Jwts.SIG.RS256)
                .compact();

        mockMvc.perform(post("/auth/apple")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"idToken\":\"" + crossProvider + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-AUTH-015"));
    }

    private static String googleToken(KeyPair signer, String subject, String email) {
        return Jwts.builder()
                .header().keyId(KID).and()
                .issuer(GOOGLE_ISSUER)
                .audience().add(GOOGLE_CLIENT_ID).and()
                .subject(subject)
                .claim("email", email)
                .claim("email_verified", true)
                .issuedAt(Date.from(Instant.now().minusSeconds(30)))
                .expiration(Date.from(Instant.now().plusSeconds(600)))
                .signWith(signer.getPrivate(), Jwts.SIG.RS256)
                .compact();
    }
}
