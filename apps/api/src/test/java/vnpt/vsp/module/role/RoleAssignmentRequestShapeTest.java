package vnpt.vsp.module.role;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.identity.security.JwtService;
import vnpt.vsp.module.role.entity.AdminAccount;
import vnpt.vsp.module.role.entity.AdminRoleAssignment;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.role.repository.AdminAccountRepository;
import vnpt.vsp.module.role.repository.AdminRoleAssignmentRepository;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * What {@code POST /admin/users/{id}/roles} accepts as a body.
 *
 * <p>Every request here goes through the real filter chain, the real
 * {@code @Valid} pass and the real error handler, because the defect lived
 * exactly there: {@code golferAccountId} was {@code @NotNull} on the body and
 * the controller copied the path variable into it <em>after</em> validation had
 * run, so bean validation saw a null that the handler was about to fill in. A
 * client that sent only the role — the only sensible client, given the id is
 * already in the URL — got 400, and the endpoint worked only for one that
 * repeated the id it had just put in the path.</p>
 *
 * <p>The path is now the sole authority and the body field is optional, so the
 * third case below is the one that keeps this honest: a body naming a
 * <em>different</em> account must be refused rather than quietly overwritten,
 * because a caller who has said two different things about which account they
 * are making an admin has not said which one they meant.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class RoleAssignmentRequestShapeTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private AdminAccountRepository adminAccountRepository;
    @Autowired private AdminRoleAssignmentRepository roleAssignmentRepository;

    /** Ids well outside anything another test seeds. */
    private static final long SUPER_ADMIN_ID = 991_000L;
    private static final long TARGET_ID = 991_001L;
    private static final long BYSTANDER_ID = 991_002L;

    private String superAdminToken;

    @BeforeEach
    void seedSuperAdmin() {
        AdminAccount account = new AdminAccount();
        account.setGolferAccountId(SUPER_ADMIN_ID);
        account.setMfaEnabled(false);
        adminAccountRepository.saveAndFlush(account);

        AdminRoleAssignment assignment = new AdminRoleAssignment();
        assignment.setAdminAccount(account);
        assignment.setRoleName(RoleName.SUPER_ADMIN);
        roleAssignmentRepository.saveAndFlush(assignment);

        superAdminToken = jwtService.generateAccessToken(SUPER_ADMIN_ID);
    }

    @Test
    @DisplayName("A body carrying only the role assigns it to the account in the path")
    void bodyWithoutTheIdIsAccepted() throws Exception {
        mockMvc.perform(assign(TARGET_ID, "{\"roleName\":\"AUDITOR\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.golferAccountId").value(TARGET_ID))
                .andExpect(jsonPath("$.roles[0]").value("AUDITOR"));

        assertTrue(hasRole(TARGET_ID, RoleName.AUDITOR),
                "the role should be assigned to the account named by the path");
    }

    @Test
    @DisplayName("A body echoing the same id is still accepted")
    void bodyEchoingTheSameIdIsAccepted() throws Exception {
        mockMvc.perform(assign(TARGET_ID,
                        "{\"golferAccountId\":" + TARGET_ID + ",\"roleName\":\"AUDITOR\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.golferAccountId").value(TARGET_ID));

        assertTrue(hasRole(TARGET_ID, RoleName.AUDITOR));
    }

    @Test
    @DisplayName("A body naming a different account is refused, and assigns nothing to either")
    void bodyDisagreeingWithThePathIsRefused() throws Exception {
        mockMvc.perform(assign(TARGET_ID,
                        "{\"golferAccountId\":" + BYSTANDER_ID + ",\"roleName\":\"SUPER_ADMIN\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-VALIDATION-001"))
                .andExpect(jsonPath("$.field").value("golferAccountId"));

        assertFalse(hasRole(TARGET_ID, RoleName.SUPER_ADMIN),
                "the path account must not be made an admin by a request the server refused");
        assertFalse(hasRole(BYSTANDER_ID, RoleName.SUPER_ADMIN),
                "the body account must not be made an admin either");
    }

    @Test
    @DisplayName("A body with no role at all is still refused, naming the field")
    void bodyWithoutARoleIsRefused() throws Exception {
        mockMvc.perform(assign(TARGET_ID, "{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VSP-ERR-VALIDATION-001"))
                .andExpect(jsonPath("$.field").value("roleName"));

        assertFalse(adminAccountRepository.findByGolferAccountId(TARGET_ID).isPresent(),
                "a rejected request must not leave an admin account behind");
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder assign(
            long pathAccountId, String body) {
        return post("/admin/users/{golferAccountId}/roles", pathAccountId)
                .header("Authorization", "Bearer " + superAdminToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body);
    }

    private boolean hasRole(long golferAccountId, RoleName role) {
        return adminAccountRepository.findByGolferAccountId(golferAccountId)
                .map(account -> roleAssignmentRepository
                        .existsByAdminAccountIdAndRoleName(account.getId(), role))
                .orElse(false);
    }
}
