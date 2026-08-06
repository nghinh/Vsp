package vnpt.vsp.module.role.dto;

import jakarta.validation.constraints.NotNull;
import vnpt.vsp.module.role.entity.RoleName;

/**
 * Request DTO for assigning a role to a golfer account.
 * <p>
 * The account being changed is named by the path of
 * {@code POST /admin/users/{golferAccountId}/roles}; the body names only the
 * role. {@link #golferAccountId} is optional and exists so a client that
 * echoes the id back is not rejected — but an echo that disagrees with the
 * path is refused rather than resolved, because there is no reading of such a
 * request that is safe to guess at.
 * <p>
 * The field was {@code @NotNull} while the controller copied the path variable
 * into it <em>after</em> validation had already run, so a correct client
 * sending only the role was rejected and the endpoint worked only for a caller
 * that duplicated the id it had just put in the URL.
 */
public class AssignRoleRequest {

    /**
     * Optional echo of the path variable. Never the source of truth: the
     * controller assigns the role to the account named by the path.
     */
    private Long golferAccountId;

    @NotNull
    private RoleName roleName;

    public AssignRoleRequest() {}

    public AssignRoleRequest(Long golferAccountId, RoleName roleName) {
        this.golferAccountId = golferAccountId;
        this.roleName = roleName;
    }

    public AssignRoleRequest(RoleName roleName) {
        this(null, roleName);
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
