package vnpt.vsp.module.role.dto;

import jakarta.validation.constraints.NotNull;
import vnpt.vsp.module.role.entity.RoleName;

/**
 * Request DTO for assigning a role to a golfer account.
 */
public class AssignRoleRequest {

    @NotNull
    private Long golferAccountId;

    @NotNull
    private RoleName roleName;

    public AssignRoleRequest() {}

    public AssignRoleRequest(Long golferAccountId, RoleName roleName) {
        this.golferAccountId = golferAccountId;
        this.roleName = roleName;
    }

    public Long getGolferAccountId() {
        return golferAccountId;
    }

    public void setGolferAccountId(Long golferAccountId) {
        this.golferAccountId = golferAccountId;
    }

    public RoleName getRoleName() {
        return roleName;
    }

    public void setRoleName(RoleName roleName) {
        this.roleName = roleName;
    }
}
