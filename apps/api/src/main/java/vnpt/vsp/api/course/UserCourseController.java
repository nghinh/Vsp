package vnpt.vsp.api.course;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.course.CourseSearchService;
import vnpt.vsp.module.course.dto.FavoriteCourseDto;
import vnpt.vsp.module.course.dto.RecentCourseDto;
import vnpt.vsp.module.course.entity.FavoriteCourse;
import vnpt.vsp.module.course.entity.RecentCourse;

import java.net.URI;
import java.util.List;

/**
 * REST controller for user-scoped course operations (favorites and recent views).
 * Per Story 3.2 SD-BACK-2: AC-1 (favorites, recent).
 * Uses the authenticated user ID from the security context.
 */
@RestController
@RequestMapping("/users/me")
public class UserCourseController {

    private final CourseSearchService courseSearchService;

    public UserCourseController(CourseSearchService courseSearchService) {
        this.courseSearchService = courseSearchService;
    }

    // ─── Favorites ────────────────────────────────────────────────────────

    /**
     * List all favorited courses for the authenticated user.
     */
    @GetMapping("/favorites")
    public ResponseEntity<List<FavoriteCourseDto>> getFavorites(Authentication authentication) {
        Long userId = getUserId(authentication);
        List<FavoriteCourseDto> favorites = courseSearchService.getFavorites(userId);
        return ResponseEntity.ok(favorites);
    }

    /**
     * Add a course to the authenticated user's favorites.
     */
    @PostMapping("/favorites/{courseId}")
    public ResponseEntity<Void> addFavorite(
            Authentication authentication,
            @PathVariable Long courseId) {
        Long userId = getUserId(authentication);
        courseSearchService.addFavorite(userId, courseId);
        return ResponseEntity
                .created(URI.create("/users/me/favorites/" + courseId))
                .build();
    }

    /**
     * Remove a course from the authenticated user's favorites.
     */
    @DeleteMapping("/favorites/{courseId}")
    public ResponseEntity<Void> removeFavorite(
            Authentication authentication,
            @PathVariable Long courseId) {
        Long userId = getUserId(authentication);
        courseSearchService.removeFavorite(userId, courseId);
        return ResponseEntity.noContent().build();
    }

    // ─── Recent ───────────────────────────────────────────────────────────

    /**
     * List recently viewed courses for the authenticated user (last 10).
     */
    @GetMapping("/recent")
    public ResponseEntity<List<RecentCourseDto>> getRecent(
            Authentication authentication,
            @RequestParam(defaultValue = "10") int limit) {
        Long userId = getUserId(authentication);
        List<RecentCourseDto> recent = courseSearchService.getRecent(userId, limit);
        return ResponseEntity.ok(recent);
    }

    /**
     * Record a course view for the authenticated user.
     * Updates viewedAt if the course was already recently viewed.
     * Enforces the 10-entry per-user cap by trimming oldest entries.
     */
    @PostMapping("/recent/{courseId}")
    public ResponseEntity<Void> recordRecentView(
            Authentication authentication,
            @PathVariable Long courseId) {
        Long userId = getUserId(authentication);
        courseSearchService.recordRecentView(userId, courseId);
        return ResponseEntity
                .created(URI.create("/users/me/recent/" + courseId))
                .build();
    }

    // ─── Helper ───────────────────────────────────────────────────────────

    private Long getUserId(Authentication authentication) {
        return (Long) authentication.getPrincipal();
    }
}
