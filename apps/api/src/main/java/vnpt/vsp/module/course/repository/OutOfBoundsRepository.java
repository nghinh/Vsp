package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.OutOfBounds;

import java.util.List;

@Repository
public interface OutOfBoundsRepository extends JpaRepository<OutOfBounds, Long> {
    List<OutOfBounds> findByHoleId(Long holeId);
}
