package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.WaterHazard;

import java.util.List;

@Repository
public interface WaterHazardRepository extends JpaRepository<WaterHazard, Long> {
    List<WaterHazard> findByHoleId(Long holeId);
}
