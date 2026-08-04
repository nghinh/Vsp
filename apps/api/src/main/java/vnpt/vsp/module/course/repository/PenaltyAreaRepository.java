package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.PenaltyArea;

import java.util.List;

@Repository
public interface PenaltyAreaRepository extends JpaRepository<PenaltyArea, Long> {
    List<PenaltyArea> findByHoleId(Long holeId);
}
