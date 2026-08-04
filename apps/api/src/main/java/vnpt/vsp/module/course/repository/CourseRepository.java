package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.Course;

import java.util.List;

@Repository
public interface CourseRepository extends JpaRepository<Course, Long> {

    List<Course> findByFacilityId(Long facilityId);

    List<Course> findByNameContainingIgnoreCase(String name);

    java.util.Optional<Course> findByFacilityIdAndName(Long facilityId, String name);

    @Query("SELECT COUNT(h) FROM Hole h WHERE h.course.id = :courseId")
    long countHolesByCourseId(@Param("courseId") Long courseId);

    /**
     * Find all courses belonging to a specific facility.
     * Uses @Query to explicitly join through the facility relationship.
     * Per Story 3.1 AC-1.
     */
    @Query("SELECT c FROM Course c WHERE c.facility.id = :facilityId")
    List<Course> findByGolfFacilityId(@Param("facilityId") Long facilityId);

    /**
     * Find a course by facility ID and exact name match.
     */
    @Query("SELECT c FROM Course c WHERE c.facility.id = :facilityId AND c.name = :name")
    java.util.Optional<Course> findByGolfFacilityIdAndName(
        @Param("facilityId") Long facilityId,
        @Param("name") String name
    );
}
