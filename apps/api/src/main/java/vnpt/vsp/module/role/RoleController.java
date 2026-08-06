package vnpt.vsp.module.role;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.role.dto.*;
import vnpt.vsp.module.role.entity.RoleName;

import java.net.URI;
import java.util.List;

/**
 * REST controller for RBAC role management and MFA endpoints.
 * Per Story 2.5 AC-1: RBAC supports 6 role types.
 * Per Story 2.5 AC-2: Admin accounts require MFA.
 */
@RestController
@RequestMapping("/admin")
@vnpt.vsp.module.role.RoleModule
public class RoleController {

    private final RoleService roleService;

    public RoleController(RoleService roleService) {
        this.roleService = roleService;
    }

    // ─── The caller's own admin identity ─────────────────────────────────────

    /**
     * The calling account's admin identity: which roles it holds, and whether
     * its MFA is enrolled.
     *
     * <p>Added for the operations portal, which had no way to find out who it
     * was talking as. It knew its roles by declaring them in TypeScript —
     * {@code const DEFAULT_ROLES = ["COURSE_ADMIN", "SUPER_ADMIN"]} — which is
     * the client answering a question only the server can answer. This is the
     * answer.
     *
     * <p>Two properties matter and both come from the URL rule rather than from
     * anything the caller sends. The account is the authenticated principal, not
     * a path variable, so this cannot be pointed at somebody else. And
     * {@code /admin/**} already requires some admin role, so an ordinary golfer
     * — including one who has an admin account row but no role assignment on it
     * — is refused rather than told "you hold no roles". The portal reads that
     * 403 as "you are not staff", which is the same fact the server would
     * enforce on every subsequent request anyway.
     *
     * <p>The annotation names every defined role, read from the enum, so a role
     * added later reaches this endpoint without anyone remembering to edit a
     * list here.
     */
    @GetMapping("/me")
    @PreAuthorize("hasAnyRole(T(vnpt.vsp.api.admin.AdminSecurityConfig).adminRoles())")
    public ResponseEntity<AdminAccountResponse> getCurrentAdminAccount(Authentication authentication) {
        Long golferAccountId = (Long) authentication.getPrincipal();
        AdminAccountResponse account = roleService.getAdminAccountByGolferId(golferAccountId);
        if (account == null) {
            throw new VspApiException(VspErrorCode.AUTH_005);
        }
        return ResponseEntity.ok(account);
    }

    // ─── Role management ────────────────────────────────────────────────────

    /**
     * List all defined roles.
     * <p>
     * This and {@link #listAdminAccounts()} are the two endpoints that never had
     * a check of any kind — not an annotation, not a line in the method body.
     * They were unreachable only because the {@code /admin/**} chain refused
     * everyone, so repairing that chain without adding these annotations would
     * have handed the admin directory to every signed-in golfer.
     */
    @GetMapping("/roles")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<List<RoleResponse>> listRoles() {
        List<RoleResponse> roles = roleService.getAllRoles();
        return ResponseEntity.ok(roles);
    }

    /**
     * List all admin accounts with their assigned roles.
     * <p>
     * A map of who holds which privilege — the reconnaissance an attacker wants
     * before choosing a target — so SUPER_ADMIN, matching the role that may
     * change those assignments.
     */
    @GetMapping("/users")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<List<AdminAccountResponse>> listAdminAccounts() {
        List<AdminAccountResponse> accounts = roleService.getAdminAccounts();
        return ResponseEntity.ok(accounts);
    }

    // ─── Role assignment / revocation ────────────────────────────────────────

    /**
     * Assign a role to a golfer account.
     * Requires SUPER_ADMIN.
     * <p>
     * The path names the account; the body names only the role. The body may
     * still echo {@code golferAccountId}, but an echo that disagrees with the
     * path is a 400 rather than a silent win for one of the two — the caller
     * has said two different things about which admin they are creating, and
     * picking one of them is how a role lands on an account nobody meant to
     * name.
     */
    @PostMapping("/users/{golferAccountId}/roles")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<AdminAccountResponse> assignRole(
            Authentication authentication,
            @PathVariable Long golferAccountId,
            @Valid @RequestBody AssignRoleRequest request) {
        Long callerId = (Long) authentication.getPrincipal();
        requireBodyAgreesWithPath(golferAccountId, request.getGolferAccountId());
        AdminAccountResponse account = roleService.assignRole(callerId, golferAccountId, request.getRoleName());
        return ResponseEntity
                .created(URI.create("/admin/users/" + account.getGolferAccountId() + "/roles"))
                .body(account);
    }

    /**
     * Revoke a role from a golfer account.
     * Requires SUPER_ADMIN.
     * Cannot revoke the last SUPER_ADMIN (ROLE_004).
     */
    @DeleteMapping("/users/{golferAccountId}/roles/{roleName}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<AdminAccountResponse> revokeRole(
            Authentication authentication,
            @PathVariable Long golferAccountId,
            @PathVariable RoleName roleName) {
        Long callerId = (Long) authentication.getPrincipal();
        AdminAccountResponse account = roleService.revokeRole(callerId, golferAccountId, roleName);
        return ResponseEntity.ok(account);
    }

    // ─── MFA management ──────────────────────────────────────────────────────

    /**
     * Step one of MFA enrolment: issue a TOTP secret and its provisioning URI.
     *
     * <p>MFA is <em>not</em> switched on here. The caller sets up an
     * authenticator app from the returned secret and then calls
     * {@code /mfa/confirm} with a code from it.
     *
     * <p>Replaces the previous {@code POST /mfa/enable}, which took a
     * {@code totpCode} for a secret it generated in the same call — a code the
     * caller had no way to know, so the endpoint could not succeed.
     *
     * <p>The path variable names the account, so without the check below "for the
     * authenticated admin account" would have meant "for any account the caller
     * cares to name": rotating another admin's TOTP secret.
     */
    @PostMapping("/users/{golferAccountId}/mfa/enroll")
    @PreAuthorize("#golferAccountId == authentication.principal or hasRole('SUPER_ADMIN')")
    public ResponseEntity<MfaEnrolmentResponse> beginMfaEnrolment(@PathVariable Long golferAccountId) {
        RoleService.MfaEnrolment enrolment = roleService.beginMfaEnrolment(golferAccountId);
        return ResponseEntity.ok(
                new MfaEnrolmentResponse(enrolment.secret(), enrolment.provisioningUri()));
    }

    /**
     * Step two of MFA enrolment: switch MFA on, given a code from the
     * authenticator set up in step one.
     *
     * <p>A wrong code is a 400 {@code VSP-ERR-MFA-002} and changes nothing — the
     * pending secret stays valid, so the caller can just try the next code.
     */
    @PostMapping("/users/{golferAccountId}/mfa/confirm")
    @PreAuthorize("#golferAccountId == authentication.principal or hasRole('SUPER_ADMIN')")
    public ResponseEntity<Void> confirmMfaEnrolment(
            @PathVariable Long golferAccountId,
            @Valid @RequestBody EnableMfaRequest request) {
        roleService.confirmMfaEnrolment(golferAccountId, request.getTotpCode());
        return ResponseEntity.noContent().build();
    }

    /**
     * Disable MFA for an admin account.
     * Requires the account owner or SUPER_ADMIN.
     */
    @PostMapping("/users/{golferAccountId}/mfa/disable")
    @PreAuthorize("#golferAccountId == authentication.principal or hasRole('SUPER_ADMIN')")
    public ResponseEntity<Void> disableMfa(
            Authentication authentication,
            @PathVariable Long golferAccountId) {
        Long callerId = (Long) authentication.getPrincipal();
        roleService.disableMfa(callerId, golferAccountId);
        return ResponseEntity.noContent().build();
    }

    /**
     * Verify a TOTP code for an admin account.
     * Used during admin login to verify MFA or to check if a setup is valid.
     */
    @PostMapping("/users/{golferAccountId}/mfa/verify")
    @PreAuthorize("#golferAccountId == authentication.principal or hasRole('SUPER_ADMIN')")
    public ResponseEntity<VerifyMfaResponse> verifyMfa(
            @PathVariable Long golferAccountId,
            @Valid @RequestBody VerifyMfaRequest request) {
        boolean valid = roleService.verifyMfa(golferAccountId, request.getTotpCode());
        return ResponseEntity.ok(new VerifyMfaResponse(valid));
    }

    // ─── Helpers ────────────────────────────────────────────────────────────

    /**
     * Refuses a body that names a different account than the path.
     * <p>
     * {@code null} in the body is the normal case and means "the account in
     * the path", which is the only account this endpoint can act on.
     */
    private void requireBodyAgreesWithPath(Long pathAccountId, Long bodyAccountId) {
        if (bodyAccountId != null && !bodyAccountId.equals(pathAccountId)) {
            throw new VspApiException(
                    VspErrorCode.VALIDATION_001,
                    "golferAccountId in the body (" + bodyAccountId + ") does not match the path ("
                            + pathAccountId + "). Omit it from the body, or send the same id.",
                    "golferAccountId",
                    null);
        }
    }

    // ─── Internal DTOs for responses ────────────────────────────────────────

    /**
     * The issued secret, both ways a client can consume it: {@code secret} for
     * manual entry, {@code provisioningUri} for a QR code.
     */
    public static class MfaEnrolmentResponse {
        private final String secret;
        private final String provisioningUri;

        public MfaEnrolmentResponse(String secret, String provisioningUri) {
            this.secret = secret;
            this.provisioningUri = provisioningUri;
        }

        public String getSecret() {
            return secret;
        }

        public String getProvisioningUri() {
            return provisioningUri;
        }
    }

    public static class VerifyMfaResponse {
        private final boolean valid;

        public VerifyMfaResponse(boolean valid) {
            this.valid = valid;
        }

        public boolean isValid() {
            return valid;
        }
    }
}
