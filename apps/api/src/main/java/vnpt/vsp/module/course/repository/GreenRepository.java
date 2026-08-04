package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.Green;

import java.util.List;

@Repository
public interface GreenRepository extends JpaRepository<Green, Long> {
    List<Green> findByHoleId(Long holeId);
}
