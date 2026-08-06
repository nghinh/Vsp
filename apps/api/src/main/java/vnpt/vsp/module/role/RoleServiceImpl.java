package vnpt.vsp.module.role;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
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

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.stream.Collectors;

import static net.logstash.logback.marker.Markers.append;

/**
 * Implementation of {@link RoleService}.
 * Per Story 2.5 AC-1: RBAC with 6 role types.
 * Per Story 2.5 AC-2: TOTP MFA for admin accounts.
 */
@Service
@vnpt.vsp.module.role.RoleModule
public class RoleServiceImpl implements RoleService {

    private static final Logger log = LoggerFactory.getLogger(RoleServiceImpl.class);

    private static final int AES_KEY_SIZE = 256;
    private static final int AES_GCM_IV_SIZE = 12;
    private static final int AES_GCM_TAG_SIZE = 128;

    /** Metric/log tags for the two operations that take a TOTP code. */
    private static final String MFA_VERIFY = "verify";
    private static final String MFA_ENROL = "enrol";
    private static final String MFA_CONFIRM = "confirm";

    private final RoleRepository roleRepository;
    private final AdminAccountRepository adminAccountRepository;
    private final AdminRoleAssignmentRepository roleAssignmentRepository;
    private final AuditService auditService;
    private final MfaAttemptLimiter mfaAttemptLimiter;

    @Value("${vsp.mfa.encryption-key:DEFAULT_ENC_KEY_FOR_DEV_ONLY_32B!}")
    private String mfaEncryptionKey;

    public RoleServiceImpl(RoleRepository roleRepository,
                           AdminAccountRepository adminAccountRepository,
                           AdminRoleAssignmentRepository roleAssignmentRepository,
                           AuditService auditService,
                           MfaAttemptLimiter mfaAttemptLimiter) {
        this.roleRepository = roleRepository;
        this.adminAccountRepository = adminAccountRepository;
        this.roleAssignmentRepository = roleAssignmentRepository;
        this.auditService = auditService;
        this.mfaAttemptLimiter = mfaAttemptLimiter;
    }

    // ─── Role queries ────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public List<RoleResponse> getAllRoles() {
        log.debug("Getting all roles");
        return roleRepository.findAllByOrderByRoleNameAsc().stream()
                .map(RoleResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<AdminAccountResponse> getAdminAccounts() {
        log.debug("Getting all admin accounts");
        return adminAccountRepository.findAll().stream()
                .map(AdminAccountResponse::fromEntity)
                .collect(Collectors.toList());
    }

    // ─── Role assignment ────────────────────────────────────────────────────

    @Override
    @Transactional
    public AdminAccountResponse assignRole(Long callerAccountId, Long golferAccountId, RoleName roleName) {
        log.debug("assignRole caller={}, target={}, role={}", callerAccountId, golferAccountId, roleName);

        // Caller must have SUPER_ADMIN to assign any role
        if (!hasRole(callerAccountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005);
        }

        // SUPER_ADMIN can only be assigned by an existing SUPER_ADMIN
        if (roleName == RoleName.SUPER_ADMIN && !hasRole(callerAccountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005);
        }

        // Get or create admin account for target golfer
        AdminAccount adminAccount = adminAccountRepository.findByGolferAccountId(golferAccountId)
                .orElseGet(() -> {
                    AdminAccount newAccount = new AdminAccount();
                    newAccount.setGolferAccountId(golferAccountId);
                    newAccount.setMfaEnabled(false);
                    return adminAccountRepository.save(newAccount);
                });

        // Check if already assigned
        if (roleAssignmentRepository.existsByAdminAccountIdAndRoleName(adminAccount.getId(), roleName)) {
            throw new VspApiException(VspErrorCode.ROLE_003);
        }

        // Create assignment
        AdminRoleAssignment assignment = new AdminRoleAssignment();
        assignment.setAdminAccount(adminAccount);
        assignment.setRoleName(roleName);
        assignment.setAssignedAt(Instant.now());
        assignment.setAssignedBy(callerAccountId);
        roleAssignmentRepository.save(assignment);

        // Audit log
        auditService.log(
                vnpt.vsp.module.audit.AuditAction.ROLE_ASSIGN,
                "AdminRoleAssignment",
                String.valueOf(adminAccount.getId()),
                null,
                String.format("{\"golferAccountId\":%d,\"role\":\"%s\",\"assignedBy\":%d}",
                        golferAccountId, roleName.name(), callerAccountId),
                null
        );

        log.info(append("action", "ROLE_ASSIGN"),
                "Role assigned: target={}, role={}, by={}", golferAccountId, roleName, callerAccountId);

        // Refresh and return
        adminAccount.getRoleAssignments().add(assignment);
        return AdminAccountResponse.fromEntity(adminAccount);
    }

    @Override
    @Transactional
    public AdminAccountResponse revokeRole(Long callerAccountId, Long golferAccountId, RoleName roleName) {
        log.debug("revokeRole caller={}, target={}, role={}", callerAccountId, golferAccountId, roleName);

        // Caller must have SUPER_ADMIN to revoke any role
        if (!hasRole(callerAccountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005);
        }

        AdminAccount adminAccount = adminAccountRepository.findByGolferAccountId(golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROLE_002));

        AdminRoleAssignment assignment = roleAssignmentRepository
                .findByAdminAccountIdAndRoleName(adminAccount.getId(), roleName)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROLE_001));

        // Cannot revoke last SUPER_ADMIN
        if (roleName == RoleName.SUPER_ADMIN) {
            long superAdminCount = roleAssignmentRepository.countByRoleName(RoleName.SUPER_ADMIN);
            if (superAdminCount <= 1) {
                throw new VspApiException(VspErrorCode.ROLE_004);
            }
        }

        roleAssignmentRepository.delete(assignment);

        // Audit log
        auditService.log(
                vnpt.vsp.module.audit.AuditAction.ROLE_REVOKE,
                "AdminRoleAssignment",
                String.valueOf(adminAccount.getId()),
                String.format("{\"golferAccountId\":%d,\"role\":\"%s\"}", golferAccountId, roleName.name()),
                null,
                String.format("{\"revokedBy\":%d}", callerAccountId)
        );

        log.info(append("action", "ROLE_REVOKE"),
                "Role revoked: target={}, role={}, by={}", golferAccountId, roleName, callerAccountId);

        adminAccount.getRoleAssignments().remove(assignment);
        return AdminAccountResponse.fromEntity(adminAccount);
    }

    // ─── MFA ─────────────────────────────────────────────────────────────────

    /**
     * Issues the secret. Does not switch MFA on — see {@link #confirmMfaEnrolment}.
     *
     * <p>The single-call {@code enableMfa} this replaces generated a secret,
     * saved it, and in the same breath demanded a current TOTP code for it. The
     * caller had never seen the secret, so the code could only be a guess against
     * a value invented microseconds earlier: a one-in-a-million success rate on a
     * flow whose entire purpose is to be completed. Nobody could turn MFA on.
     *
     * <p>Worse, the failure path it then took — {@code setMfaSecret(null)} —
     * ran against whatever the account already was. On an account with MFA
     * already enabled, one wrong code wiped the secret and left
     * {@code mfaEnabled} true: MFA flagged on with nothing behind it, so every
     * subsequent verification hit {@code decryptSecret(null)}. Refusing to
     * enrol over an enabled account (MFA_007) removes that path rather than
     * patching it, and the confirm step below never clears a secret at all.
     */
    @Override
    @Transactional
    public MfaEnrolment beginMfaEnrolment(Long golferAccountId) {
        log.debug("beginMfaEnrolment golferAccountId={}", golferAccountId);

        // Before the lookup: an attempt refused here must cost nothing, and the
        // budget must not depend on whether the named account happens to exist.
        mfaAttemptLimiter.checkAllowed(golferAccountId, MFA_ENROL);

        AdminAccount adminAccount = adminAccountRepository.findByGolferAccountId(golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROLE_002));

        if (Boolean.TRUE.equals(adminAccount.getMfaEnabled())) {
            throw new VspApiException(VspErrorCode.MFA_007);
        }

        String rawSecret = TotpUtils.generateSecret();

        // Pending, by construction: the secret is stored while mfaEnabled stays
        // false. "Secret present, not enabled" is an enrolment in progress;
        // "enabled" always implies a secret is present.
        adminAccount.setMfaSecret(encryptSecret(rawSecret));
        adminAccount.setMfaVerifiedAt(null);
        adminAccountRepository.save(adminAccount);

        log.info(append("action", "MFA_ENROLMENT_STARTED"),
                "MFA enrolment started: golferAccountId={}", golferAccountId);

        return new MfaEnrolment(
                rawSecret,
                TotpUtils.getProvisioningUri(rawSecret, String.valueOf(golferAccountId), "VSP Admin"));
    }

    @Override
    @Transactional
    public void confirmMfaEnrolment(Long golferAccountId, String totpCode) {
        log.debug("confirmMfaEnrolment golferAccountId={}", golferAccountId);

        mfaAttemptLimiter.checkAllowed(golferAccountId, MFA_CONFIRM);

        AdminAccount adminAccount = adminAccountRepository.findByGolferAccountId(golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROLE_002));

        if (Boolean.TRUE.equals(adminAccount.getMfaEnabled())) {
            throw new VspApiException(VspErrorCode.MFA_007);
        }
        if (adminAccount.getMfaSecret() == null) {
            throw new VspApiException(VspErrorCode.MFA_006);
        }

        if (!TotpUtils.verifyCode(decryptSecret(adminAccount.getMfaSecret()), totpCode)) {
            // Deliberately no write. The pending secret is already in the
            // caller's authenticator app; clearing it here would force them to
            // start over for one mistyped digit, and clearing it on an account
            // that was enabled is what used to strand mfaEnabled with no secret.
            mfaAttemptLimiter.recordFailure(golferAccountId);
            throw new VspApiException(VspErrorCode.MFA_002);
        }
        mfaAttemptLimiter.recordSuccess(golferAccountId);

        // Only now, and only ever alongside a secret that is already stored.
        adminAccount.setMfaEnabled(true);
        adminAccount.setMfaVerifiedAt(Instant.now());
        adminAccountRepository.save(adminAccount);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.MFA_ENABLED,
                "AdminAccount",
                String.valueOf(adminAccount.getId()),
                null,
                String.format("{\"golferAccountId\":%d}", golferAccountId),
                null
        );

        log.info(append("action", "MFA_ENABLED"),
                "MFA enabled: golferAccountId={}", golferAccountId);
    }

    @Override
    @Transactional
    public void disableMfa(Long callerAccountId, Long golferAccountId) {
        log.debug("disableMfa caller={}, target={}", callerAccountId, golferAccountId);

        // Only the account owner or a SUPER_ADMIN can disable MFA
        if (!callerAccountId.equals(golferAccountId) && !hasRole(callerAccountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005);
        }

        AdminAccount adminAccount = adminAccountRepository.findByGolferAccountId(golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROLE_002));

        if (!adminAccount.getMfaEnabled()) {
            throw new VspApiException(VspErrorCode.MFA_001);
        }

        if (adminAccount.getMfaVerifiedAt() == null) {
            throw new VspApiException(VspErrorCode.MFA_001, "MFA must be verified before it can be disabled");
        }

        String beforeJson = String.format("{\"mfaEnabled\":true,\"mfaVerifiedAt\":\"%s\"}",
                adminAccount.getMfaVerifiedAt());

        adminAccount.setMfaEnabled(false);
        adminAccount.setMfaSecret(null);
        adminAccount.setMfaVerifiedAt(null);
        adminAccountRepository.save(adminAccount);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.MFA_DISABLED,
                "AdminAccount",
                String.valueOf(adminAccount.getId()),
                beforeJson,
                "{\"mfaEnabled\":false}",
                String.format("{\"disabledBy\":%d}", callerAccountId)
        );

        log.info(append("action", "MFA_DISABLED"),
                "MFA disabled: golferAccountId={}, by={}", golferAccountId, callerAccountId);
    }

    @Override
    @Transactional(readOnly = true)
    public boolean verifyMfa(Long golferAccountId, String totpCode) {
        log.debug("verifyMfa golferAccountId={}", golferAccountId);

        // First statement in the method on purpose. Anything above it — the
        // lookup, the "is MFA even on" answer — is work an attacker gets for
        // free, and is itself information about the account.
        mfaAttemptLimiter.checkAllowed(golferAccountId, MFA_VERIFY);

        AdminAccount adminAccount = adminAccountRepository.findByGolferAccountId(golferAccountId)
                .orElse(null);

        // The null-secret arm is for accounts the old enableMfa already stranded:
        // it cleared mfaSecret on a failed verification without clearing
        // mfaEnabled, so rows exist that claim MFA is on with nothing behind it.
        // Reaching decryptSecret(null) there would be a 500 on every login;
        // "MFA is not enabled" is both survivable and, for such a row, true.
        if (adminAccount == null
                || !Boolean.TRUE.equals(adminAccount.getMfaEnabled())
                || adminAccount.getMfaSecret() == null) {
            if (adminAccount != null && Boolean.TRUE.equals(adminAccount.getMfaEnabled())) {
                log.warn(append("action", "MFA_INCONSISTENT"),
                        "Account has mfaEnabled with no secret: golferAccountId={}", golferAccountId);
            }
            mfaAttemptLimiter.recordFailure(golferAccountId);
            throw new VspApiException(VspErrorCode.MFA_001);
        }

        String rawSecret = decryptSecret(adminAccount.getMfaSecret());
        boolean valid = TotpUtils.verifyCode(rawSecret, totpCode);

        // A wrong code answers 200 {"valid":false}, so the counter and not the
        // status code is what distinguishes a typo from a search.
        if (valid) {
            mfaAttemptLimiter.recordSuccess(golferAccountId);
        } else {
            mfaAttemptLimiter.recordFailure(golferAccountId);
        }
        return valid;
    }

    // ─── RBAC checks ─────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public boolean hasRole(Long golferAccountId, RoleName roleName) {
        return adminAccountRepository.findByGolferAccountId(golferAccountId)
                .map(adminAccount ->
                        roleAssignmentRepository.existsByAdminAccountIdAndRoleName(adminAccount.getId(), roleName))
                .orElse(false);
    }

    @Override
    @Transactional(readOnly = true)
    public boolean hasAdminRole(Long golferAccountId) {
        return adminAccountRepository.findByGolferAccountId(golferAccountId)
                .map(adminAccount -> !roleAssignmentRepository.findByAdminAccountId(adminAccount.getId()).isEmpty())
                .orElse(false);
    }

    @Override
    @Transactional(readOnly = true)
    public java.util.Set<RoleName> getRoles(Long golferAccountId) {
        if (golferAccountId == null) {
            return java.util.Set.of();
        }
        return adminAccountRepository.findByGolferAccountId(golferAccountId)
                .map(adminAccount -> roleAssignmentRepository.findByAdminAccountId(adminAccount.getId()).stream()
                        .map(AdminRoleAssignment::getRoleName)
                        .collect(Collectors.toCollection(() -> java.util.EnumSet.noneOf(RoleName.class))))
                .map(roles -> (java.util.Set<RoleName>) roles)
                .orElseGet(java.util.Set::of);
    }

    @Override
    @Transactional(readOnly = true)
    public AdminAccountResponse getAdminAccountByGolferId(Long golferAccountId) {
        return adminAccountRepository.findByGolferAccountId(golferAccountId)
                .map(AdminAccountResponse::fromEntity)
                .orElse(null);
    }

    // ─── Secret encryption (AES-GCM) ──────────────────────────────────────────

    /**
     * Encrypts a raw TOTP secret using AES-GCM.
     * Format: IV (12 bytes) || ciphertext || auth tag
     */
    private String encryptSecret(String rawSecret) {
        try {
            byte[] iv = new byte[AES_GCM_IV_SIZE];
            new SecureRandom().nextBytes(iv);

            SecretKeySpec key = getAesKey();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            GCMParameterSpec gcmSpec = new GCMParameterSpec(AES_GCM_TAG_SIZE, iv);
            cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec);

            byte[] ciphertext = cipher.doFinal(rawSecret.getBytes(java.nio.charset.StandardCharsets.UTF_8));

            // Prepend IV to ciphertext
            ByteBuffer buffer = ByteBuffer.allocate(iv.length + ciphertext.length);
            buffer.put(iv);
            buffer.put(ciphertext);

            return Base64.getEncoder().encodeToString(buffer.array());
        } catch (Exception e) {
            throw new RuntimeException("MFA secret encryption failed", e);
        }
    }

    /**
     * Decrypts an AES-GCM encrypted TOTP secret.
     */
    private String decryptSecret(String encrypted) {
        try {
            byte[] decoded = Base64.getDecoder().decode(encrypted);
            ByteBuffer buffer = ByteBuffer.wrap(decoded);

            byte[] iv = new byte[AES_GCM_IV_SIZE];
            buffer.get(iv);

            byte[] ciphertext = new byte[buffer.remaining()];
            buffer.get(ciphertext);

            SecretKeySpec key = getAesKey();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            GCMParameterSpec gcmSpec = new GCMParameterSpec(AES_GCM_TAG_SIZE, iv);
            cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec);

            return new String(cipher.doFinal(ciphertext), java.nio.charset.StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new RuntimeException("MFA secret decryption failed", e);
        }
    }

    private SecretKeySpec getAesKey() {
        // Pad or truncate key to 32 bytes (AES-256)
        byte[] keyBytes = mfaEncryptionKey.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        byte[] key = new byte[32];
        System.arraycopy(keyBytes, 0, key, 0, Math.min(keyBytes.length, 32));
        return new SecretKeySpec(key, "AES");
    }
}
