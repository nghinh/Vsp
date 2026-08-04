package vnpt.vsp.module.score.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.score.entity.ScoreEntry;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ScoreEntryRepository extends JpaRepository<ScoreEntry, UUID> {

    List<ScoreEntry> findByScoreIdOrderByHoleNumberAsc(UUID scoreId);

    Optional<ScoreEntry> findByScoreIdAndHoleNumber(UUID scoreId, Integer holeNumber);
}
