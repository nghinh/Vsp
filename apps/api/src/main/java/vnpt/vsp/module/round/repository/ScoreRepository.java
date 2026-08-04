package vnpt.vsp.module.round.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.round.entity.Score;

import java.util.List;
import java.util.UUID;

@Repository("roundScoreRepository")
public interface ScoreRepository extends JpaRepository<Score, UUID> {

    List<Score> findByRoundIdAndDeletedAtIsNull(UUID roundId);

    List<Score> findByGolferAccountIdAndDeletedAtIsNull(Long golferAccountId);
}
