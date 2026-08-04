package vnpt.vsp.module.role.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.role.entity.AdminAccount;

import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link AdminAccount} entities.
 */
@Repository
@vnpt.vsp.module.role.RoleModule
public interface AdminAccountRepository extends JpaRepository<AdminAccount, Long> {

    /**
     * Find an admin account by golfer account ID.
     */
    Optional<AdminAccount> findByGolferAccountId(Long golferAccountId);

    /**
     * Check if an admin account exists for a golfer account ID.
     */
    boolean existsByGolferAccountId(Long golferAccountId);

    /**
     * Find all admin accounts.
     */
    List<AdminAccount> findAll();
}
