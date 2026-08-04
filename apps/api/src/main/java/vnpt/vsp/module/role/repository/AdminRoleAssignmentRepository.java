package vnpt.vsp.module.role.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.role.entity.AdminRoleAssignment;
import vnpt.vsp.module.role.entity.RoleName;

import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link AdminRoleAssignment} entities.
 */
@Repository
@vnpt.vsp.module.role.RoleModule
public interface AdminRoleAssignmentRepository extends JpaRepository<AdminRoleAssignment, Long> {

    /**
     * Find all role assignments for an admin account.
     */
    List<AdminRoleAssignment> findByAdminAccountId(Long adminAccountId);

    /**
     * Find a specific role assignment.
     */
    Optional<AdminRoleAssignment> findByAdminAccountIdAndRoleName(Long adminAccountId, RoleName roleName);

    /**
     * Check if an admin has a specific role.
     */
    boolean existsByAdminAccountIdAndRoleName(Long adminAccountId, RoleName roleName);

    /**
     * Delete a specific role assignment.
     */
    @Modifying
    void deleteByAdminAccountIdAndRoleName(Long adminAccountId, RoleName roleName);

    /**
     * Count how many SUPER_ADMIN assignments exist (used to prevent last-super-admin revocation).
     */
    long countByRoleName(RoleName roleName);

    /**
     * Find all admins with a specific role.
     */
    List<AdminRoleAssignment> findByRoleName(RoleName roleName);
}
