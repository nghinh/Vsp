package vnpt.vsp.api.error;

import org.hamcrest.Matchers;
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
 * What a client sees when it sends a value that names no enum constant.
 *
 * <p>Jackson wraps the rejection in {@code HttpMessageNotReadableException},
 * the same exception a truncated body produces, so the API used to answer
 * {@code VSP-ERR-VALIDATION-004 "Malformed JSON in request body"} — sending a
 * client developer to hunt for a syntax error in a body whose syntax is
 * perfect. Run through the real converter stack, because the whole defect was
 * in what Jackson does on the way to the handler.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class EnumValueErrorContractTest {

    @Autowired
    private MockMvc mockMvc;

    private static final String GEOMETRY_CORRECTION_BODY = """
            {"holeId":1,"layer":"%s","geometry":{"type":"Point","coordinates":[106.7,10.8]},
             "gpsAccuracyMeters":5.0}
            """;

    @Test
    @WithMockUser
    @DisplayName("An unknown layer names the field and lists the accepted values")
    void unknownEnumValueNamesFieldAndAcceptedValues() throws Exception {
        mockMvc.perform(post("/courses/1/geometry-corrections")
                        .header("Idempotency-Key", "11111111-1111-4111-8111-111111111111")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(GEOMETRY_CORRECTION_BODY.formatted("tee")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-VALIDATION-003"))
                .andExpect(jsonPath("$.field").value("layer"))
                // the wire forms the client must send, not the Java constant names
                .andExpect(jsonPath("$.message").value(
                        Matchers.containsString("green, fairway, bunker, water, ob")))
                // no Java type or package may appear in a client-facing message
                .andExpect(jsonPath("$.message").value(
                        Matchers.not(Matchers.containsString("vnpt.vsp"))))
                .andExpect(jsonPath("$.message").value(
                        Matchers.not(Matchers.containsString("GeometryLayer"))));
    }

    @Test
    @WithMockUser
    @DisplayName("Genuinely malformed JSON is still reported as malformed JSON")
    void malformedJsonStillReportsMalformedJson() throws Exception {
        mockMvc.perform(post("/courses/1/geometry-corrections")
                        .header("Idempotency-Key", "22222222-2222-4222-8222-222222222222")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"holeId\": 1, \"layer\": "))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-VALIDATION-004"));
    }
}
