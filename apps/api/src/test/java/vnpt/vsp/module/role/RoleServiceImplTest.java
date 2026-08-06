package vnpt.vsp.module.role;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.role.dto.*;
import vnpt.vsp.module.role.entity.AdminAccount;
import vnpt.vsp.module.role.entity.AdminRoleAssignment;
import vnpt.vsp.module.role.entity.Role;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.role.repository.AdminAccountRepository;
import vnpt.vsp.module.role.repository.AdminRoleAssignmentRepository;
import vnpt.vsp.module.role.repository.RoleRepository;
import vnpt.vsp.module.role.util.TotpUtils;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link RoleServiceImpl}.
 * Tests:
 * - getAllRoles returns all 6 roles
 * - assignRole grants role with audit
 * - revokeRole removes role with audit
 * - cannot revoke last SUPER_ADMIN (ROLE_004)
 * - hasRole returns true/false correctly
 * - enableMfa sets secret and verified flag
 * - verifyMfa accepts valid TOTP and rejects invalid
 * - hasAdminRole returns true if any admin role assigned
 * Per Story 2.5 AC-1: 6 role types
 * Per Story 2.5 AC-2: TOTP MFA for admin accounts
 */
@ExtendWith(MockitoExtension.class)
class RoleServiceImplTest {

    @Mock
    private RoleRepository roleRepository;

    @Mock
    private AdminAccountRepository adminAccountRepository;

    @Mock
    private AdminRoleAssignmentRepository roleAssignmentRepository;

    @Mock
    private AuditService auditService;

    /**
     * A real limiter with a real budget, not a mock: these tests make a handful
     * of attempts each and must stay under the ceiling, which is also a check
     * that the limiter does not get in an honest caller's way.
     */
    private MfaAttemptLimiter mfaAttemptLimiter;

    private RoleServiceImpl roleService;

    @BeforeEach
    void setUp() {
        mfaAttemptLimiter = new MfaAttemptLimiter(
                5, java.time.Duration.ofMinutes(15), 1000,
                new io.micrometer.core.instrument.simple.SimpleMeterRegistry());
        roleService = new RoleServiceImpl(
                roleRepository,
                adminAccountRepository,
                roleAssignmentRepository,
                auditService,
                mfaAttemptLimiter
        );
        ReflectionTestUtils.setField(roleService, "mfaEncryptionKey", "TEST_ENC_KEY_FOR_UNIT_TESTS_32B!");
    }

    // ─── getAllRoles ──────────────────────────────────────────────────────────

    @Test
    void getAllRoles_returnsAllSixRoles() {
        // Given
        List<Role> roles = List.of(
                createRole(1L, RoleName.SUPER_ADMIN),
                createRole(2L, RoleName.COURSE_ADMIN),
                createRole(3L, RoleName.GREENKEEPER),
                createRole(4L, RoleName.TOURNAMENT_DIRECTOR),
                createRole(5L, RoleName.CADDIE_MASTER),
                createRole(6L, RoleName.AUDITOR)
        );
        when(roleRepository.findAllByOrderByRoleNameAsc()).thenReturn(roles);

        // When
        List<RoleResponse> result = roleService.getAllRoles();

        // Then
        assertEquals(6, result.size());
        verify(roleRepository).findAllByOrderByRoleNameAsc();
    }

    // ─── assignRole ────────────────────────────────────────────────────────────

    @Test
    void assignRole_grantsRoleAndAudits() {
        // Given
        Long callerId = 1L;
        Long targetId = 42L;
        RoleName role = RoleName.COURSE_ADMIN;

        // Caller is SUPER_ADMIN
        AdminAccount callerAdminAccount = createAdminAccount(1L, callerId, false);
        callerAdminAccount.getRoleAssignments().add(createAssignment(callerAdminAccount, RoleName.SUPER_ADMIN));
        when(adminAccountRepository.findByGolferAccountId(callerId)).thenReturn(Optional.of(callerAdminAccount));
        when(roleAssignmentRepository.existsByAdminAccountIdAndRoleName(1L, RoleName.SUPER_ADMIN)).thenReturn(true);

        // Target admin account
        AdminAccount adminAccount = createAdminAccount(10L, targetId, false);
        when(adminAccountRepository.findByGolferAccountId(targetId)).thenReturn(Optional.of(adminAccount));
        when(roleAssignmentRepository.existsByAdminAccountIdAndRoleName(10L, role)).thenReturn(false);
        when(roleAssignmentRepository.save(any(AdminRoleAssignment.class))).thenAnswer(inv -> {
            AdminRoleAssignment arg = inv.getArgument(0);
            arg.setId(100L);
            return arg;
        });

        // When
        AdminAccountResponse result = roleService.assignRole(callerId, targetId, role);

        // Then
        verify(roleAssignmentRepository).save(any(AdminRoleAssignment.class));
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.ROLE_ASSIGN),
                eq("AdminRoleAssignment"),
                anyString(),
                isNull(),
                contains("COURSE_ADMIN"),
                isNull()
        );
        assertNotNull(result);
    }

    @Test
    void assignRole_throwsAUTH_005_whenCallerIsNotSuperAdmin() {
        // Given
        Long callerId = 42L;
        Long targetId = 99L;
        when(adminAccountRepository.findByGolferAccountId(callerId)).thenReturn(Optional.empty());

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> roleService.assignRole(callerId, targetId, RoleName.COURSE_ADMIN));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    @Test
    void assignRole_throwsROLE_003_whenRoleAlreadyAssigned() {
        // Given
        Long callerId = 1L;
        Long targetId = 42L;
        RoleName role = RoleName.COURSE_ADMIN;

        // Caller is SUPER_ADMIN
        AdminAccount callerAdminAccount = createAdminAccount(1L, callerId, false);
        callerAdminAccount.getRoleAssignments().add(createAssignment(callerAdminAccount, RoleName.SUPER_ADMIN));
        when(adminAccountRepository.findByGolferAccountId(callerId)).thenReturn(Optional.of(callerAdminAccount));
        when(roleAssignmentRepository.existsByAdminAccountIdAndRoleName(1L, RoleName.SUPER_ADMIN)).thenReturn(true);

        // Target already has COURSE_ADMIN
        AdminAccount adminAccount = createAdminAccount(10L, targetId, false);
        when(adminAccountRepository.findByGolferAccountId(targetId)).thenReturn(Optional.of(adminAccount));
        when(roleAssignmentRepository.existsByAdminAccountIdAndRoleName(10L, role)).thenReturn(true);

        // When/Then — role already assigned → ROLE_003
        VspApiException ex = assertThrows(VspApiException.class,
                () -> roleService.assignRole(callerId, targetId, role));
        assertEquals(VspErrorCode.ROLE_003, ex.getErrorCode());
    }

    // ─── revokeRole ────────────────────────────────────────────────────────────

    @Test
    void revokeRole_removesRoleAndAudits() {
        // Given
        Long callerId = 1L;
        Long targetId = 42L;
        RoleName role = RoleName.COURSE_ADMIN;

        AdminAccount adminAccount = createAdminAccount(10L, targetId, false);
        AdminRoleAssignment assignment = createAssignment(adminAccount, role);

        // Caller is super-admin check: hasRole(callerId, SUPER_ADMIN)
        // Mock adminAccountRepository to return the caller's admin account with SUPER_ADMIN
        AdminAccount callerAdminAccount = createAdminAccount(1L, callerId, false);
        callerAdminAccount.getRoleAssignments().add(createAssignment(callerAdminAccount, RoleName.SUPER_ADMIN));
        when(adminAccountRepository.findByGolferAccountId(callerId)).thenReturn(Optional.of(callerAdminAccount));
        when(roleAssignmentRepository.existsByAdminAccountIdAndRoleName(1L, RoleName.SUPER_ADMIN)).thenReturn(true);

        when(adminAccountRepository.findByGolferAccountId(targetId)).thenReturn(Optional.of(adminAccount));
        when(roleAssignmentRepository.findByAdminAccountIdAndRoleName(10L, role)).thenReturn(Optional.of(assignment));
        // Note: role != SUPER_ADMIN, so countByRoleName(SUPER_ADMIN) is not called

        // When
        AdminAccountResponse result = roleService.revokeRole(callerId, targetId, role);

        // Then
        verify(roleAssignmentRepository).delete(assignment);
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.ROLE_REVOKE),
                eq("AdminRoleAssignment"),
                anyString(),
                anyString(),
                isNull(),
                anyString()
        );
        assertNotNull(result);
    }

    @Test
    void revokeRole_throwsROLE_004_whenRevokingLastSuperAdmin() {
        // Given
        Long callerId = 1L;
        Long targetId = 42L;
        AdminAccount adminAccount = createAdminAccount(10L, targetId, false);
        AdminRoleAssignment assignment = createAssignment(adminAccount, RoleName.SUPER_ADMIN);

        // Caller has SUPER_ADMIN check
        AdminAccount callerAdminAccount = createAdminAccount(1L, callerId, false);
        callerAdminAccount.getRoleAssignments().add(createAssignment(callerAdminAccount, RoleName.SUPER_ADMIN));
        when(adminAccountRepository.findByGolferAccountId(callerId)).thenReturn(Optional.of(callerAdminAccount));
        when(roleAssignmentRepository.existsByAdminAccountIdAndRoleName(1L, RoleName.SUPER_ADMIN)).thenReturn(true);

        when(adminAccountRepository.findByGolferAccountId(targetId)).thenReturn(Optional.of(adminAccount));
        when(roleAssignmentRepository.findByAdminAccountIdAndRoleName(10L, RoleName.SUPER_ADMIN))
                .thenReturn(Optional.of(assignment));
        when(roleAssignmentRepository.countByRoleName(RoleName.SUPER_ADMIN)).thenReturn(1L);

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> roleService.revokeRole(callerId, targetId, RoleName.SUPER_ADMIN));
        assertEquals(VspErrorCode.ROLE_004, ex.getErrorCode());
    }

    // ─── hasRole / hasAdminRole ──────────────────────────────────────────────

    @Test
    void hasRole_returnsTrue_whenRoleAssigned() {
        // Given
        Long golferId = 42L;
        AdminAccount adminAccount = createAdminAccount(10L, golferId, false);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(adminAccount));
        when(roleAssignmentRepository.existsByAdminAccountIdAndRoleName(10L, RoleName.COURSE_ADMIN)).thenReturn(true);

        // When
        boolean result = roleService.hasRole(golferId, RoleName.COURSE_ADMIN);

        // Then
        assertTrue(result);
    }

    @Test
    void hasRole_returnsFalse_whenNoAdminAccount() {
        // Given
        Long golferId = 42L;
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.empty());

        // When
        boolean result = roleService.hasRole(golferId, RoleName.COURSE_ADMIN);

        // Then
        assertFalse(result);
    }

    @Test
    void hasAdminRole_returnsTrue_whenAnyRoleAssigned() {
        // Given
        Long golferId = 42L;
        AdminAccount adminAccount = createAdminAccount(10L, golferId, false);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(adminAccount));
        when(roleAssignmentRepository.findByAdminAccountId(10L)).thenReturn(List.of(
                createAssignment(adminAccount, RoleName.GREENKEEPER)));

        // When
        boolean result = roleService.hasAdminRole(golferId);

        // Then
        assertTrue(result);
    }

    @Test
    void hasAdminRole_returnsFalse_whenNoRolesAssigned() {
        // Given
        Long golferId = 42L;
        AdminAccount adminAccount = createAdminAccount(10L, golferId, false);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(adminAccount));
        when(roleAssignmentRepository.findByAdminAccountId(10L)).thenReturn(List.of());

        // When
        boolean result = roleService.hasAdminRole(golferId);

        // Then
        assertFalse(result);
    }

    // ─── MFA ─────────────────────────────────────────────────────────────────

    /**
     * The enrolment these tests replace could not be written honestly. Both of
     * its "success" cases ended up asserting MFA_002, with a comment saying "we
     * can't easily get the right code because the implementation generates its
     * own secret internally" — which is not a difficulty in the test, it is the
     * defect: the caller could not get the right code either.
     *
     * <p>Now step one returns the secret, so a test — like a real client — can
     * compute a genuine code and finish enrolling.
     */
    @Test
    void enrolment_endToEnd_issuesASecretThenEnablesMfaWithARealCodeFromIt() {
        Long golferId = 42L;
        AdminAccount account = createAdminAccount(10L, golferId, false);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(account));
        when(adminAccountRepository.save(any(AdminAccount.class))).thenAnswer(inv -> inv.getArgument(0));

        RoleService.MfaEnrolment enrolment = roleService.beginMfaEnrolment(golferId);

        // Step one hands over the secret and switches nothing on.
        assertNotNull(enrolment.secret());
        assertFalse(account.getMfaEnabled(), "step one must not enable MFA");
        assertNotNull(account.getMfaSecret(), "the pending secret must be stored");
        assertNull(account.getMfaVerifiedAt());

        // The URI an authenticator app would scan carries that same secret.
        assertTrue(enrolment.provisioningUri().startsWith("otpauth://totp/"));
        assertTrue(enrolment.provisioningUri().contains("secret=" + enrolment.secret()));

        // Step two, with a code any authenticator holding that secret would show.
        roleService.confirmMfaEnrolment(golferId, TotpUtils.generateCode(enrolment.secret()));

        assertTrue(account.getMfaEnabled());
        assertNotNull(account.getMfaSecret());
        assertNotNull(account.getMfaVerifiedAt());

        // And the enrolled secret actually verifies afterwards.
        assertTrue(roleService.verifyMfa(golferId, TotpUtils.generateCode(enrolment.secret())));
    }

    @Test
    void confirmMfaEnrolment_onWrongCode_throwsMFA_002_andChangesNothing() {
        Long golferId = 42L;
        AdminAccount account = createAdminAccount(10L, golferId, false);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(account));
        when(adminAccountRepository.save(any(AdminAccount.class))).thenAnswer(inv -> inv.getArgument(0));

        RoleService.MfaEnrolment enrolment = roleService.beginMfaEnrolment(golferId);
        String pendingSecret = account.getMfaSecret();

        VspApiException ex = assertThrows(VspApiException.class,
                () -> roleService.confirmMfaEnrolment(golferId, wrongCodeFor(enrolment.secret())));
        assertEquals(VspErrorCode.MFA_002, ex.getErrorCode());

        assertFalse(account.getMfaEnabled());
        assertNull(account.getMfaVerifiedAt());
        // The pending secret survives: one mistyped digit must not force the
        // caller to tear down and rebuild their authenticator entry.
        assertEquals(pendingSecret, account.getMfaSecret());

        // ...and the next, correct code still completes the same enrolment.
        roleService.confirmMfaEnrolment(golferId, TotpUtils.generateCode(enrolment.secret()));
        assertTrue(account.getMfaEnabled());
    }

    @Test
    void confirmMfaEnrolment_withNoEnrolmentInProgress_throwsMFA_006() {
        Long golferId = 42L;
        AdminAccount account = createAdminAccount(10L, golferId, false);
        account.setMfaSecret(null);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(account));

        VspApiException ex = assertThrows(VspApiException.class,
                () -> roleService.confirmMfaEnrolment(golferId, "123456"));
        assertEquals(VspErrorCode.MFA_006, ex.getErrorCode());
    }

    /**
     * The path that used to strand the account. Old {@code enableMfa} generated a
     * fresh secret over whatever was there, and on the (near-certain) verification
     * failure did {@code setMfaSecret(null)} — without touching {@code mfaEnabled}.
     * One wrong code against an already-enabled account therefore left MFA flagged
     * on with no secret behind it. Enrolment is now refused outright in that state.
     */
    @Test
    void beginMfaEnrolment_onAnAlreadyEnabledAccount_isRefused_andLeavesTheLiveSecretIntact() {
        Long golferId = 42L;
        AdminAccount account = createAdminAccount(10L, golferId, true);
        account.setMfaSecret("an-existing-encrypted-secret");
        account.setMfaVerifiedAt(Instant.now());
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(account));

        VspApiException ex = assertThrows(VspApiException.class,
                () -> roleService.beginMfaEnrolment(golferId));
        assertEquals(VspErrorCode.MFA_007, ex.getErrorCode());

        assertTrue(account.getMfaEnabled());
        assertEquals("an-existing-encrypted-secret", account.getMfaSecret());
        verify(adminAccountRepository, never()).save(any(AdminAccount.class));
    }

    @Test
    void confirmMfaEnrolment_onAnAlreadyEnabledAccount_isRefused() {
        Long golferId = 42L;
        AdminAccount account = createAdminAccount(10L, golferId, true);
        account.setMfaSecret("an-existing-encrypted-secret");
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(account));

        VspApiException ex = assertThrows(VspApiException.class,
                () -> roleService.confirmMfaEnrolment(golferId, "123456"));
        assertEquals(VspErrorCode.MFA_007, ex.getErrorCode());
        assertEquals("an-existing-encrypted-secret", account.getMfaSecret());
    }

    /**
     * The invariant, stated directly and driven over every failure the enrolment
     * has: whatever goes wrong, the account never ends up claiming MFA is on
     * without a secret to check codes against.
     */
    @Test
    void noEnrolmentFailurePath_leavesMfaEnabledWithoutASecret() {
        Long golferId = 42L;
        AdminAccount account = createAdminAccount(10L, golferId, false);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(account));
        when(adminAccountRepository.save(any(AdminAccount.class))).thenAnswer(inv -> inv.getArgument(0));

        // Confirm with nothing pending.
        account.setMfaSecret(null);
        assertThrows(VspApiException.class, () -> roleService.confirmMfaEnrolment(golferId, "123456"));
        assertConsistent(account);

        // Confirm with a wrong code, repeatedly, staying inside the attempt budget.
        RoleService.MfaEnrolment enrolment = roleService.beginMfaEnrolment(golferId);
        assertConsistent(account);
        for (int i = 0; i < 3; i++) {
            assertThrows(VspApiException.class,
                    () -> roleService.confirmMfaEnrolment(golferId, wrongCodeFor(enrolment.secret())));
            assertConsistent(account);
        }

        // Enrol again over a pending (not yet confirmed) enrolment.
        RoleService.MfaEnrolment second = roleService.beginMfaEnrolment(golferId);
        assertConsistent(account);

        // Then succeed, and stay consistent.
        roleService.confirmMfaEnrolment(golferId, TotpUtils.generateCode(second.secret()));
        assertConsistent(account);
        assertTrue(account.getMfaEnabled());

        // A refused re-enrolment on the now-enabled account.
        assertThrows(VspApiException.class, () -> roleService.beginMfaEnrolment(golferId));
        assertConsistent(account);
    }

    private static void assertConsistent(AdminAccount account) {
        if (Boolean.TRUE.equals(account.getMfaEnabled())) {
            assertNotNull(account.getMfaSecret(),
                    "mfaEnabled is true with no mfaSecret: MFA is flagged on with nothing behind it");
            assertNotNull(account.getMfaVerifiedAt(),
                    "mfaEnabled is true with no mfaVerifiedAt, which disableMfa then refuses to unwind");
        }
    }

    /** A six-digit code that is definitely not the current one for this secret. */
    private static String wrongCodeFor(String secret) {
        String actual = TotpUtils.generateCode(secret);
        return actual.equals("000000") ? "111111" : "000000";
    }

    /**
     * A secret an authenticator app can actually consume. The provisioning URI's
     * {@code secret=} parameter is Base32 by definition; these secrets used to be
     * Base64, so the URI carried characters ({@code +}, {@code /}, {@code =},
     * lowercase) that no authenticator could decode to the same key.
     */
    @Test
    void issuedSecret_isBase32_soAnAuthenticatorAppCanDecodeTheProvisioningUri() {
        Long golferId = 42L;
        AdminAccount account = createAdminAccount(10L, golferId, false);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(account));
        when(adminAccountRepository.save(any(AdminAccount.class))).thenAnswer(inv -> inv.getArgument(0));

        String secret = roleService.beginMfaEnrolment(golferId).secret();

        assertTrue(secret.matches("[A-Z2-7]+"), "not Base32: " + secret);
        assertEquals(32, secret.length(), "160 bits of entropy in Base32 is 32 characters");
    }

    /**
     * verifyMfa with real encryption requires an integration test with real AES key.
     * The MFA_001 path (MFA not enabled) is tested below.
     * Full TOTP flow tested in integration tests.
     */

    @Test
    void verifyMfa_throwsMFA_001_whenMfaNotEnabled() {
        // Given
        Long golferId = 42L;
        AdminAccount adminAccount = createAdminAccount(10L, golferId, false);
        when(adminAccountRepository.findByGolferAccountId(golferId)).thenReturn(Optional.of(adminAccount));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> roleService.verifyMfa(golferId, "123456"));
        assertEquals(VspErrorCode.MFA_001, ex.getErrorCode());
    }

    @Test
    void disableMfa_clearsMfaFieldsAndAudits() {
        // Given
        Long callerId = 42L;
        Long targetId = 42L;
        AdminAccount adminAccount = createAdminAccount(10L, targetId, true);
        adminAccount.setMfaVerifiedAt(Instant.now());
        when(adminAccountRepository.findByGolferAccountId(targetId)).thenReturn(Optional.of(adminAccount));
        // Note: callerId == targetId, so equals check passes; hasRole is not called
        when(adminAccountRepository.save(any(AdminAccount.class))).thenAnswer(inv -> inv.getArgument(0));

        // When
        roleService.disableMfa(callerId, targetId);

        // Then
        assertFalse(adminAccount.getMfaEnabled());
        assertNull(adminAccount.getMfaSecret());
        assertNull(adminAccount.getMfaVerifiedAt());
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.MFA_DISABLED),
                eq("AdminAccount"),
                anyString(),
                anyString(),
                eq("{\"mfaEnabled\":false}"),
                anyString()
        );
    }

    // ─── Helper methods ────────────────────────────────────────────────────────

    private Role createRole(Long id, RoleName roleName) {
        Role role = new Role();
        role.setId(id);
        role.setRoleName(roleName);
        // createdAt is set by @PrePersist — no need to set explicitly
        return role;
    }

    private AdminAccount createAdminAccount(Long id, Long golferAccountId, boolean mfaEnabled) {
        AdminAccount account = new AdminAccount();
        account.setId(id);
        account.setGolferAccountId(golferAccountId);
        account.setMfaEnabled(mfaEnabled);
        account.setRoleAssignments(new ArrayList<>());
        // createdAt is set by @PrePersist — no need to set explicitly
        return account;
    }

    private AdminRoleAssignment createAssignment(AdminAccount account, RoleName roleName) {
        AdminRoleAssignment assignment = new AdminRoleAssignment();
        assignment.setId(100L);
        assignment.setAdminAccount(account);
        assignment.setRoleName(roleName);
        assignment.setAssignedAt(Instant.now());
        return assignment;
    }
}
