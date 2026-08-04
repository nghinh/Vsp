package vnpt.vsp.module.identity.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.identity.entity.GolferAccount;

import java.util.Optional;

/**
 * Repository for {@link GolferAccount} entities.
 */
@Repository
public interface GolferAccountRepository extends JpaRepository<GolferAccount, Long> {

    Optional<GolferAccount> findByPhone(String phone);

    Optional<GolferAccount> findByEmail(String email);

    Optional<GolferAccount> findByGoogleSubject(String googleSubject);

    Optional<GolferAccount> findByAppleSubject(String appleSubject);

    boolean existsByPhone(String phone);

    boolean existsByEmail(String email);

    boolean existsByGoogleSubject(String googleSubject);

    boolean existsByAppleSubject(String appleSubject);

    Optional<GolferAccount> findByPhoneOrEmail(String phone, String email);
}
