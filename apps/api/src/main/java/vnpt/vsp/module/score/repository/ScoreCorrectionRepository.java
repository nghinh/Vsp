package vnpt.vsp.module.score.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.score.entity.ScoreCorrection;

import java.util.List;
import java.util.UUID;

@Repository
public interface ScoreCorrectionRepository extends JpaRepository<ScoreCorrection, UUID> {

    List<ScoreCorrection> findByRoundIdOrderByCorrectedAtDesc(UUID roundId);

    List<ScoreCorrection> findByRoundIdAndPlayerIdOrderByCorrectedAtDesc(UUID roundId, Long playerId);
}
