package vnpt.vsp.module.course;

import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.FavoriteCourse;
import vnpt.vsp.module.course.entity.RecentCourse;

import java.util.List;

/**
 * Course search service interface.
 * Per Story 3.2 SD-BACK-1: AC-1 (text + geographic search), AC-2 (ST_DWithin), AC-3 (freshness metadata).
 */
public interface CourseSearchService {

    // ─── Search ───────────────────────────────────────────────────────────

    /**
     * Search courses by text and/or geographic filters with pagination.
     * Supports three modes: text-only, nearby-only, or combined text+nearby.
     * Enriches each result with DataFreshnessDto, hasPackage, and updateAvailable.
     *
     * @param request search request with filters and pagination
     * @return paginated search results
     */
    PageResponse<CourseSearchResultDto> searchCourses(CourseSearchRequest request);

    // ─── Favorites ────────────────────────────────────────────────────────

    /**
     * Get all favorites for a user.
     *
     * @param userId the user ID
     * @return list of favorited courses with timestamps
     */
    List<FavoriteCourseDto> getFavorites(Long userId);

    /**
     * Add a course to user's favorites.
     *
     * @param userId the user ID
     * @param courseId the course ID
     * @return the created FavoriteCourse
     */
    FavoriteCourse addFavorite(Long userId, Long courseId);

    /**
     * Remove a course from user's favorites.
     *
     * @param userId the user ID
     * @param courseId the course ID
     */
    void removeFavorite(Long userId, Long courseId);

    // ─── Recent ───────────────────────────────────────────────────────────

    /**
     * Get recently viewed courses for a user.
     * Returns up to 'limit' most recent entries (default 10).
     *
     * @param userId the user ID
     * @param limit maximum number of results
     * @return list of recently viewed courses with timestamps
     */
    List<RecentCourseDto> getRecent(Long userId, int limit);

    /**
     * Record a course view for a user (upsert — updates viewedAt if already exists).
     * Enforces the 10-entry per-user cap by trimming oldest entries.
     *
     * @param userId the user ID
     * @param courseId the course ID
     * @return the recorded RecentCourse
     */
    RecentCourse recordRecentView(Long userId, Long courseId);
}
