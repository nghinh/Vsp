package vnpt.vsp.module.round.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.round.entity.Round;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RoundRepository extends JpaRepository<Round, UUID> {

    List<Round> findByGolferAccountIdAndDeletedAtIsNull(Long golferAccountId);

    /**
     * Paginated list of a golfer's rounds (most recent first), excluding soft-deleted.
     * Used by GET /rounds to sync the authenticated golfer's round history.
     */
    Page<Round> findByGolferAccountIdAndDeletedAtIsNullOrderByStartedAtDesc(
            Long golferAccountId, Pageable pageable);

    Optional<Round> findByIdAndGolferAccountId(UUID id, Long golferAccountId);

    Optional<Round> findByIdAndGolferAccountIdAndDeletedAtIsNull(UUID id, Long golferAccountId);

    long countByGolferAccountIdAndDeletedAtIsNull(Long golferAccountId);

    @Query("SELECT r FROM Round r WHERE r.golferAccountId = :accountId AND r.deletedAt IS NULL ORDER BY r.startedAt DESC")
    List<Round> findActiveByGolferAccountId(@Param("accountId") Long golferAccountId);

    /**
     * Find all in-progress rounds that use a given tournament policy.
     * Used to propagate policy version bumps to active tournament rounds.
     * Per Story 12.1 Slice F.
     */
    List<Round> findByTournamentPolicyIdAndStatusAndDeletedAtIsNull(
            java.util.UUID tournamentPolicyId, Round.RoundStatus status);
}
