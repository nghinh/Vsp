package vnpt.vsp.module.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.function.Executable;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseServiceImpl}.
 * Per Story 3.1 GEO-5: CRUD coverage for all entity types.
 * Tests: facility CRUD, course CRUD, hole CRUD, tee set, pin position, course condition.
 */
@ExtendWith(MockitoExtension.class)
class CourseServiceImplTest {

    @Mock private GolfFacilityRepository facilityRepository;
    @Mock private CourseRepository courseRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private TeeSetRepository teeSetRepository;
    @Mock private PinPositionRepository pinPositionRepository;
    @Mock private CourseConditionRepository courseConditionRepository;
    @Mock private AuditService auditService;

    private CourseServiceImpl courseService;

    @BeforeEach
    void setUp() {
        courseService = new CourseServiceImpl(
                facilityRepository, courseRepository, holeRepository,
                teeSetRepository, pinPositionRepository, courseConditionRepository,
                auditService);
    }

    // ─── Facility tests ──────────────────────────────────────────────────

    @Test
    void createFacility_savesAndReturnsFacility() {
        GolfFacility facility = new GolfFacility();
        facility.setName("Tan Son Nhat Golf");
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("SYSTEM");
        facility.setDataQuality(dqm);

        when(facilityRepository.save(any(GolfFacility.class)))
                .thenAnswer(inv -> { GolfFacility f = inv.getArgument(0); f.setId(1L); return f; });

        GolfFacility result = courseService.createFacility(facility);

        assertNotNull(result);
        assertEquals(1L, result.getId());
        assertEquals("Tan Son Nhat Golf", result.getName());
        verify(auditService).log(any(), eq("GolfFacility"), eq("1"), isNull(), anyString(), isNull());
    }

    @Test
    void getFacility_returnsFacility_whenExists() {
        GolfFacility facility = new GolfFacility();
        facility.setId(1L);
        facility.setName("Test Facility");

        when(facilityRepository.findById(1L)).thenReturn(Optional.of(facility));

        GolfFacility result = courseService.getFacility(1L);

        assertEquals("Test Facility", result.getName());
    }

    @Test
    void getFacility_throwsNotFound_whenNotExists() {
        when(facilityRepository.findById(999L)).thenReturn(Optional.empty());

        assertThrows(VspApiException.class, () -> courseService.getFacility(999L));
    }

    @Test
    void listFacilities_returnsAll() {
        GolfFacility f1 = new GolfFacility(); f1.setId(1L); f1.setName("Facility 1");
        GolfFacility f2 = new GolfFacility(); f2.setId(2L); f2.setName("Facility 2");
        when(facilityRepository.findAll()).thenReturn(List.of(f1, f2));

        List<GolfFacility> result = courseService.listFacilities();

        assertEquals(2, result.size());
    }

    @Test
    void updateFacility_updatesFields() {
        GolfFacility existing = new GolfFacility();
        existing.setId(1L);
        existing.setName("Old Name");
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("SYSTEM");
        existing.setDataQuality(dqm);

        GolfFacility update = new GolfFacility();
        update.setName("New Name");

        when(facilityRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(facilityRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        GolfFacility result = courseService.updateFacility(1L, update);

        assertEquals("New Name", result.getName());
        verify(auditService).log(any(), eq("GolfFacility"), eq("1"), anyString(), anyString(), isNull());
    }

    // ─── Course tests ───────────────────────────────────────────────────

    @Test
    void createCourse_savesWithFacility() {
        GolfFacility facility = new GolfFacility();
        facility.setId(1L);
        facility.setName("Test Facility");
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("SYSTEM");
        facility.setDataQuality(dqm);

        Course course = new Course();
        course.setName("North Course");
        course.setHolesCount(18);
        course.setParTotal(72);

        when(facilityRepository.findById(1L)).thenReturn(Optional.of(facility));
        when(courseRepository.save(any())).thenAnswer(inv -> { Course c = inv.getArgument(0); c.setId(1L); return c; });

        Course result = courseService.createCourse(1L, course);

        assertEquals(1L, result.getId());
        assertEquals("North Course", result.getName());
        assertEquals(facility, result.getFacility());
    }

    @Test
    void createCourse_throwsNotFound_whenFacilityMissing() {
        when(facilityRepository.findById(999L)).thenReturn(Optional.empty());

        Course course = new Course();
        course.setName("Orphan Course");

        assertThrows(VspApiException.class, () -> courseService.createCourse(999L, course));
    }

    @Test
    void getCourse_returnsCourse_whenExists() {
        Course course = new Course();
        course.setId(1L);
        course.setName("South Course");

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));

        Course result = courseService.getCourse(1L);

        assertEquals("South Course", result.getName());
    }

    @Test
    void listCoursesByFacility_returnsCourses() {
        Course c1 = new Course(); c1.setId(1L); c1.setName("East");
        Course c2 = new Course(); c2.setId(2L); c2.setName("West");
        when(courseRepository.findByFacilityId(1L)).thenReturn(List.of(c1, c2));

        List<Course> result = courseService.listCoursesByFacility(1L);

        assertEquals(2, result.size());
    }

    // ─── Hole tests ─────────────────────────────────────────────────────

    @Test
    void createHole_savesWithCourse() {
        Course course = new Course();
        course.setId(1L);
        course.setName("Main Course");
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("SYSTEM");
        course.setDataQuality(dqm);

        Hole hole = new Hole();
        hole.setHoleNumber(1);
        hole.setPar(4);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(holeRepository.save(any())).thenAnswer(inv -> { Hole h = inv.getArgument(0); h.setId(1L); return h; });

        Hole result = courseService.createHole(1L, hole);

        assertEquals(1L, result.getId());
        assertEquals(1, result.getHoleNumber());
        assertEquals(course, result.getCourse());
    }

    @Test
    void listHolesByCourse_returnsOrderedByNumber() {
        Hole h1 = new Hole(); h1.setId(1L); h1.setHoleNumber(1);
        Hole h2 = new Hole(); h2.setId(2L); h2.setHoleNumber(2);
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of(h1, h2));

        List<Hole> result = courseService.listHolesByCourse(1L);

        assertEquals(2, result.size());
        assertEquals(1, result.get(0).getHoleNumber());
        assertEquals(2, result.get(1).getHoleNumber());
    }

    @Test
    void updateHole_updatesPar() {
        Hole existing = new Hole();
        existing.setId(1L);
        existing.setHoleNumber(1);
        existing.setPar(4);
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("SYSTEM");
        existing.setDataQuality(dqm);

        Hole update = new Hole();
        update.setPar(5);

        when(holeRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(holeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Hole result = courseService.updateHole(1L, update);

        assertEquals(5, result.getPar());
    }

    // ─── TeeSet tests ───────────────────────────────────────────────────

    @Test
    void createTeeSet_savesWithCourse() {
        Course course = new Course();
        course.setId(1L);
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("SYSTEM");
        course.setDataQuality(dqm);

        TeeSet teeSet = new TeeSet();
        teeSet.setName("Black Tee");
        teeSet.setTotalPar(72);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(teeSetRepository.save(any())).thenAnswer(inv -> { TeeSet t = inv.getArgument(0); t.setId(1L); return t; });

        TeeSet result = courseService.createTeeSet(1L, teeSet);

        assertEquals(1L, result.getId());
        assertEquals("Black Tee", result.getName());
    }

    @Test
    void getTeeSetsByCourse_returnsSets() {
        TeeSet ts1 = new TeeSet(); ts1.setId(1L); ts1.setName("White");
        TeeSet ts2 = new TeeSet(); ts2.setId(2L); ts2.setName("Gold");
        when(teeSetRepository.findByCourseId(1L)).thenReturn(List.of(ts1, ts2));

        List<TeeSet> result = courseService.getTeeSetsByCourse(1L);

        assertEquals(2, result.size());
    }

    // ─── PinPosition tests ──────────────────────────────────────────────

    @Test
    void createPinPosition_savesWithHole() {
        Hole hole = new Hole();
        hole.setId(1L);
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("SYSTEM");
        hole.setDataQuality(dqm);

        PinPosition pin = new PinPosition();
        pin.setEffectiveDate(LocalDate.of(2026, 8, 1));

        when(holeRepository.findById(1L)).thenReturn(Optional.of(hole));
        when(pinPositionRepository.save(any())).thenAnswer(inv -> { PinPosition p = inv.getArgument(0); p.setId(1L); return p; });

        PinPosition result = courseService.createPinPosition(1L, pin);

        assertEquals(1L, result.getId());
        assertEquals(hole, result.getHole());
    }

    @Test
    void getActivePinPosition_returnsActivePin() {
        PinPosition pin = new PinPosition();
        pin.setId(1L);
        pin.setEffectiveDate(LocalDate.now().minusDays(1));

        when(pinPositionRepository.findByHoleIdAndEffectiveDateLessThanEqualAndExpiryDateIsNull(eq(1L), any(LocalDate.class)))
                .thenReturn(List.of(pin));

        PinPosition result = courseService.getActivePinPosition(1L);

        assertEquals(1L, result.getId());
    }

    @Test
    void getActivePinPosition_throwsNotFound_whenNoActivePin() {
        when(pinPositionRepository.findByHoleIdAndEffectiveDateLessThanEqualAndExpiryDateIsNull(eq(1L), any(LocalDate.class)))
                .thenReturn(List.of());
        when(pinPositionRepository.findByHoleIdAndExpiryDateIsNull(1L)).thenReturn(List.of());

        assertThrows(VspApiException.class, () -> courseService.getActivePinPosition(1L));
    }

    // ─── CourseCondition tests ──────────────────────────────────────────

    @Test
    void createCourseCondition_savesWithCourse() {
        Course course = new Course();
        course.setId(1L);
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("SYSTEM");
        course.setDataQuality(dqm);

        CourseCondition condition = new CourseCondition();
        condition.setConditionType(CourseCondition.ConditionType.OTHER);
        condition.setSeverity(CourseCondition.Severity.MODERATE);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(courseConditionRepository.save(any())).thenAnswer(inv -> { CourseCondition c = inv.getArgument(0); c.setId(1L); return c; });

        CourseCondition result = courseService.createCourseCondition(1L, condition);

        assertEquals(1L, result.getId());
        assertEquals(CourseCondition.ConditionType.OTHER, result.getConditionType());
    }

    @Test
    void getActiveConditions_returnsActiveConditions() {
        CourseCondition c1 = new CourseCondition();
        c1.setId(1L);
        c1.setConditionType(CourseCondition.ConditionType.OTHER);

        when(courseConditionRepository.findByCourseIdAndEffectiveDateLessThanEqualAndExpiryDateIsNull(eq(1L), any(LocalDate.class)))
                .thenReturn(List.of(c1));

        List<CourseCondition> result = courseService.getActiveConditions(1L);

        assertEquals(1, result.size());
        assertEquals(CourseCondition.ConditionType.OTHER, result.get(0).getConditionType());
    }

    // ─── Audit helper tests ─────────────────────────────────────────────

    @Test
    void recordCoursePublish_delegatesToAuditService() {
        courseService.recordCoursePublish(1L, "{}", "{\"status\":\"PUBLISHED\"}");

        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.COURSE_PUBLISH),
                eq("Course"), eq("1"), eq("{}"), eq("{\"status\":\"PUBLISHED\"}"), isNull());
    }

    @Test
    void recordCourseRollback_delegatesToAuditService() {
        courseService.recordCourseRollback(1L, "{\"status\":\"PUBLISHED\"}", "{}");

        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.COURSE_ROLLBACK),
                eq("Course"), eq("1"), eq("{\"status\":\"PUBLISHED\"}"), eq("{}"), isNull());
    }

    // ─── Geometry validation ────────────────────────────────────────────
    //
    // These are the admin course/hole/facility write paths. The WKT arrives
    // verbatim from the request body; anything PostGIS would refuse has to be
    // refused here as VALIDATION-008, not surfaced as a 500 from the parser.
    // Nothing is saved and no facility/course is even looked up: the check runs
    // before the entity reaches Hibernate.

    private static void assertRejectedAsGeometry(String field, Executable call) {
        VspApiException ex = assertThrows(VspApiException.class, call);
        assertEquals(VspErrorCode.VALIDATION_008, ex.getErrorCode());
        assertEquals(field, ex.getField());
    }

    @Test
    void createFacility_rejectsGeometryPostgresWouldRefuse() {
        GolfFacility facility = new GolfFacility();
        facility.setName("Bad geometry club");
        facility.setLocation("POLYGON((0 0,1 0,1 1,0 1,0 0))"); // column is geometry(Point,4326)

        assertRejectedAsGeometry("location", () -> courseService.createFacility(facility));
        verify(facilityRepository, never()).save(any(GolfFacility.class));
    }

    @Test
    void updateFacility_rejectsMalformedWkt() {
        GolfFacility update = new GolfFacility();
        update.setLocation("POINT(oops)");

        assertRejectedAsGeometry("location", () -> courseService.updateFacility(1L, update));
        verify(facilityRepository, never()).findById(anyLong());
    }

    @Test
    void createCourse_rejectsSelfIntersectingBoundary() {
        Course course = new Course();
        course.setName("Bowtie Links");
        course.setLocation("POLYGON((0 0,1 1,1 0,0 1,0 0))");

        assertRejectedAsGeometry("location", () -> courseService.createCourse(1L, course));
        verify(courseRepository, never()).save(any(Course.class));
    }

    @Test
    void updateCourse_acceptsAnyValidShapeForTheBoundaryColumn() {
        Course existing = new Course();
        existing.setId(1L);
        Course update = new Course();
        update.setLocation("POLYGON((106 10,106.001 10,106.001 10.001,106 10.001,106 10))");

        when(courseRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(courseRepository.save(any(Course.class))).thenAnswer(inv -> inv.getArgument(0));

        Course result = courseService.updateCourse(1L, update);

        assertEquals("POLYGON((106 10,106.001 10,106.001 10.001,106 10.001,106 10))", result.getLocation());
    }

    @Test
    void createHole_rejectsEachGeometryFieldByName() {
        Hole withBadTee = new Hole();
        withBadTee.setHoleNumber(1);
        withBadTee.setTeeingGroundLocation("SRID=3857;POINT(0 0)");
        assertRejectedAsGeometry("teeingGroundLocation", () -> courseService.createHole(1L, withBadTee));

        Hole withBadGreen = new Hole();
        withBadGreen.setHoleNumber(1);
        withBadGreen.setTeeingGroundLocation("POINT(106.7 10.8)");
        withBadGreen.setGreenLocation("LINESTRING(106 10,106.001 10.001)");
        assertRejectedAsGeometry("greenLocation", () -> courseService.createHole(1L, withBadGreen));

        verify(holeRepository, never()).save(any(Hole.class));
    }

    @Test
    void updateHole_rejectsGeometryWithAZOrdinate() {
        Hole update = new Hole();
        update.setGreenLocation("POINT(106.7 10.8 12.5)");

        assertRejectedAsGeometry("greenLocation", () -> courseService.updateHole(1L, update));
        verify(holeRepository, never()).findById(anyLong());
    }

    @Test
    void holeWithNoGeometryIsStillAllowed() {
        Hole hole = new Hole();
        hole.setHoleNumber(3);
        hole.setPar(4);
        Course course = new Course();
        course.setId(1L);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(holeRepository.save(any(Hole.class)))
                .thenAnswer(inv -> { Hole h = inv.getArgument(0); h.setId(9L); return h; });

        assertEquals(9L, courseService.createHole(1L, hole).getId());
    }
}
