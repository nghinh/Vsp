package vnpt.vsp.module.round.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.round.entity.RoundSegment;

import java.util.List;
import java.util.UUID;

@Repository
public interface RoundSegmentRepository
        extends JpaRepository<RoundSegment, RoundSegment.RoundSegmentId> {

    /** The đường of a round, first played first. */
    List<RoundSegment> findByIdRoundIdOrderByIdPositionAsc(UUID roundId);
}
