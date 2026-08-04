package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.TeeBox;

import java.util.List;

@Repository
public interface TeeBoxRepository extends JpaRepository<TeeBox, Long> {
    List<TeeBox> findByHoleId(Long holeId);
    List<TeeBox> findByTeeSetId(Long teeSetId);
}
