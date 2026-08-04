package vnpt.vsp.module.course;

import vnpt.vsp.module.course.dto.CourseDetailDto;

/**
 * Course detail aggregation service interface.
 * Per Story 3.3 CD-BACK-1: aggregates all detail data for GET /courses/{id}.
 */
public interface CourseDetailService {

    /**
     * Get comprehensive course detail by course ID.
     *
     * @param courseId the course ID
     * @return CourseDetailDto with all fields populated; null fields indicate unavailable data (AC-2)
     * @throws vnpt.vsp.api.error.VspApiException COURSE_001 if course not found
     */
    CourseDetailDto getCourseDetail(Long courseId);
}
