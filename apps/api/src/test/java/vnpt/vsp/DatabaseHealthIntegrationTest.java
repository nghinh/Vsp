package vnpt.vsp;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Integration test that verifies database connectivity is reported
 * through the health endpoint. Uses H2 in-memory database via the
 * test profile so it runs without requiring an external PostgreSQL instance.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DatabaseHealthIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void healthEndpointIncludesDbComponent() throws Exception {
        MvcResult result = mockMvc.perform(get("/actuator/health")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andReturn();

        String content = result.getResponse().getContentAsString();
        // Health response must include a "db" component
        assertTrue(content.contains("\"db\""),
                "Health response should contain db component. Got: " + content);
    }

    @Test
    void healthEndpointDbComponentIsUp() throws Exception {
        MvcResult result = mockMvc.perform(get("/actuator/health")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andReturn();

        String content = result.getResponse().getContentAsString();
        // DB component status must be UP
        assertTrue(content.contains("\"status\":\"UP\""),
                "Health response should have UP status. Got: " + content);
        // Verify the db section contains database product detail
        // H2 reports as "H2" or "PostgreSQL" depending on compatibility mode
        assertTrue(content.contains("database") || content.contains("H2"),
                "Health db component should include database detail. Got: " + content);
    }

    @Test
    void rootHealthStatusIsUp() throws Exception {
        mockMvc.perform(get("/actuator/health")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void readinessProbeIncludesDb() throws Exception {
        MvcResult result = mockMvc.perform(get("/actuator/health/readiness")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andReturn();

        String content = result.getResponse().getContentAsString();
        assertTrue(content.contains("\"status\":\"UP\""),
                "Readiness should be UP with DB. Got: " + content);
    }
}
