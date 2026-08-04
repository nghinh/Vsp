package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.Bunker;

import java.util.List;

@Repository
public interface BunkerRepository extends JpaRepository<Bunker, Long> {
    List<Bunker> findByHoleId(Long holeId);
}
