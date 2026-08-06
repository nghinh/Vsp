package vnpt.vsp.module.role;

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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Repeated wrong codes stop being answered.
 *
 * <p>Through the real chain, because the point is what a caller with a valid
 * token can do: {@code /admin/users/{id}/mfa/verify} answers whether a six-digit
 * code is the right one, for the caller's own account or — as a SUPER_ADMIN —
 * anyone's. With no ceiling that is a search of a keyspace small enough to
 * exhaust while the codes are still live, against the accounts that hold every
 * privilege in the system.</p>
 *
 * <p>Each test uses account ids of its own: the limiter is a singleton for the
 * lifetime of the Spring context, exactly as it is in a running instance, and a
 * budget shared between tests would make them order-dependent.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class MfaEndpointThrottlingTest {

    /** Matches {@code vsp.mfa.rate-limit.max-attempts}. */
    private static final int MAX_ATTEMPTS = 5;

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private AdminAccountRepository adminAccountRepository;
    @Autowired private AdminRoleAssignmentRepository roleAssignmentRepository;

    @Test
    @DisplayName("An admin guessing at their own code is cut off after the budget")
    void verifyIsThrottledForTheAccountsOwner() throws Exception {
        long accountId = 992_100L;
        String token = seedAdmin(accountId, RoleName.COURSE_ADMIN);

        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            mockMvc.perform(verify(accountId, token, "000000"))
                    .andExpect(status().is(org.hamcrest.Matchers.not(429)));
        }

        mockMvc.perform(verify(accountId, token, "000000"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("VSP-ERR-MFA-005"))
                .andExpect(jsonPath("$.message").isNotEmpty())
                .andExpect(jsonPath("$.correlationId").isNotEmpty());
    }

    @Test
    @DisplayName("A SUPER_ADMIN cannot use the endpoint to search another admin's codes")
    void verifyIsThrottledPerTargetAccountNotPerCaller() throws Exception {
        long superAdminId = 992_200L;
        long targetId = 992_201L;
        String superAdminToken = seedAdmin(superAdminId, RoleName.SUPER_ADMIN);
        seedAdmin(targetId, RoleName.COURSE_ADMIN);

        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            mockMvc.perform(verify(targetId, superAdminToken, "111111"));
        }

        mockMvc.perform(verify(targetId, superAdminToken, "111111"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("VSP-ERR-MFA-005"));

        // The budget belongs to the account under attack, not to the caller, so
        // a different target is still served — and a throttle keyed on the
        // caller would have been trivially defeated by a second admin token.
        long bystanderId = 992_202L;
        seedAdmin(bystanderId, RoleName.COURSE_ADMIN);
        mockMvc.perform(verify(bystanderId, superAdminToken, "111111"))
                .andExpect(status().is(org.hamcrest.Matchers.not(429)));
    }

    /**
     * Enrolment is now two calls, and the code — the guessable part — is in the
     * second. So the budget is spent on {@code /mfa/confirm}, and exhausting it
     * must also shut the door on {@code /mfa/enroll}: an attacker who can still
     * start a fresh enrolment can rotate the pending secret indefinitely, and a
     * budget that only covers confirm would be a budget on nothing.
     */
    @Test
    @DisplayName("Confirming an enrolment is throttled, and a spent budget also refuses a new enrolment")
    void enrolmentConfirmationIsThrottled() throws Exception {
        long accountId = 992_300L;
        String token = seedAdmin(accountId, RoleName.COURSE_ADMIN);

        // Step one, so confirm reaches the code check rather than "nothing pending".
        mockMvc.perform(enroll(accountId, token)).andExpect(status().isOk());

        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            mockMvc.perform(confirm(accountId, token, "000000"))
                    .andExpect(status().isBadRequest());
        }

        mockMvc.perform(confirm(accountId, token, "000000"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("VSP-ERR-MFA-005"));

        mockMvc.perform(enroll(accountId, token))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("VSP-ERR-MFA-005"));
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder enroll(
            long accountId, String token) {
        return post("/admin/users/{id}/mfa/enroll", accountId)
                .header("Authorization", "Bearer " + token);
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder confirm(
            long accountId, String token, String code) {
        return post("/admin/users/{id}/mfa/confirm", accountId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"totpCode\":\"" + code + "\"}");
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder verify(
            long accountId, String token, String code) {
        return post("/admin/users/{id}/mfa/verify", accountId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"totpCode\":\"" + code + "\"}");
    }

    private String seedAdmin(long golferAccountId, RoleName role) {
        AdminAccount account = new AdminAccount();
        account.setGolferAccountId(golferAccountId);
        account.setMfaEnabled(false);
        adminAccountRepository.saveAndFlush(account);

        AdminRoleAssignment assignment = new AdminRoleAssignment();
        assignment.setAdminAccount(account);
        assignment.setRoleName(role);
        roleAssignmentRepository.saveAndFlush(assignment);

        return jwtService.generateAccessToken(golferAccountId);
    }
}
