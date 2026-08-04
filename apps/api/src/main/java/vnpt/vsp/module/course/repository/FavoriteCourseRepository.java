package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.FavoriteCourse;

import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link FavoriteCourse} user-course favorites.
 * Per Story 3.2 SD-BACK-1.
 */
@Repository
public interface FavoriteCourseRepository extends JpaRepository<FavoriteCourse, Long> {

    /**
     * Find all favorites for a user, ordered by creation time descending.
     */
    List<FavoriteCourse> findByUserIdOrderByCreatedAtDesc(Long userId);

    /**
     * Find a specific favorite by user and course.
     */
    Optional<FavoriteCourse> findByUserIdAndCourseId(Long userId, Long courseId);

    /**
     * Check if a user has favorited a specific course.
     */
    boolean existsByUserIdAndCourseId(Long userId, Long courseId);

    /**
     * Delete a specific favorite.
     */
    void deleteByUserIdAndCourseId(Long userId, Long courseId);

    /**
     * Count favorites for a user.
     */
    long countByUserId(Long userId);
}
