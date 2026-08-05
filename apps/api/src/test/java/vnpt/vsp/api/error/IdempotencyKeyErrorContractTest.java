package vnpt.vsp.api.error;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * What a client sees when it forgets the {@code Idempotency-Key} header,
 * exercised through the whole filter chain — which is the only place this was
 * ever visible.
 *
 * <p>The check lives in a servlet filter, outside {@code DispatcherServlet}, so
 * the exception it raised never reached {@link GlobalExceptionHandler}. It
 * unwound through the Spring Security chain into a container error dispatch to
 * {@code /error}, and that dispatch does not carry the authenticated principal
 * — {@code OncePerRequestFilter} skips error dispatches by default, so the JWT
 * is never re-read. Security answered it with a bare <strong>403 and no
 * body</strong>: a client was told it was forbidden when it was in fact missing
 * a header.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class IdempotencyKeyErrorContractTest {

    @Autowired
    private MockMvc mockMvc;

    private static final String GEOMETRY_CORRECTION_BODY = """
            {"holeId":1,"layer":"green","geometry":{"type":"Point","coordinates":[106.7,10.8]},
             "gpsAccuracyMeters":5.0}
            """;

    @Test
    @WithMockUser
    @DisplayName("POST /rounds without Idempotency-Key is a 400 with the documented body, not a bare 403")
    void missingIdempotencyKeyOnRounds() throws Exception {
        mockMvc.perform(post("/rounds")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"courseId\":1,\"playerIds\":[1]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-VALIDATION-006"))
                .andExpect(jsonPath("$.field").value("Idempotency-Key"))
                .andExpect(jsonPath("$.message").isNotEmpty())
                .andExpect(jsonPath("$.correlationId").isNotEmpty());
    }

    @Test
    @WithMockUser
    @DisplayName("POST /courses/{id}/geometry-corrections without Idempotency-Key is a 400 too")
    void missingIdempotencyKeyOnGeometryCorrections() throws Exception {
        mockMvc.perform(post("/courses/1/geometry-corrections")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(GEOMETRY_CORRECTION_BODY))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-VALIDATION-006"))
                .andExpect(jsonPath("$.field").value("Idempotency-Key"));
    }

    @Test
    @WithMockUser
    @DisplayName("A blank Idempotency-Key is treated as missing, not as a cache key")
    void blankIdempotencyKey() throws Exception {
        mockMvc.perform(post("/rounds")
                        .header("Idempotency-Key", "   ")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"courseId\":1,\"playerIds\":[1]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-VALIDATION-006"));
    }
}
