package vnpt.vsp.module.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.util.ArrayList;
import java.util.List;

/**
 * Implementation of {@link CourseAdminService}.
 * Per Story 8.1 AC-2: validates course is ready for publication.
 * Delegates all CourseService CRUD operations to CourseServiceImpl.
 */
@Service
@CourseModule
public class CourseAdminServiceImpl implements CourseAdminService {

    private static final Logger log = LoggerFactory.getLogger(CourseAdminServiceImpl.class);

    private final CourseService courseService;
    private final GolfFacilityRepository facilityRepository;
    private final CourseRepository courseRepository;
    private final HoleRepository holeRepository;
    private final TeeSetRepository teeSetRepository;

    public CourseAdminServiceImpl(
            CourseService courseService,
            GolfFacilityRepository facilityRepository,
            CourseRepository courseRepository,
            HoleRepository holeRepository,
            TeeSetRepository teeSetRepository) {
        this.courseService = courseService;
        this.facilityRepository = facilityRepository;
        this.courseRepository = courseRepository;
        this.holeRepository = holeRepository;
        this.teeSetRepository = teeSetRepository;
    }

    // ─── CourseService CRUD delegation ────────────────────────────────────────

    @Override
    public GolfFacility createFacility(GolfFacility facility) {
        return courseService.createFacility(facility);
    }

    @Override
    public GolfFacility getFacility(Long facilityId) {
        return courseService.getFacility(facilityId);
    }

    @Override
    public List<GolfFacility> listFacilities() {
        return courseService.listFacilities();
    }

    @Override
    public GolfFacility updateFacility(Long facilityId, GolfFacility update) {
        return courseService.updateFacility(facilityId, update);
    }

    @Override
    public Course createCourse(Long facilityId, Course course) {
        return courseService.createCourse(facilityId, course);
    }

    @Override
    public Course getCourse(Long courseId) {
        return courseService.getCourse(courseId);
    }

    @Override
    public List<Course> listCoursesByFacility(Long facilityId) {
        return courseService.listCoursesByFacility(facilityId);
    }

    @Override
    public Course updateCourse(Long courseId, Course update) {
        return courseService.updateCourse(courseId, update);
    }

    @Override
    public Hole createHole(Long courseId, Hole hole) {
        return courseService.createHole(courseId, hole);
    }

    @Override
    public Hole getHole(Long holeId) {
        return courseService.getHole(holeId);
    }

    @Override
    public List<Hole> listHolesByCourse(Long courseId) {
        return courseService.listHolesByCourse(courseId);
    }

    @Override
    public Hole updateHole(Long holeId, Hole update) {
        return courseService.updateHole(holeId, update);
    }

    @Override
    public TeeSet createTeeSet(Long courseId, TeeSet teeSet) {
        return courseService.createTeeSet(courseId, teeSet);
    }

    @Override
    public List<TeeSet> getTeeSetsByCourse(Long courseId) {
        return courseService.getTeeSetsByCourse(courseId);
    }

    @Override
    public TeeSet getTeeSet(Long teeSetId) {
        return courseService.getTeeSet(teeSetId);
    }

    @Override
    public TeeSet updateTeeSet(Long teeSetId, TeeSet update) {
        return courseService.updateTeeSet(teeSetId, update);
    }

    @Override
    public PinPosition createPinPosition(Long holeId, PinPosition pinPosition) {
        return courseService.createPinPosition(holeId, pinPosition);
    }

    @Override
    public PinPosition getActivePinPosition(Long holeId) {
        return courseService.getActivePinPosition(holeId);
    }

    @Override
    public CourseCondition createCourseCondition(Long courseId, CourseCondition condition) {
        return courseService.createCourseCondition(courseId, condition);
    }

    @Override
    public List<CourseCondition> getActiveConditions(Long courseId) {
        return courseService.getActiveConditions(courseId);
    }

    @Override
    public void recordCoursePublish(Long courseId, String beforeJson, String afterJson) {
        courseService.recordCoursePublish(courseId, beforeJson, afterJson);
    }

    @Override
    public void recordCourseRollback(Long courseId, String beforeJson, String afterJson) {
        courseService.recordCourseRollback(courseId, beforeJson, afterJson);
    }

    // ─── Admin-specific: validateForPublish ───────────────────────────────────

    @Override
    public List<String> validateForPublish(Long courseId) {
        List<String> errors = new ArrayList<>();

        Course course = courseRepository.findById(courseId).orElse(null);
        if (course == null) {
            errors.add("Course not found");
            return errors;
        }

        // Facility validation
        GolfFacility facility = course.getFacility();
        if (facility == null || facility.getName() == null || facility.getName().isBlank()) {
            errors.add("Facility name is required");
        }

        // Course-level validation
        if (course.getName() == null || course.getName().isBlank()) {
            errors.add("Course name is required for publication");
        }
        if (course.getHolesCount() == null || course.getHolesCount() < 1) {
            errors.add("Course must have a valid holes count");
        }
        if (course.getParTotal() == null || course.getParTotal() < 1) {
            errors.add("Course must have a valid total par");
        }

        // Hole-level validation
        List<Hole> holes = holeRepository.findByCourseIdOrderByHoleNumber(courseId);
        if (holes.isEmpty()) {
            errors.add("Course must have at least one hole for publication");
        }
        for (Hole hole : holes) {
            if (hole.getHoleNumber() == null) {
                errors.add("Hole number is required");
            }
            if (hole.getPar() == null) {
                errors.add("Hole " + hole.getHoleNumber() + " par is required");
            }
            if (hole.getGreenLocation() == null || hole.getGreenLocation().isBlank()) {
                errors.add("Hole " + hole.getHoleNumber() + " green location is required");
            }
        }

        log.debug("validateForPublish courseId={}: {} errors", courseId, errors.size());
        return errors;
    }
}
