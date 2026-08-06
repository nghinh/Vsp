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
     * Step one of MFA enrolment: issue a TOTP secret for an admin account.
     *
     * <p>Generates a secret, encrypts it and stores it as the account's
     * <em>pending</em> secret — {@code mfaSecret} set, {@code mfaEnabled} still
     * false — then hands the caller the secret and its provisioning URI so an
     * authenticator app can be set up. MFA is not switched on here; that is
     * {@link #confirmMfaEnrolment}, which requires a code proving the app and the
     * server agree.
     *
     * <p>This replaces the previous single-call {@code enableMfa(id, totpCode)},
     * which generated the secret server-side and then demanded a current code for
     * a secret the caller had never seen — one attempt in a million.
     *
     * <p>Refused with {@code MFA_007} when MFA is already enabled, so a fresh
     * enrolment can never overwrite the secret behind a working one.
     *
     * @param golferAccountId the golfer account ID
     * @return the issued secret and its {@code otpauth://} provisioning URI
     */
    MfaEnrolment beginMfaEnrolment(Long golferAccountId);

    /**
     * Step two of MFA enrolment: switch MFA on, given a code proving the
     * authenticator holds the secret issued by {@link #beginMfaEnrolment}.
     *
     * <p>On a wrong code nothing about the account changes: the pending secret
     * survives so the caller can simply try the next code, and MFA stays off.
     *
     * @param golferAccountId the golfer account ID
     * @param totpCode        a current TOTP code for the pending secret
     */
    void confirmMfaEnrolment(Long golferAccountId, String totpCode);

    /**
     * A secret issued by {@link #beginMfaEnrolment} and the URI that carries it.
     *
     * @param secret          the Base32 TOTP secret, for manual entry
     * @param provisioningUri the {@code otpauth://} URI, for a QR code
     */
    record MfaEnrolment(String secret, String provisioningUri) {}

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
     * Every role assigned to a golfer account, in one lookup.
     * <p>
     * This is what turns a JWT principal into Spring Security authorities, so
     * it is on the hot path of every authenticated request: callers must not
     * have to make one round trip per role they are interested in.
     *
     * @param golferAccountId the golfer account ID
     * @return the assigned roles, empty when the account is not an admin
     */
    java.util.Set<RoleName> getRoles(Long golferAccountId);

    /**
     * Get the admin account for a golfer account ID.
     * Returns null if no admin account exists.
     *
     * @param golferAccountId the golfer account ID
     * @return the AdminAccountResponse or null
     */
    AdminAccountResponse getAdminAccountByGolferId(Long golferAccountId);
}
