package vnpt.vsp.module.role;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
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
     */
    @PostMapping("/users/{golferAccountId}/roles")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<AdminAccountResponse> assignRole(
            Authentication authentication,
            @PathVariable Long golferAccountId,
            @Valid @RequestBody AssignRoleRequest request) {
        Long callerId = (Long) authentication.getPrincipal();
        request.setGolferAccountId(golferAccountId);
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
     * Enable MFA for the authenticated admin account.
     * Generates a TOTP secret and returns the provisioning URI for QR code generation.
     * <p>
     * The path variable names the account, so without the check below "for the
     * authenticated admin account" would have meant "for any account the caller
     * cares to name": rotating another admin's TOTP secret.
     */
    @PostMapping("/users/{golferAccountId}/mfa/enable")
    @PreAuthorize("#golferAccountId == authentication.principal or hasRole('SUPER_ADMIN')")
    public ResponseEntity<EnableMfaResponse> enableMfa(
            @PathVariable Long golferAccountId,
            @Valid @RequestBody EnableMfaRequest request) {
        String provisioningUri = roleService.enableMfa(golferAccountId, request.getTotpCode());
        return ResponseEntity.ok(new EnableMfaResponse(provisioningUri));
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

    // ─── Internal DTOs for responses ────────────────────────────────────────

    public static class EnableMfaResponse {
        private final String provisioningUri;

        public EnableMfaResponse(String provisioningUri) {
            this.provisioningUri = provisioningUri;
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
