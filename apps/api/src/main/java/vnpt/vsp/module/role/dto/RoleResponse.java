package vnpt.vsp.module.role.dto;

import vnpt.vsp.module.role.entity.Role;
import vnpt.vsp.module.role.entity.RoleName;

import java.time.Instant;

/**
 * Response DTO for a role.
 */
public class RoleResponse {

    private Long id;
    private RoleName roleName;
    private Instant createdAt;

    public RoleResponse() {}

    public RoleResponse(Long id, RoleName roleName, Instant createdAt) {
        this.id = id;
        this.roleName = roleName;
        this.createdAt = createdAt;
    }

    public static RoleResponse fromEntity(Role role) {
        return new RoleResponse(role.getId(), role.getRoleName(), role.getCreatedAt());
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public RoleName getRoleName() {
        return roleName;
    }

    public void setRoleName(RoleName roleName) {
        this.roleName = roleName;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }
}
