package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;

import java.util.List;
import java.util.Optional;

@Repository
public interface DataVersionRepository extends JpaRepository<DataVersion, Long> {

    List<DataVersion> findByCourseIdOrderByVersionNumberDesc(Long courseId);

    Optional<DataVersion> findByCourseIdAndVersionNumber(Long courseId, Integer versionNumber);

    List<DataVersion> findByCourseIdAndStatus(Long courseId, DataVersionStatus status);

    /**
     * Returns the latest published version for a course.
     */
    @Query("SELECT dv FROM DataVersion dv WHERE dv.course.id = :courseId " +
           "AND dv.status = 'PUBLISHED' ORDER BY dv.versionNumber DESC LIMIT 1")
    Optional<DataVersion> findLatestPublishedByCourseId(@Param("courseId") Long courseId);

    /**
     * Returns the latest version number for a course (regardless of status).
     */
    @Query("SELECT MAX(dv.versionNumber) FROM DataVersion dv WHERE dv.course.id = :courseId")
    Optional<Integer> findMaxVersionNumberByCourseId(@Param("courseId") Long courseId);
}
