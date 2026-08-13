package vnpt.vsp.module.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseDetailServiceImpl}.
 * Per Story 3.3 CD-BACK-1: AC-1 (full aggregation), AC-2 (null for unavailable), AC-3 (dataQuality).
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CourseDetailServiceTest {

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private GolfFacilityRepository golfFacilityRepository;

    @Mock
    private HoleRepository holeRepository;

    @Mock
    private TeeSetRepository teeSetRepository;

    @Mock
    private CourseConditionRepository courseConditionRepository;

    @Mock
    private DataVersionRepository dataVersionRepository;

    private CourseDetailServiceImpl service;

    private GolfFacility testFacility;
    private Course testCourse;
    private DataVersion testDataVersion;

    @BeforeEach
    void setUp() {
        service = new CourseDetailServiceImpl(
                courseRepository, golfFacilityRepository, holeRepository,
                teeSetRepository, courseConditionRepository,
                dataVersionRepository);

        testFacility = new GolfFacility();
        testFacility.setId(1L);
        testFacility.setName("Thuyle Golf Club");
        testFacility.setAddress("123 Nguyen Van Linh, District 7, HCMC");
        testFacility.setPhone("+84-28-3822-5555");
        testFacility.setWebsite("https://thuyle-golf.com");
        testFacility.setLocation("POINT(106.6299 10.8231)");

        testCourse = new Course();
        testCourse.setId(10L);
        testCourse.setFacility(testFacility);
        testCourse.setName("Championship Course");
        testCourse.setHolesCount(18);
        testCourse.setParTotal(72);
        // rating/slope — not in Course entity, remain null per AC-2

        DataQualityMetadata courseDqm = new DataQualityMetadata();
        courseDqm.setAccuracyClass(AccuracyClass.A_RTK_SURVEYED);
        courseDqm.setVerificationStatus(VerificationStatus.VERIFIED);
        courseDqm.setPublisher("Thuyle Golf Club");
        testCourse.setMetadata(courseDqm);

        testDataVersion = new DataVersion();
        testDataVersion.setId(100L);
        testDataVersion.setCourse(testCourse);
        testDataVersion.setVersionNumber(3);
        testDataVersion.setPublishedBy("Thuyle Golf Club");
        testDataVersion.setPublishedAt(Instant.parse("2026-07-15T10:00:00Z"));
        DataQualityMetadata dvDqm = new DataQualityMetadata();
        dvDqm.setVerificationStatus(VerificationStatus.VERIFIED);
        dvDqm.setLastVerifiedAt(Instant.parse("2026-07-14T08:30:00Z"));
        testDataVersion.setMetadata(dvDqm);
    }

    // ─── AC-1: Full aggregation ─────────────────────────────────────────────────

    @Test
    void getCourseDetail_fullAggregation_includesAllFields() {
        // Arrange
        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(golfFacilityRepository.findLongitudeByFacilityId(1L)).thenReturn(106.6299);
        when(golfFacilityRepository.findLatitudeByFacilityId(1L)).thenReturn(10.8231);

        Hole hole1 = createHole(10L, 1, 4, new BigDecimal("382.50"));
        Hole hole2 = createHole(10L, 2, 5, new BigDecimal("435.00"));
        when(holeRepository.findByCourseIdOrderByHoleNumber(10L))
                .thenReturn(Arrays.asList(hole1, hole2));

        TeeSet teeSet1 = createTeeSet(20L, "Black Tee", 72);
        when(teeSetRepository.findByCourseId(10L)).thenReturn(Arrays.asList(teeSet1));

        CourseCondition cond = createCondition(30L, CourseCondition.ConditionType.GREEN_SPEED,
                CourseCondition.Severity.MODERATE, "Greens running fast");
        when(courseConditionRepository.findActiveByCourseId(eq(10L), any(LocalDate.class)))
                .thenReturn(Arrays.asList(cond));

        when(dataVersionRepository.findLatestPublishedByCourseId(10L))
                .thenReturn(Optional.of(testDataVersion));

        // Act
        CourseDetailDto result = service.getCourseDetail(10L);

        // Assert — AC-1: all fields populated
        assertNotNull(result);
        assertEquals(10L, result.getCourseId());
        assertEquals(1L, result.getFacilityId());
        assertEquals("Thuyle Golf Club", result.getFacilityName());
        assertEquals("Championship Course", result.getCourseName());
        assertEquals("+84-28-3822-5555", result.getPhone());
        assertEquals("https://thuyle-golf.com", result.getWebsite());
        assertEquals("123 Nguyen Van Linh, District 7, HCMC", result.getAddress());
        assertEquals(10.8231, result.getLatitude());
        assertEquals(106.6299, result.getLongitude());
        assertEquals(18, result.getHolesCount());
        assertEquals(72, result.getParTotal());
        // rating/slope null — not in entity (AC-2)
        assertNull(result.getRating());
        assertNull(result.getSlope());

        // Holes
        assertEquals(2, result.getHoles().size());
        assertEquals(1, result.getHoles().get(0).getHoleNumber());
        assertEquals(4, result.getHoles().get(0).getPar());
        assertEquals(new BigDecimal("382.50"), result.getHoles().get(0).getPlayingLengthMeters());

        // Tee sets
        assertEquals(1, result.getTeeSets().size());
        assertEquals(20L, result.getTeeSets().get(0).getId());
        assertEquals("Black Tee", result.getTeeSets().get(0).getName());

        // Conditions
        assertEquals(1, result.getConditions().size());
        assertEquals("GREEN_SPEED", result.getConditions().get(0).getConditionType());
        assertEquals("MODERATE", result.getConditions().get(0).getSeverity());

        // Data freshness
        assertNotNull(result.getDataFreshness());
        assertEquals(3, result.getDataFreshness().getVersionNumber());
        assertEquals("Thuyle Golf Club", result.getDataFreshness().getPublisher());
        assertEquals("VERIFIED", result.getDataFreshness().getVerificationStatus());

        // AC-2: unavailable fields
        assertNotNull(result.getImageUrls());   // empty list
        assertTrue(result.getImageUrls().isEmpty());
        assertNotNull(result.getFacilities());
        assertTrue(result.getFacilities().isEmpty());
        assertNotNull(result.getLocalRules());
        assertTrue(result.getLocalRules().isEmpty());
    }

    // ─── AC-2: Null handling ─────────────────────────────────────────────────────

    @Test
    void getCourseDetail_nullPhoneAndWebsite_returnsNullNotFabricated() {
        // Create a fresh facility with null contact fields
        GolfFacility nullContactFacility = new GolfFacility();
        nullContactFacility.setId(1L);
        nullContactFacility.setName("Null Contact Club");
        nullContactFacility.setAddress("456 No Phone St, HCMC");
        nullContactFacility.setPhone(null);
        nullContactFacility.setWebsite(null);
        nullContactFacility.setLocation("POINT(107.0000 11.0000)");

        Course nullContactCourse = new Course();
        nullContactCourse.setId(20L);
        nullContactCourse.setFacility(nullContactFacility);
        nullContactCourse.setName("Empty Course");
        nullContactCourse.setHolesCount(9);
        nullContactCourse.setParTotal(36);
        DataQualityMetadata dqm = new DataQualityMetadata();
        nullContactCourse.setMetadata(dqm);

        when(courseRepository.findById(20L)).thenReturn(Optional.of(nullContactCourse));
        when(golfFacilityRepository.findLongitudeByFacilityId(1L)).thenReturn(null);
        when(golfFacilityRepository.findLatitudeByFacilityId(1L)).thenReturn(null);
        when(holeRepository.findByCourseIdOrderByHoleNumber(20L)).thenReturn(Collections.emptyList());
        when(teeSetRepository.findByCourseId(20L)).thenReturn(Collections.emptyList());
        when(courseConditionRepository.findActiveByCourseId(eq(20L), any(LocalDate.class)))
                .thenReturn(Collections.emptyList());
        when(dataVersionRepository.findLatestPublishedByCourseId(20L)).thenReturn(Optional.empty());

        CourseDetailDto result = service.getCourseDetail(20L);

        // AC-2: unavailable = null, not fabricated
        assertNull(result.getPhone());
        assertNull(result.getWebsite());
        assertNull(result.getLatitude());
        assertNull(result.getLongitude());
    }

    @Test
    void getCourseDetail_noConditions_returnsEmptyListNotNull() {
        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(golfFacilityRepository.findLongitudeByFacilityId(1L)).thenReturn(106.6299);
        when(golfFacilityRepository.findLatitudeByFacilityId(1L)).thenReturn(10.8231);
        when(holeRepository.findByCourseIdOrderByHoleNumber(10L)).thenReturn(Collections.emptyList());
        when(teeSetRepository.findByCourseId(10L)).thenReturn(Collections.emptyList());
        when(courseConditionRepository.findActiveByCourseId(eq(10L), any(LocalDate.class)))
                .thenReturn(Collections.emptyList());
        when(dataVersionRepository.findLatestPublishedByCourseId(10L)).thenReturn(Optional.empty());

        CourseDetailDto result = service.getCourseDetail(10L);

        assertNotNull(result.getConditions());
        assertTrue(result.getConditions().isEmpty());
    }

    @Test
    void getCourseDetail_noPublishedVersion_dataFreshnessNull() {
        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(golfFacilityRepository.findLongitudeByFacilityId(1L)).thenReturn(106.6299);
        when(golfFacilityRepository.findLatitudeByFacilityId(1L)).thenReturn(10.8231);
        when(holeRepository.findByCourseIdOrderByHoleNumber(10L)).thenReturn(Collections.emptyList());
        when(teeSetRepository.findByCourseId(10L)).thenReturn(Collections.emptyList());
        when(courseConditionRepository.findActiveByCourseId(eq(10L), any(LocalDate.class)))
                .thenReturn(Collections.emptyList());
        when(dataVersionRepository.findLatestPublishedByCourseId(10L)).thenReturn(Optional.empty());

        CourseDetailDto result = service.getCourseDetail(10L);

        // No published version = no data freshness
        assertNull(result.getDataFreshness());
    }

    // ─── AC-3: Data quality ─────────────────────────────────────────────────────

    @Test
    void getCourseDetail_withDataQualityMetadata_carriesAccuracyClassAndVerificationStatus() {
        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(golfFacilityRepository.findLongitudeByFacilityId(1L)).thenReturn(106.6299);
        when(golfFacilityRepository.findLatitudeByFacilityId(1L)).thenReturn(10.8231);
        when(holeRepository.findByCourseIdOrderByHoleNumber(10L)).thenReturn(Collections.emptyList());

        // Create tee set with explicit A_RTK_SURVEYED accuracy class
        TeeSet teeSet = new TeeSet();
        teeSet.setId(20L);
        teeSet.setCourse(testCourse);
        teeSet.setName("White Tee");
        teeSet.setTotalPar(72);
        DataQualityMetadata teeSetDqm = new DataQualityMetadata();
        teeSetDqm.setAccuracyClass(AccuracyClass.A_RTK_SURVEYED);
        teeSetDqm.setVerificationStatus(VerificationStatus.VERIFIED);
        teeSet.setDataQuality(teeSetDqm);

        when(teeSetRepository.findByCourseId(10L)).thenReturn(Arrays.asList(teeSet));

        CourseCondition cond = createCondition(30L, CourseCondition.ConditionType.COURSE_OVERALL,
                CourseCondition.Severity.LOW, "Course in great shape");
        when(courseConditionRepository.findActiveByCourseId(eq(10L), any(LocalDate.class)))
                .thenReturn(Arrays.asList(cond));
        when(dataVersionRepository.findLatestPublishedByCourseId(10L))
                .thenReturn(Optional.of(testDataVersion));

        CourseDetailDto result = service.getCourseDetail(10L);

        // Tee set data quality
        assertNotNull(result.getTeeSets().get(0).getDataQuality());
        assertEquals("A_RTK_SURVEYED", result.getTeeSets().get(0).getDataQuality().getAccuracyClass());
        assertEquals("VERIFIED", result.getTeeSets().get(0).getDataQuality().getVerificationStatus());

        // Condition data quality — uses B_LICENSED_PROVIDER from createCondition helper
        assertNotNull(result.getConditions().get(0).getDataQuality());
        assertEquals("B_LICENSED_PROVIDER", result.getConditions().get(0).getDataQuality().getAccuracyClass());

        // DataFreshness verification status
        assertNotNull(result.getDataFreshness());
        assertEquals("VERIFIED", result.getDataFreshness().getVerificationStatus());
    }

    /**
     * A hole's length is measured between its tee and green coordinates, so a
     * client shown the length must be able to see where those coordinates came
     * from. The seeded database generated 831 of its 900 holes arithmetically
     * and stamped them C_VERIFIED_SATELLITE / VERIFIED; the client can only
     * refuse to present that as surveyed if the provenance travels with the
     * number.
     */
    @Test
    void getCourseDetail_holeSummary_carriesTheProvenanceOfItsCoordinates() {
        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(golfFacilityRepository.findLongitudeByFacilityId(1L)).thenReturn(106.6299);
        when(golfFacilityRepository.findLatitudeByFacilityId(1L)).thenReturn(10.8231);

        Hole synthetic = new Hole();
        synthetic.setId(41L);
        synthetic.setCourse(testCourse);
        synthetic.setHoleNumber(1);
        synthetic.setPar(4);
        synthetic.setPlayingLengthMeters(new java.math.BigDecimal("362.00"));
        DataQualityMetadata syntheticDqm = new DataQualityMetadata();
        syntheticDqm.setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
        syntheticDqm.setVerificationStatus(VerificationStatus.UNVERIFIED);
        syntheticDqm.setSource("synthetic:seed-arithmetic");
        synthetic.setDataQuality(syntheticDqm);

        Hole digitised = new Hole();
        digitised.setId(42L);
        digitised.setCourse(testCourse);
        digitised.setHoleNumber(2);
        digitised.setPar(5);
        digitised.setPlayingLengthMeters(new java.math.BigDecimal("488.00"));
        DataQualityMetadata digitisedDqm = new DataQualityMetadata();
        digitisedDqm.setAccuracyClass(AccuracyClass.C_VERIFIED_SATELLITE);
        digitisedDqm.setVerificationStatus(VerificationStatus.VERIFIED);
        digitised.setDataQuality(digitisedDqm);

        when(holeRepository.findByCourseIdOrderByHoleNumber(10L))
                .thenReturn(Arrays.asList(synthetic, digitised));
        when(teeSetRepository.findByCourseId(10L)).thenReturn(Collections.emptyList());
        when(courseConditionRepository.findActiveByCourseId(eq(10L), any(LocalDate.class)))
                .thenReturn(Collections.emptyList());
        when(dataVersionRepository.findLatestPublishedByCourseId(10L))
                .thenReturn(Optional.of(testDataVersion));

        CourseDetailDto result = service.getCourseDetail(10L);

        assertNotNull(result.getHoles().get(0).getDataQuality());
        assertEquals("D_UNVERIFIED_COMMUNITY",
                result.getHoles().get(0).getDataQuality().getAccuracyClass());
        assertEquals("UNVERIFIED",
                result.getHoles().get(0).getDataQuality().getVerificationStatus());

        assertEquals("C_VERIFIED_SATELLITE",
                result.getHoles().get(1).getDataQuality().getAccuracyClass());
        assertEquals("VERIFIED",
                result.getHoles().get(1).getDataQuality().getVerificationStatus());
    }

    /**
     * Verification status alone lets a class-D row claim to be verified. The
     * class travels with it so the client can show the weaker of the two.
     */
    @Test
    void getCourseDetail_dataFreshness_carriesAccuracyClassNotJustVerification() {
        DataQualityMetadata dvDqm = new DataQualityMetadata();
        dvDqm.setVerificationStatus(VerificationStatus.UNVERIFIED);
        dvDqm.setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
        testDataVersion.setMetadata(dvDqm);

        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(golfFacilityRepository.findLongitudeByFacilityId(1L)).thenReturn(106.6299);
        when(golfFacilityRepository.findLatitudeByFacilityId(1L)).thenReturn(10.8231);
        when(holeRepository.findByCourseIdOrderByHoleNumber(10L)).thenReturn(Collections.emptyList());
        when(teeSetRepository.findByCourseId(10L)).thenReturn(Collections.emptyList());
        when(courseConditionRepository.findActiveByCourseId(eq(10L), any(LocalDate.class)))
                .thenReturn(Collections.emptyList());
        when(dataVersionRepository.findLatestPublishedByCourseId(10L))
                .thenReturn(Optional.of(testDataVersion));

        CourseDetailDto result = service.getCourseDetail(10L);

        assertEquals("D_UNVERIFIED_COMMUNITY", result.getDataFreshness().getAccuracyClass());
        assertEquals("UNVERIFIED", result.getDataFreshness().getVerificationStatus());
    }

    // ─── Error handling ─────────────────────────────────────────────────────────

    @Test
    void getCourseDetail_courseNotFound_throwsCOURSE_001() {
        when(courseRepository.findById(999L)).thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class,
                () -> service.getCourseDetail(999L));

        assertEquals("VSP-ERR-COURSE-001", ex.getErrorCode().getCode());
    }

    // ─── Test data helpers ───────────────────────────────────────────────────────

    private Hole createHole(Long courseId, int holeNumber, int par, BigDecimal playingLength) {
        Hole hole = new Hole();
        hole.setId(courseId * 10 + holeNumber);
        hole.setCourse(testCourse);
        hole.setHoleNumber(holeNumber);
        hole.setPar(par);
        hole.setPlayingLengthMeters(playingLength);
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setAccuracyClass(AccuracyClass.B_LICENSED_PROVIDER);
        dqm.setVerificationStatus(VerificationStatus.VERIFIED);
        hole.setMetadata(dqm);
        return hole;
    }

    private TeeSet createTeeSet(Long id, String name, int totalPar) {
        TeeSet teeSet = new TeeSet();
        teeSet.setId(id);
        teeSet.setCourse(testCourse);
        teeSet.setName(name);
        teeSet.setTotalPar(totalPar);
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setAccuracyClass(AccuracyClass.B_LICENSED_PROVIDER);
        dqm.setVerificationStatus(VerificationStatus.VERIFIED);
        teeSet.setDataQuality(dqm);
        return teeSet;
    }

    private CourseCondition createCondition(Long id, CourseCondition.ConditionType type,
                                           CourseCondition.Severity severity, String description) {
        CourseCondition cond = new CourseCondition();
        cond.setId(id);
        cond.setCourse(testCourse);
        cond.setConditionType(type);
        cond.setSeverity(severity);
        cond.setDescription(description);
        cond.setEffectiveDate(LocalDate.now().minusDays(1));
        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setAccuracyClass(AccuracyClass.B_LICENSED_PROVIDER);
        dqm.setVerificationStatus(VerificationStatus.VERIFIED);
        cond.setMetadata(dqm);
        return cond;
    }

    @Test
    void getCourseDetail_carriesEveryDuongOfTheFacility_inNameOrder() {
        // Long Biên has đường A, B and C. A golfer setting up a round there
        // pairs two of them, and this endpoint is the only place the phone
        // learns that the other two exist.
        Course duongB = new Course();
        duongB.setId(22L);
        duongB.setFacility(testFacility);
        duongB.setName("Đường B");
        duongB.setHolesCount(9);
        duongB.setParTotal(36);

        Course duongA = new Course();
        duongA.setId(21L);
        duongA.setFacility(testFacility);
        duongA.setName("Đường A");
        duongA.setHolesCount(9);
        duongA.setParTotal(36);

        when(courseRepository.findById(21L)).thenReturn(Optional.of(duongA));
        when(courseRepository.findByFacilityId(1L))
                .thenReturn(List.of(duongB, duongA));

        CourseDetailDto dto = service.getCourseDetail(21L);

        assertEquals(2, dto.getFacilityCourses().size());
        assertEquals("Đường A", dto.getFacilityCourses().get(0).getName());
        assertEquals(21L, dto.getFacilityCourses().get(0).getCourseId());
        assertEquals(9, dto.getFacilityCourses().get(0).getHolesCount());
        assertEquals("Đường B", dto.getFacilityCourses().get(1).getName());
    }

    @Test
    void getCourseDetail_aClubWithOneCourse_listsOnlyItself() {
        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(courseRepository.findByFacilityId(1L)).thenReturn(List.of(testCourse));

        CourseDetailDto dto = service.getCourseDetail(10L);

        assertEquals(1, dto.getFacilityCourses().size());
        assertEquals(10L, dto.getFacilityCourses().get(0).getCourseId());
    }
}
