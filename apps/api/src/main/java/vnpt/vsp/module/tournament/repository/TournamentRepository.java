package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.tournament.entity.Tournament;
import vnpt.vsp.module.tournament.entity.TournamentStatus;

import java.util.List;
import java.util.UUID;

@Repository
public interface TournamentRepository extends JpaRepository<Tournament, UUID>,
        JpaSpecificationExecutor<Tournament> {

    List<Tournament> findByStatus(TournamentStatus status);

    List<Tournament> findByCourseId(Long courseId);

    List<Tournament> findByStatusAndCourseId(TournamentStatus status, Long courseId);
}
