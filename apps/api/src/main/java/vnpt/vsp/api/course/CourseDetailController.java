package vnpt.vsp.api.course;

import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.course.CourseDetailService;
import vnpt.vsp.module.course.dto.CourseDetailDto;

import java.util.concurrent.TimeUnit;

/**
 * REST controller for course detail endpoint.
 * Per Story 3.3 CD-BACK-1: AC-1 (full detail), AC-2 (null for unavailable), AC-3 (dataQuality).
 */
@RestController
@RequestMapping("/courses")
public class CourseDetailController {

    private final CourseDetailService courseDetailService;

    public CourseDetailController(CourseDetailService courseDetailService) {
        this.courseDetailService = courseDetailService;
    }

    /**
     * Get comprehensive course detail by ID.
     *
     * @param courseId course ID
     * @return CourseDetailDto with all fields; 404 if course not found (COURSE_001)
     */
    @GetMapping("/{courseId}")
    public ResponseEntity<CourseDetailDto> getCourseDetail(@PathVariable Long courseId) {
        CourseDetailDto detail = courseDetailService.getCourseDetail(courseId);

        // ETag from data version number (if available)
        if (detail.getDataFreshness() != null && detail.getDataFreshness().getVersionNumber() != null) {
            String etag = String.format("\"%d\"", detail.getDataFreshness().getVersionNumber());
            return ResponseEntity.ok()
                    .cacheControl(CacheControl.maxAge(5, TimeUnit.MINUTES))
                    .eTag(etag)
                    .body(detail);
        }

        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(5, TimeUnit.MINUTES))
                .body(detail);
    }
}
