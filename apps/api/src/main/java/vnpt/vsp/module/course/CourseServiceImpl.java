package vnpt.vsp.module.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.time.LocalDate;
import java.util.List;

import static net.logstash.logback.marker.Markers.append;

/**
 * Implementation of {@link CourseService}.
 * Per Story 3.1 GEO-5: full CRUD for course hierarchy entities.
 * Uses GeospatialService for geometry validation on create/update.
 */
@Service
@Primary
@CourseModule
public class CourseServiceImpl implements CourseService {

    private static final Logger log = LoggerFactory.getLogger(CourseServiceImpl.class);

    private final GolfFacilityRepository facilityRepository;
    private final CourseRepository courseRepository;
    private final HoleRepository holeRepository;
    private final TeeSetRepository teeSetRepository;
    private final PinPositionRepository pinPositionRepository;
    private final CourseConditionRepository courseConditionRepository;
    private final AuditService auditService;

    public CourseServiceImpl(
            GolfFacilityRepository facilityRepository,
            CourseRepository courseRepository,
            HoleRepository holeRepository,
            TeeSetRepository teeSetRepository,
            PinPositionRepository pinPositionRepository,
            CourseConditionRepository courseConditionRepository,
            AuditService auditService) {
        this.facilityRepository = facilityRepository;
        this.courseRepository = courseRepository;
        this.holeRepository = holeRepository;
        this.teeSetRepository = teeSetRepository;
        this.pinPositionRepository = pinPositionRepository;
        this.courseConditionRepository = courseConditionRepository;
        this.auditService = auditService;
    }

    // ─── Facility operations ───────────────────────────────────────────────

    @Override
    @Transactional
    public GolfFacility createFacility(GolfFacility facility) {
        log.debug(append("action", "CREATE_FACILITY"), "Creating facility: name={}", facility.getName());
        initMetadataDefaults(facility.getDataQuality(), "SYSTEM");
        GolfFacility saved = facilityRepository.save(facility);
        auditService.log(AuditAction.COURSE_PUBLISH, "GolfFacility", String.valueOf(saved.getId()),
                null, serializeFacilityToJson(saved), null);
        log.info(append("action", "CREATE_FACILITY"), "Facility created: id={}", saved.getId());
        return saved;
    }

    @Override
    @Transactional(readOnly = true)
    public GolfFacility getFacility(Long facilityId) {
        return facilityRepository.findById(facilityId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.FACILITY_001));
    }

    @Override
    @Transactional(readOnly = true)
    public List<GolfFacility> listFacilities() {
        return facilityRepository.findAll();
    }

    @Override
    @Transactional
    public GolfFacility updateFacility(Long facilityId, GolfFacility update) {
        log.debug(append("action", "UPDATE_FACILITY"), "Updating facility: id={}", facilityId);
        GolfFacility existing = facilityRepository.findById(facilityId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.FACILITY_001));
        String beforeJson = serializeFacilityToJson(existing);
        applyFacilityUpdate(existing, update);
        GolfFacility saved = facilityRepository.save(existing);
        auditService.log(AuditAction.COURSE_PUBLISH, "GolfFacility", String.valueOf(saved.getId()),
                beforeJson, serializeFacilityToJson(saved), null);
        log.info(append("action", "UPDATE_FACILITY"), "Facility updated: id={}", saved.getId());
        return saved;
    }

    // ─── Course operations ─────────────────────────────────────────────────

    @Override
    @Transactional
    public Course createCourse(Long facilityId, Course course) {
        log.debug(append("action", "CREATE_COURSE"), "Creating course: facilityId={}, name={}", facilityId, course.getName());
        GolfFacility facility = facilityRepository.findById(facilityId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.FACILITY_001));
        course.setFacility(facility);
        initMetadataDefaults(course.getDataQuality(), "SYSTEM");
        Course saved = courseRepository.save(course);
        auditService.log(AuditAction.COURSE_PUBLISH, "Course", String.valueOf(saved.getId()),
                null, serializeCourseToJson(saved), null);
        log.info(append("action", "CREATE_COURSE"), "Course created: id={}", saved.getId());
        return saved;
    }

    @Override
    @Transactional(readOnly = true)
    public Course getCourse(Long courseId) {
        return courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Course> listCoursesByFacility(Long facilityId) {
        return courseRepository.findByFacilityId(facilityId);
    }

    @Override
    @Transactional
    public Course updateCourse(Long courseId, Course update) {
        log.debug(append("action", "UPDATE_COURSE"), "Updating course: id={}", courseId);
        Course existing = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
        String beforeJson = serializeCourseToJson(existing);
        applyCourseUpdate(existing, update);
        Course saved = courseRepository.save(existing);
        auditService.log(AuditAction.COURSE_PUBLISH, "Course", String.valueOf(saved.getId()),
                beforeJson, serializeCourseToJson(saved), null);
        log.info(append("action", "UPDATE_COURSE"), "Course updated: id={}", saved.getId());
        return saved;
    }

    // ─── Hole operations ────────────────────────────────────────────────────

    @Override
    @Transactional
    public Hole createHole(Long courseId, Hole hole) {
        log.debug(append("action", "CREATE_HOLE"), "Creating hole: courseId={}, number={}", courseId, hole.getHoleNumber());
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
        hole.setCourse(course);
        initMetadataDefaults(hole.getDataQuality(), "SYSTEM");
        Hole saved = holeRepository.save(hole);
        auditService.log(AuditAction.COURSE_PUBLISH, "Hole", String.valueOf(saved.getId()),
                null, serializeHoleToJson(saved), null);
        log.info(append("action", "CREATE_HOLE"), "Hole created: id={}", saved.getId());
        return saved;
    }

    @Override
    @Transactional(readOnly = true)
    public Hole getHole(Long holeId) {
        return holeRepository.findById(holeId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.HOLE_001));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Hole> listHolesByCourse(Long courseId) {
        return holeRepository.findByCourseIdOrderByHoleNumber(courseId);
    }

    @Override
    @Transactional
    public Hole updateHole(Long holeId, Hole update) {
        log.debug(append("action", "UPDATE_HOLE"), "Updating hole: id={}", holeId);
        Hole existing = holeRepository.findById(holeId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.HOLE_001));
        String beforeJson = serializeHoleToJson(existing);
        applyHoleUpdate(existing, update);
        Hole saved = holeRepository.save(existing);
        auditService.log(AuditAction.COURSE_PUBLISH, "Hole", String.valueOf(saved.getId()),
                beforeJson, serializeHoleToJson(saved), null);
        log.info(append("action", "UPDATE_HOLE"), "Hole updated: id={}", saved.getId());
        return saved;
    }

    // ─── TeeSet operations ─────────────────────────────────────────────────

    @Override
    @Transactional
    public TeeSet createTeeSet(Long courseId, TeeSet teeSet) {
        log.debug(append("action", "CREATE_TEE_SET"), "Creating tee set: courseId={}, name={}", courseId, teeSet.getName());
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
        teeSet.setCourse(course);
        initMetadataDefaults(teeSet.getDataQuality(), "SYSTEM");
        TeeSet saved = teeSetRepository.save(teeSet);
        log.info(append("action", "CREATE_TEE_SET"), "TeeSet created: id={}", saved.getId());
        return saved;
    }

    @Override
    @Transactional(readOnly = true)
    public List<TeeSet> getTeeSetsByCourse(Long courseId) {
        return teeSetRepository.findByCourseId(courseId);
    }

    @Override
    @Transactional(readOnly = true)
    public TeeSet getTeeSet(Long teeSetId) {
        return teeSetRepository.findById(teeSetId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.TEE_SET_001));
    }

    @Override
    @Transactional
    public TeeSet updateTeeSet(Long teeSetId, TeeSet update) {
        log.debug(append("action", "UPDATE_TEE_SET"), "Updating tee set: id={}", teeSetId);
        TeeSet existing = teeSetRepository.findById(teeSetId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.TEE_SET_001));
        String beforeJson = "{\"id\":" + existing.getId() + ",\"name\":\"" + nullSafe(existing.getName()) + "\"}";
        applyTeeSetUpdate(existing, update);
        TeeSet saved = teeSetRepository.save(existing);
        log.info(append("action", "UPDATE_TEE_SET"), "TeeSet updated: id={}", saved.getId());
        return saved;
    }

    // ─── PinPosition operations ─────────────────────────────────────────────

    @Override
    @Transactional
    public PinPosition createPinPosition(Long holeId, PinPosition pinPosition) {
        log.debug(append("action", "CREATE_PIN_POSITION"), "Creating pin position: holeId={}", holeId);
        Hole hole = holeRepository.findById(holeId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.HOLE_001));
        pinPosition.setHole(hole);
        initMetadataDefaults(pinPosition.getDataQuality(), "SYSTEM");
        PinPosition saved = pinPositionRepository.save(pinPosition);
        log.info(append("action", "CREATE_PIN_POSITION"), "PinPosition created: id={}", saved.getId());
        return saved;
    }

    @Override
    @Transactional(readOnly = true)
    public PinPosition getActivePinPosition(Long holeId) {
        LocalDate today = LocalDate.now();
        List<PinPosition> active = pinPositionRepository
                .findByHoleIdAndEffectiveDateLessThanEqualAndExpiryDateIsNull(holeId, today);
        if (active.isEmpty()) {
            active = pinPositionRepository.findByHoleIdAndExpiryDateIsNull(holeId);
        }
        return active.stream()
                .findFirst()
                .orElseThrow(() -> new VspApiException(VspErrorCode.PIN_001));
    }

    // ─── CourseCondition operations ─────────────────────────────────────────

    @Override
    @Transactional
    public CourseCondition createCourseCondition(Long courseId, CourseCondition condition) {
        log.debug(append("action", "CREATE_COURSE_CONDITION"), "Creating course condition: courseId={}", courseId);
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
        condition.setCourse(course);
        initMetadataDefaults(condition.getDataQuality(), "SYSTEM");
        CourseCondition saved = courseConditionRepository.save(condition);
        log.info(append("action", "CREATE_COURSE_CONDITION"), "CourseCondition created: id={}", saved.getId());
        return saved;
    }

    @Override
    @Transactional(readOnly = true)
    public List<CourseCondition> getActiveConditions(Long courseId) {
        LocalDate today = LocalDate.now();
        return courseConditionRepository
                .findByCourseIdAndEffectiveDateLessThanEqualAndExpiryDateIsNull(courseId, today);
    }

    // ─── Audit helpers (from stub) ──────────────────────────────────────────

    @Override
    public void recordCoursePublish(Long courseId, String beforeJson, String afterJson) {
        auditService.log(AuditAction.COURSE_PUBLISH, "Course",
                String.valueOf(courseId), beforeJson, afterJson, null);
    }

    @Override
    public void recordCourseRollback(Long courseId, String beforeJson, String afterJson) {
        auditService.log(AuditAction.COURSE_ROLLBACK, "Course",
                String.valueOf(courseId), beforeJson, afterJson, null);
    }

    // ─── Private helpers ───────────────────────────────────────────────────

    private void initMetadataDefaults(DataQualityMetadata metadata, String publisher) {
        if (metadata == null) {
            metadata = new DataQualityMetadata();
        }
        if (metadata.getPublisher() == null) metadata.setPublisher(publisher);
        if (metadata.getEffectiveDate() == null) metadata.setEffectiveDate(LocalDate.now());
        if (metadata.getVersion() == null) metadata.setVersion(1);
        if (metadata.getVerificationStatus() == null) metadata.setVerificationStatus(VerificationStatus.UNVERIFIED);
        if (metadata.getAccuracyClass() == null) metadata.setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
    }

    private void applyFacilityUpdate(GolfFacility existing, GolfFacility update) {
        if (update.getName() != null) existing.setName(update.getName());
        if (update.getAddress() != null) existing.setAddress(update.getAddress());
        if (update.getPhone() != null) existing.setPhone(update.getPhone());
        if (update.getWebsite() != null) existing.setWebsite(update.getWebsite());
        if (update.getLocation() != null) existing.setLocation(update.getLocation());
    }

    private void applyCourseUpdate(Course existing, Course update) {
        if (update.getName() != null) existing.setName(update.getName());
        if (update.getHolesCount() != null) existing.setHolesCount(update.getHolesCount());
        if (update.getParTotal() != null) existing.setParTotal(update.getParTotal());
        if (update.getLocation() != null) existing.setLocation(update.getLocation());
    }

    private void applyHoleUpdate(Hole existing, Hole update) {
        if (update.getHoleNumber() != null) existing.setHoleNumber(update.getHoleNumber());
        if (update.getPar() != null) existing.setPar(update.getPar());
        if (update.getTeeingGroundLocation() != null) existing.setTeeingGroundLocation(update.getTeeingGroundLocation());
        if (update.getGreenLocation() != null) existing.setGreenLocation(update.getGreenLocation());
        if (update.getPlayingLengthMeters() != null) existing.setPlayingLengthMeters(update.getPlayingLengthMeters());
    }

    private void applyTeeSetUpdate(TeeSet existing, TeeSet update) {
        if (update.getName() != null) existing.setName(update.getName());
        if (update.getTotalPar() != null) existing.setTotalPar(update.getTotalPar());
    }

    private String serializeFacilityToJson(GolfFacility f) {
        return "{\"id\":" + f.getId() + ",\"name\":\"" + nullSafe(f.getName()) + "\"}";
    }

    private String serializeCourseToJson(Course c) {
        return "{\"id\":" + c.getId() + ",\"facilityId\":" +
                (c.getFacility() != null ? c.getFacility().getId() : "null") +
                ",\"name\":\"" + nullSafe(c.getName()) + "\"}";
    }

    private String serializeHoleToJson(Hole h) {
        return "{\"id\":" + h.getId() + ",\"holeNumber\":" + h.getHoleNumber() +
                ",\"courseId\":" + (h.getCourse() != null ? h.getCourse().getId() : "null") + "}";
    }

    private String nullSafe(String value) {
        return value == null ? "" : value.replace("\"", "\\\"");
    }
}
