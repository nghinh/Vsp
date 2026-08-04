package vnpt.vsp.module.identity.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.identity.entity.PasswordRecoveryToken;

import java.time.Instant;
import java.util.Optional;

/**
 * Repository for {@link PasswordRecoveryToken} entities.
 */
@Repository
public interface PasswordRecoveryTokenRepository extends JpaRepository<PasswordRecoveryToken, Long> {

    @Query("""
        SELECT t FROM PasswordRecoveryToken t
        WHERE t.token = :token
        AND t.usedAt IS NULL
        AND t.expiresAt > :now
        """)
    Optional<PasswordRecoveryToken> findActiveToken(
            @Param("token") String token,
            @Param("now") Instant now);

    void deleteByGolferAccountId(Long accountId);

    void deleteByExpiresAtBefore(Instant before);
}
