package vnpt.vsp.module.course;

import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.TeeSet;
import java.util.List;

/**
 * Admin service interface extending CourseService with admin-specific operations.
 * Per Story 8.1 AC-2: validation before publish.
 */
public interface CourseAdminService extends CourseService {

    /**
     * Validate a course is ready for publication.
     * Checks: facility has name, course has name + holesCount + parTotal,
     * each hole has holeNumber + par + greenLocation.
     *
     * @param courseId the course to validate
     * @return list of validation error messages; empty if publishable
     */
    List<String> validateForPublish(Long courseId);

    @Override
    TeeSet getTeeSet(Long teeSetId);

    @Override
    TeeSet updateTeeSet(Long teeSetId, TeeSet update);
}
