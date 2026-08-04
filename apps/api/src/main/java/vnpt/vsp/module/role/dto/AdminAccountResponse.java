package vnpt.vsp.module.role.dto;

import vnpt.vsp.module.role.entity.AdminAccount;
import vnpt.vsp.module.role.entity.AdminRoleAssignment;
import vnpt.vsp.module.role.entity.RoleName;

import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Response DTO for an admin account with its assigned roles.
 */
public class AdminAccountResponse {

    private Long id;
    private Long golferAccountId;
    private Boolean mfaEnabled;
    private Instant mfaVerifiedAt;
    private List<RoleName> roles;
    private Instant createdAt;

    public AdminAccountResponse() {}

    public AdminAccountResponse(Long id, Long golferAccountId, Boolean mfaEnabled,
                                Instant mfaVerifiedAt, List<RoleName> roles, Instant createdAt) {
        this.id = id;
        this.golferAccountId = golferAccountId;
        this.mfaEnabled = mfaEnabled;
        this.mfaVerifiedAt = mfaVerifiedAt;
        this.roles = roles;
        this.createdAt = createdAt;
    }

    public static AdminAccountResponse fromEntity(AdminAccount account) {
        List<RoleName> roles = account.getRoleAssignments().stream()
                .map(AdminRoleAssignment::getRoleName)
                .collect(Collectors.toList());
        return new AdminAccountResponse(
                account.getId(),
                account.getGolferAccountId(),
                account.getMfaEnabled(),
                account.getMfaVerifiedAt(),
                roles,
                account.getCreatedAt()
        );
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getGolferAccountId() {
        return golferAccountId;
    }

    public void setGolferAccountId(Long golferAccountId) {
        this.golferAccountId = golferAccountId;
    }

    public Boolean getMfaEnabled() {
        return mfaEnabled;
    }

    public void setMfaEnabled(Boolean mfaEnabled) {
        this.mfaEnabled = mfaEnabled;
    }

    public Instant getMfaVerifiedAt() {
        return mfaVerifiedAt;
    }

    public void setMfaVerifiedAt(Instant mfaVerifiedAt) {
        this.mfaVerifiedAt = mfaVerifiedAt;
    }

    public List<RoleName> getRoles() {
        return roles;
    }

    public void setRoles(List<RoleName> roles) {
        this.roles = roles;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }
}
