package vnpt.vsp.module.identity.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.identity.entity.RefreshToken;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link RefreshToken} entities.
 * Per Story 2.2 AC-1: refresh tokens rotate on use.
 * Per Story 2.2 AC-3: revoked sessions cannot refresh.
 */
@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    /**
     * Find an active (non-revoked, non-expired) refresh token by its hash for a specific account.
     */
    @Query("SELECT rt FROM RefreshToken rt WHERE rt.golferAccount.id = :accountId AND rt.tokenHash = :tokenHash AND rt.revokedAt IS NULL AND rt.expiresAt > :now")
    Optional<RefreshToken> findActiveByAccountIdAndTokenHash(
            @Param("accountId") Long golferAccountId,
            @Param("tokenHash") String tokenHash,
            @Param("now") Instant now);

    /**
     * List all active (non-revoked, non-expired) sessions for an account, ordered by creation time descending.
     */
    @Query("SELECT rt FROM RefreshToken rt WHERE rt.golferAccount.id = :accountId AND rt.revokedAt IS NULL AND rt.expiresAt > :now ORDER BY rt.createdAt DESC")
    List<RefreshToken> findActiveSessionsByAccountId(
            @Param("accountId") Long golferAccountId,
            @Param("now") Instant now);

    /**
     * Find a session by ID for a specific account.
     */
    Optional<RefreshToken> findByIdAndGolferAccountId(Long id, Long golferAccountId);

    /**
     * Revoke all active sessions for an account (bulk logout).
     */
    @Modifying
    @Query("UPDATE RefreshToken rt SET rt.revokedAt = :revokedAt WHERE rt.golferAccount.id = :accountId AND rt.revokedAt IS NULL AND rt.expiresAt > :now")
    int revokeAllActiveSessions(
            @Param("accountId") Long golferAccountId,
            @Param("revokedAt") Instant revokedAt,
            @Param("now") Instant now);

    /**
     * Delete expired tokens older than a cutoff date (for cleanup job).
     */
    @Modifying
    @Query("DELETE FROM RefreshToken rt WHERE rt.expiresAt < :cutoff")
    int deleteExpiredTokens(@Param("cutoff") Instant cutoff);
}
