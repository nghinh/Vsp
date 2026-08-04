package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.CartPath;

import java.util.List;

@Repository
public interface CartPathRepository extends JpaRepository<CartPath, Long> {
    List<CartPath> findByHoleId(Long holeId);
}
