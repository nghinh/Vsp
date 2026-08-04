package vnpt.vsp.module.shot.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.shot.entity.Shot;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ShotRepository extends JpaRepository<Shot, UUID> {

    /** Find all non-deleted shots for a round. */
    List<Shot> findByRoundIdAndDeletedAtIsNull(UUID roundId);

    /** Find all non-deleted shots for a round, ordered by hole then shot. */
    List<Shot> findByRoundIdAndDeletedAtIsNullOrderByHoleNumberAscShotNumberAsc(UUID roundId);

    /** Find all non-deleted shots for a player in a round. */
    List<Shot> findByRoundIdAndPlayerIdAndDeletedAtIsNull(UUID roundId, Long playerId);

    /** Find a shot by idempotency key (for deduplication). */
    Optional<Shot> findByIdempotencyKey(String idempotencyKey);

    /** Count shots for a round (non-deleted). */
    long countByRoundIdAndDeletedAtIsNull(UUID roundId);

    /** Find a shot by ID ignoring deleted rows. */
    Optional<Shot> findByIdAndDeletedAtIsNull(UUID id);
}
