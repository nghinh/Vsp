package vnpt.vsp.module.score.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.score.entity.Score;

import java.util.List;
import java.util.UUID;

@Repository("scoreModuleRepository")
public interface ScoreRepository extends JpaRepository<Score, UUID> {

    List<Score> findByRoundIdAndDeletedAtIsNull(UUID roundId);

    List<Score> findByGolferAccountIdAndDeletedAtIsNull(Long golferAccountId);

    long countByRoundIdAndDeletedAtIsNull(UUID roundId);
}
