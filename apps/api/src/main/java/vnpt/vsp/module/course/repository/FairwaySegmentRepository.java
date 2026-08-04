package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.FairwaySegment;

import java.util.List;

@Repository
public interface FairwaySegmentRepository extends JpaRepository<FairwaySegment, Long> {
    List<FairwaySegment> findByHoleId(Long holeId);
}
