package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.TeeSet;

import java.util.List;

@Repository
public interface TeeSetRepository extends JpaRepository<TeeSet, Long> {
    List<TeeSet> findByCourseId(Long courseId);

    /**
     * Find all tee sets that have a tee box on the given hole.
     * Resolves through TeeBox → TeeSet relationship to support hole-scoped validation.
     */
    @Query("SELECT DISTINCT ts FROM TeeSet ts JOIN ts.teeBoxes tb WHERE tb.hole.id = :holeId")
    List<TeeSet> findByHoleId(@Param("holeId") Long holeId);
}
