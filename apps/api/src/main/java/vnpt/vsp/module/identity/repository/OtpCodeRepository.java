package vnpt.vsp.module.identity.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.identity.entity.OtpCode;

import java.time.Instant;
import java.util.Optional;

/**
 * Repository for {@link OtpCode} entities.
 */
@Repository
public interface OtpCodeRepository extends JpaRepository<OtpCode, Long> {

    @Query("""
        SELECT o FROM OtpCode o
        WHERE o.golferAccount.id = :accountId
        AND o.type = :type
        AND o.verifiedAt IS NULL
        AND o.expiresAt > :now
        ORDER BY o.createdAt DESC
        LIMIT 1
        """)
    Optional<OtpCode> findActiveOtp(
            @Param("accountId") Long accountId,
            @Param("type") OtpCode.OtpType type,
            @Param("now") Instant now);

    @Query("""
        SELECT o FROM OtpCode o
        WHERE o.golferAccount.id = :accountId
        AND o.code = :code
        AND o.type = :type
        AND o.verifiedAt IS NULL
        AND o.expiresAt > :now
        ORDER BY o.createdAt DESC
        LIMIT 1
        """)
    Optional<OtpCode> findActiveOtpByCode(
            @Param("accountId") Long accountId,
            @Param("code") String code,
            @Param("type") OtpCode.OtpType type,
            @Param("now") Instant now);

    void deleteByGolferAccountIdAndType(Long accountId, OtpCode.OtpType type);

    void deleteByExpiresAtBefore(Instant before);
}
