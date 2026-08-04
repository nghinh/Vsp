package vnpt.vsp.module.role.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.role.entity.Role;
import vnpt.vsp.module.role.entity.RoleName;

import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link Role} entities.
 */
@Repository
@vnpt.vsp.module.role.RoleModule
public interface RoleRepository extends JpaRepository<Role, Long> {

    /**
     * Find all roles ordered by name.
     */
    List<Role> findAllByOrderByRoleNameAsc();

    /**
     * Find a role by its name.
     */
    Optional<Role> findByRoleName(RoleName roleName);

    /**
     * Check if a role with the given name exists.
     */
    boolean existsByRoleName(RoleName roleName);
}
