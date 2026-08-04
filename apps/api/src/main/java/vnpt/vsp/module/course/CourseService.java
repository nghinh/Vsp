package vnpt.vsp.module.course;

import vnpt.vsp.module.course.entity.*;

import java.util.List;

/**
 * Course module public service interface.
 * Exposes course catalog and metadata operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 * Per Story 3.1 GEO-5: full CRUD for course hierarchy entities.
 */
public interface CourseService {

    // ─── Facility operations ───────────────────────────────────────────────

    /**
     * Create a new golf facility.
     */
    GolfFacility createFacility(GolfFacility facility);

    /**
     * Get a facility by ID.
     */
    GolfFacility getFacility(Long facilityId);

    /**
     * List all facilities.
     */
    List<GolfFacility> listFacilities();

    /**
     * Update an existing facility.
     */
    GolfFacility updateFacility(Long facilityId, GolfFacility update);

    // ─── Course operations ─────────────────────────────────────────────────

    /**
     * Create a new course under a facility.
     */
    Course createCourse(Long facilityId, Course course);

    /**
     * Get a course by ID.
     */
    Course getCourse(Long courseId);

    /**
     * List all courses belonging to a facility.
     */
    List<Course> listCoursesByFacility(Long facilityId);

    /**
     * Update an existing course.
     */
    Course updateCourse(Long courseId, Course update);

    // ─── Hole operations ────────────────────────────────────────────────────

    /**
     * Create a new hole under a course.
     */
    Hole createHole(Long courseId, Hole hole);

    /**
     * Get a hole by ID.
     */
    Hole getHole(Long holeId);

    /**
     * List all holes for a course, ordered by hole number.
     */
    List<Hole> listHolesByCourse(Long courseId);

    /**
     * Update an existing hole.
     */
    Hole updateHole(Long holeId, Hole update);

    // ─── TeeSet operations ─────────────────────────────────────────────────

    /**
     * Create a new tee set for a course.
     */
    TeeSet createTeeSet(Long courseId, TeeSet teeSet);

    /**
     * Get all tee sets for a course.
     */
    List<TeeSet> getTeeSetsByCourse(Long courseId);

    /**
     * Get a tee set by ID.
     */
    TeeSet getTeeSet(Long teeSetId);

    /**
     * Update an existing tee set (partial update — only non-null fields are applied).
     */
    TeeSet updateTeeSet(Long teeSetId, TeeSet update);

    // ─── PinPosition operations ─────────────────────────────────────────────

    /**
     * Create a new pin position for a hole.
     */
    PinPosition createPinPosition(Long holeId, PinPosition pinPosition);

    /**
     * Get the currently active pin position for a hole (effective <= today, expiry is null).
     */
    PinPosition getActivePinPosition(Long holeId);

    // ─── CourseCondition operations ─────────────────────────────────────────

    /**
     * Create a new course condition.
     */
    CourseCondition createCourseCondition(Long courseId, CourseCondition condition);

    /**
     * Get all currently active conditions for a course.
     */
    List<CourseCondition> getActiveConditions(Long courseId);

    // ─── Audit helpers ───────────────────────────────────────────────────

    /**
     * Records a course publish event in the audit trail.
     *
     * @param courseId the identifier of the published course
     * @param beforeJson JSON snapshot of the course before publish (draft state)
     * @param afterJson  JSON snapshot of the course after  publish (published state)
     */
    void recordCoursePublish(Long courseId, String beforeJson, String afterJson);

    /**
     * Records a course rollback event in the audit trail.
     *
     * @param courseId the identifier of the rolled-back course
     * @param beforeJson JSON snapshot of the course before rollback
     * @param afterJson  JSON snapshot of the course after  rollback (prior published version)
     */
    void recordCourseRollback(Long courseId, String beforeJson, String afterJson);
}
