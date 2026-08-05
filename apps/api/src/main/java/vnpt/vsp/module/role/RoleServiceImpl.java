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

    private final RoleRepository roleRepository;
    private final AdminAccountRepository adminAccountRepository;
    private final AdminRoleAssignmentRepository roleAssignmentRepository;
    private final AuditService auditService;

    @Value("${vsp.mfa.encryption-key:DEFAULT_ENC_KEY_FOR_DEV_ONLY_32B!}")
    private String mfaEncryptionKey;

    public RoleServiceImpl(RoleRepository roleRepository,
                           AdminAccountRepository adminAccountRepository,
                           AdminRoleAssignmentRepository roleAssignmentRepository,
                           AuditService auditService) {
        this.roleRepository = roleRepository;
        this.adminAccountRepository = adminAccountRepository;
        this.roleAssignmentRepository = roleAssignmentRepository;
        this.auditService = auditService;
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

    @Override
    @Transactional
    public String enableMfa(Long golferAccountId, String totpCode) {
        log.debug("enableMfa golferAccountId={}", golferAccountId);

        AdminAccount adminAccount = adminAccountRepository.findByGolferAccountId(golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROLE_002));

        // Generate a new secret
        String rawSecret = TotpUtils.generateSecret();

        // Temporarily set the secret so we can verify the provided code
        adminAccount.setMfaSecret(encryptSecret(rawSecret));
        adminAccountRepository.save(adminAccount);

        // Verify the TOTP code against this secret
        if (!TotpUtils.verifyCode(rawSecret, totpCode)) {
            // Clear the secret if verification fails
            adminAccount.setMfaSecret(null);
            adminAccountRepository.save(adminAccount);
            throw new VspApiException(VspErrorCode.MFA_002);
        }

        // Verification successful — mark as verified and re-save
        adminAccount.setMfaEnabled(true);
        adminAccount.setMfaVerifiedAt(Instant.now());
        // Keep the secret (already set above)
        adminAccountRepository.save(adminAccount);

        // Audit log
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

        // Return the provisioning URI for QR code generation
        return TotpUtils.getProvisioningUri(rawSecret, String.valueOf(golferAccountId), "VSP Admin");
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

        AdminAccount adminAccount = adminAccountRepository.findByGolferAccountId(golferAccountId)
                .orElse(null);

        if (adminAccount == null || !Boolean.TRUE.equals(adminAccount.getMfaEnabled())) {
            throw new VspApiException(VspErrorCode.MFA_001);
        }

        String rawSecret = decryptSecret(adminAccount.getMfaSecret());
        return TotpUtils.verifyCode(rawSecret, totpCode);
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
