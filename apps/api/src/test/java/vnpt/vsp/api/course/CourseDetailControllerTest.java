package vnpt.vsp.api.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.CourseDetailService;
import vnpt.vsp.module.course.dto.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Collections;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseDetailController}.
 * Per Story 3.3 CD-BACK-1: AC-1, AC-2, AC-3.
 * Uses pure Mockito — no Spring context loading required.
 */
@ExtendWith(MockitoExtension.class)
class CourseDetailControllerTest {

    @Mock
    private CourseDetailService courseDetailService;

    private CourseDetailController controller;

    @BeforeEach
    void setUp() {
        controller = new CourseDetailController(courseDetailService);
    }

    // ─── AC-1: Full detail returned ─────────────────────────────────────────

    @Test
    void getCourseDetail_validId_returns200WithFullDetail() {
        CourseDetailDto dto = buildFullCourseDetailDto();
        when(courseDetailService.getCourseDetail(10L)).thenReturn(dto);

        ResponseEntity<CourseDetailDto> response = controller.getCourseDetail(10L);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(10L, response.getBody().getCourseId());
        assertEquals("Thuyle Golf Club", response.getBody().getFacilityName());
        assertEquals("Championship Course", response.getBody().getCourseName());
        assertEquals("+84-28-3822-5555", response.getBody().getPhone());
        assertEquals("https://thuyle-golf.com", response.getBody().getWebsite());
        assertEquals(10.8231, response.getBody().getLatitude());
        assertEquals(106.6299, response.getBody().getLongitude());
        assertEquals(18, response.getBody().getHolesCount());
        assertEquals(72, response.getBody().getParTotal());
        assertEquals(1, response.getBody().getHoles().size());
        assertEquals(1, response.getBody().getTeeSets().size());
        assertEquals(1, response.getBody().getConditions().size());
        assertEquals(3, response.getBody().getDataFreshness().getVersionNumber());
    }

    // ─── AC-2: Null/unavailable fields ───────────────────────────────────────

    @Test
    void getCourseDetail_nullPhone_returnsNullNotEmpty() {
        CourseDetailDto dto = buildFullCourseDetailDto();
        dto.setPhone(null);
        when(courseDetailService.getCourseDetail(10L)).thenReturn(dto);

        ResponseEntity<CourseDetailDto> response = controller.getCourseDetail(10L);

        assertEquals(200, response.getStatusCode().value());
        assertNull(response.getBody().getPhone());
        assertEquals("https://thuyle-golf.com", response.getBody().getWebsite());
    }

    @Test
    void getCourseDetail_noConditions_returnsEmptyList() {
        CourseDetailDto dto = buildFullCourseDetailDto();
        dto.setConditions(Collections.emptyList());
        when(courseDetailService.getCourseDetail(10L)).thenReturn(dto);

        ResponseEntity<CourseDetailDto> response = controller.getCourseDetail(10L);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody().getConditions());
        assertTrue(response.getBody().getConditions().isEmpty());
    }

    @Test
    void getCourseDetail_noDataFreshness_stillReturns200() {
        CourseDetailDto dto = buildFullCourseDetailDto();
        dto.setDataFreshness(null);
        when(courseDetailService.getCourseDetail(10L)).thenReturn(dto);

        ResponseEntity<CourseDetailDto> response = controller.getCourseDetail(10L);

        assertEquals(200, response.getStatusCode().value());
        assertNull(response.getBody().getDataFreshness());
    }

    // ─── AC-3: ETag and Cache-Control ─────────────────────────────────────────

    @Test
    void getCourseDetail_withVersionNumber_returnsETag() {
        CourseDetailDto dto = buildFullCourseDetailDto();
        when(courseDetailService.getCourseDetail(10L)).thenReturn(dto);

        ResponseEntity<CourseDetailDto> response = controller.getCourseDetail(10L);

        assertNotNull(response.getHeaders().getETag());
        assertEquals("\"3\"", response.getHeaders().getETag());
        assertTrue(response.getHeaders().getCacheControl().contains("max-age=300"));
    }

    @Test
    void getCourseDetail_noVersionNumber_noETag() {
        CourseDetailDto dto = buildFullCourseDetailDto();
        dto.setDataFreshness(null);
        when(courseDetailService.getCourseDetail(10L)).thenReturn(dto);

        ResponseEntity<CourseDetailDto> response = controller.getCourseDetail(10L);

        assertNull(response.getHeaders().getETag());
    }

    // ─── Error handling ─────────────────────────────────────────────────────

    @Test
    void getCourseDetail_courseNotFound_serviceThrowsCOURSE001() {
        when(courseDetailService.getCourseDetail(999L))
                .thenThrow(new VspApiException(VspErrorCode.COURSE_001));

        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getCourseDetail(999L));

        assertEquals("VSP-ERR-COURSE-001", ex.getErrorCode().getCode());
    }

    // ─── Test data builder ───────────────────────────────────────────────────

    private CourseDetailDto buildFullCourseDetailDto() {
        CourseDetailDto dto = new CourseDetailDto();
        dto.setCourseId(10L);
        dto.setFacilityId(1L);
        dto.setFacilityName("Thuyle Golf Club");
        dto.setCourseName("Championship Course");
        dto.setPhone("+84-28-3822-5555");
        dto.setWebsite("https://thuyle-golf.com");
        dto.setAddress("123 Nguyen Van Linh, HCMC");
        dto.setLatitude(10.8231);
        dto.setLongitude(106.6299);
        dto.setHolesCount(18);
        dto.setParTotal(72);
        dto.setRating(new BigDecimal("4.5"));
        dto.setSlope(125);
        dto.setImageUrls(Collections.emptyList());
        dto.setFacilities(Collections.emptyList());
        dto.setLocalRules(Collections.emptyList());

        // Holes
        vnpt.vsp.module.course.dto.HoleSummaryDto hole =
                new vnpt.vsp.module.course.dto.HoleSummaryDto();
        hole.setHoleNumber(1);
        hole.setPar(4);
        hole.setPlayingLengthMeters(new BigDecimal("382.50"));
        dto.setHoles(Arrays.asList(hole));

        // Tee set
        TeeSetSummaryDto teeSet = new TeeSetSummaryDto();
        teeSet.setId(20L);
        teeSet.setName("Black Tee");
        teeSet.setTotalPar(72);
        teeSet.setRating(new BigDecimal("4.5"));
        teeSet.setSlope(125);
        teeSet.setYardages(Collections.emptyMap());
        DataQualityDto dq = new DataQualityDto("A_RTK_SURVEYED", "VERIFIED");
        teeSet.setDataQuality(dq);
        dto.setTeeSets(Arrays.asList(teeSet));

        // Condition
        ConditionDto cond = new ConditionDto();
        cond.setConditionType("GREEN_SPEED");
        cond.setSeverity("MODERATE");
        cond.setDescription("Greens running fast at 11 stimpmeter");
        cond.setEffectiveDate(LocalDate.now());
        cond.setDataQuality(dq);
        dto.setConditions(Arrays.asList(cond));

        // Data freshness
        DataFreshnessDto df = new DataFreshnessDto();
        df.setPublishedAt("2026-07-15T10:00:00Z");
        df.setVersionNumber(3);
        df.setPublisher("Thuyle Golf Club");
        df.setVerificationStatus("VERIFIED");
        df.setLastVerifiedAt("2026-07-14T08:30:00Z");
        dto.setDataFreshness(df);

        return dto;
    }
}
