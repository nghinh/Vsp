package vnpt.vsp.module.role;

import vnpt.vsp.module.role.dto.*;
import vnpt.vsp.module.role.entity.RoleName;

import java.util.List;

/**
 * Service interface for RBAC role management and MFA.
 * Per Story 2.5 AC-1: RBAC supports 6 role types.
 * Per Story 2.5 AC-2: Admin accounts require MFA.
 */
public interface RoleService {

    // ─── Role queries ────────────────────────────────────────────────────────

    /**
     * Get all defined roles.
     */
    List<RoleResponse> getAllRoles();

    /**
     * Get all admin accounts with their assigned roles.
     */
    List<AdminAccountResponse> getAdminAccounts();

    // ─── Role assignment ────────────────────────────────────────────────────

    /**
     * Assign a role to a golfer account.
     * Creates an AdminAccount if one does not exist for this golfer.
     * Requires the caller to have SUPER_ADMIN role.
     *
     * @param callerAccountId  the admin performing the assignment
     * @param golferAccountId the golfer to assign the role to
     * @param roleName        the role to assign
     */
    AdminAccountResponse assignRole(Long callerAccountId, Long golferAccountId, RoleName roleName);

    /**
     * Revoke a role from a golfer account.
     * Cannot revoke the last SUPER_ADMIN (ROLE_004).
     * Requires the caller to have SUPER_ADMIN role.
     *
     * @param callerAccountId  the admin performing the revocation
     * @param golferAccountId the golfer to revoke the role from
     * @param roleName        the role to revoke
     */
    AdminAccountResponse revokeRole(Long callerAccountId, Long golferAccountId, RoleName roleName);

    // ─── MFA ─────────────────────────────────────────────────────────────────

    /**
     * Enable MFA for an admin account.
     * Generates a TOTP secret, encrypts it, and stores it.
     * Requires a valid TOTP verification to complete.
     *
     * @param golferAccountId the golfer account ID
     * @param totpCode        the current TOTP code to verify the secret
     * @return the provisioning URI for QR code generation
     */
    String enableMfa(Long golferAccountId, String totpCode);

    /**
     * Disable MFA for an admin account.
     * Requires the account to have previously verified MFA (mfaVerifiedAt is set).
     *
     * @param callerAccountId  the admin performing the disable (must be the account owner or SUPER_ADMIN)
     * @param golferAccountId the golfer account ID
     */
    void disableMfa(Long callerAccountId, Long golferAccountId);

    /**
     * Verify a TOTP code for an admin account.
     *
     * @param golferAccountId the golfer account ID
     * @param totpCode        the TOTP code to verify
     * @return true if the code is valid
     */
    boolean verifyMfa(Long golferAccountId, String totpCode);

    // ─── RBAC checks ─────────────────────────────────────────────────────────

    /**
     * Check if a golfer account has a specific role.
     *
     * @param golferAccountId the golfer account ID
     * @param roleName        the role to check
     * @return true if the golfer has the role
     */
    boolean hasRole(Long golferAccountId, RoleName roleName);

    /**
     * Check if a golfer account has any admin role.
     *
     * @param golferAccountId the golfer account ID
     * @return true if the golfer has at least one admin role
     */
    boolean hasAdminRole(Long golferAccountId);

    /**
     * Get the admin account for a golfer account ID.
     * Returns null if no admin account exists.
     *
     * @param golferAccountId the golfer account ID
     * @return the AdminAccountResponse or null
     */
    AdminAccountResponse getAdminAccountByGolferId(Long golferAccountId);
}
