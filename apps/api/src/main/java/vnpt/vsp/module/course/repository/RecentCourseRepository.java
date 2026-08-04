package vnpt.vsp.module.course.repository;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.RecentCourse;

import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link RecentCourse} user recently-viewed courses.
 * Capped at 10 per user — trimming is enforced via service layer.
 * Per Story 3.2 SD-BACK-1.
 */
@Repository
public interface RecentCourseRepository extends JpaRepository<RecentCourse, Long> {

    /**
     * Find recent courses for a user, ordered by viewed time descending.
     * Use Pageable to limit results (e.g., top 10).
     */
    List<RecentCourse> findByUserIdOrderByViewedAtDesc(Long userId, Pageable pageable);

    /**
     * Find a specific recent entry by user and course.
     */
    Optional<RecentCourse> findByUserIdAndCourseId(Long userId, Long courseId);

    /**
     * Count entries for a user.
     */
    long countByUserId(Long userId);

    /**
     * Delete the oldest entries for a user beyond the given limit.
     * Keeps the most recent 'limit' entries.
     */
    @Modifying
    @Query(value = """
        DELETE FROM recent_courses rc
        WHERE rc.user_id = :userId
        AND rc.id NOT IN (
            SELECT rc2.id FROM recent_courses rc2
            WHERE rc2.user_id = :userId
            ORDER BY rc2.viewed_at DESC
            LIMIT :limit
        )
        """, nativeQuery = true)
    void deleteOldestByUserIdIfExceedsLimit(@Param("userId") Long userId, @Param("limit") int limit);
}
