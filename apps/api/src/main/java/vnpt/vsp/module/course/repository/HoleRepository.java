package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.Hole;

import java.util.List;
import java.util.Optional;

@Repository
public interface HoleRepository extends JpaRepository<Hole, Long> {

    List<Hole> findByCourseIdOrderByHoleNumber(Long courseId);

    Optional<Hole> findByCourseIdAndHoleNumber(Long courseId, Integer holeNumber);

    boolean existsByCourseIdAndHoleNumber(Long courseId, Integer holeNumber);

    @org.springframework.data.jpa.repository.Query(
        "SELECT COALESCE(SUM(h.par), 0) FROM Hole h WHERE h.course.id = :courseId")
    int sumParByCourseId(@org.springframework.data.repository.query.Param("courseId") Long courseId);
}
