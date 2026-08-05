package vnpt.vsp.module.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseSearchServiceImpl}.
 * Per Story 3.2 SD-BACK-1.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CourseSearchServiceTest {

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private GolfFacilityRepository facilityRepository;

    @Mock
    private CourseSearchRepository searchRepository;

    @Mock
    private FavoriteCourseRepository favoriteRepository;

    @Mock
    private RecentCourseRepository recentRepository;

    @Mock
    private DataVersionRepository dataVersionRepository;

    private CourseSearchServiceImpl service;

    private GolfFacility testFacility;
    private Course testCourse;
    private DataVersion testDataVersion;

    @BeforeEach
    void setUp() {
        service = new CourseSearchServiceImpl(
                courseRepository, facilityRepository, searchRepository,
                favoriteRepository, recentRepository, dataVersionRepository);

        testFacility = new GolfFacility();
        testFacility.setId(1L);
        testFacility.setName("Thuyle Golf Club");
        testFacility.setAddress("123 Nguyen Van Linh, HCMC");
        testFacility.setLocation("POINT(106.6299 10.8231)");

        testCourse = new Course();
        testCourse.setId(10L);
        testCourse.setFacility(testFacility);
        testCourse.setName("Championship Course");
        testCourse.setHolesCount(18);
        testCourse.setParTotal(72);

        DataQualityMetadata dqm = new DataQualityMetadata();
        dqm.setPublisher("Thuyle Golf Club");
        dqm.setVerificationStatus(VerificationStatus.VERIFIED);
        dqm.setLastVerifiedAt(Instant.parse("2026-07-14T08:30:00Z"));

        testDataVersion = new DataVersion();
        testDataVersion.setId(100L);
        testDataVersion.setCourse(testCourse);
        testDataVersion.setVersionNumber(3);
        testDataVersion.setStatus(DataVersionStatus.PUBLISHED);
        testDataVersion.setPublishedAt(Instant.parse("2026-07-15T10:00:00Z"));
        testDataVersion.setPublishedBy("Thuyle Golf Club");
        testDataVersion.setMetadata(dqm);
    }

    // ─── Search Tests ─────────────────────────────────────────────────────

    @Test
    void searchCourses_textOnly_returnsResultsFromRepository() {
        CourseSearchRequest request = new CourseSearchRequest();
        request.setQ("Thuyle");
        request.setPage(0);
        request.setSize(20);

        Page<Course> mockPage = new PageImpl<>(List.of(testCourse));
        when(searchRepository.searchByText(eq("Thuyle"), any(Pageable.class))).thenReturn(mockPage);
        when(dataVersionRepository.findLatestPublishedByCourseId(10L)).thenReturn(Optional.of(testDataVersion));

        PageResponse<CourseSearchResultDto> result = service.searchCourses(request);

        assertNotNull(result);
        assertEquals(1, result.getContent().size());
        CourseSearchResultDto dto = result.getContent().get(0);
        assertEquals(10L, dto.getCourseId());
        assertEquals("Championship Course", dto.getCourseName());
        assertEquals("Thuyle Golf Club", dto.getFacilityName());
        assertTrue(dto.isHasPackage());
        assertNotNull(dto.getDataFreshness());
        assertEquals(3, dto.getDataFreshness().getVersionNumber());
        assertEquals("VERIFIED", dto.getDataFreshness().getVerificationStatus());
    }

    @Test
    void searchCourses_nearbyOnly_returnsResultsWithDistance() {
        CourseSearchRequest request = new CourseSearchRequest();
        request.setLat(10.8231);
        request.setLng(106.6299);
        request.setRadiusMeters(5000.0);
        request.setPage(0);
        request.setSize(20);

        Object[] rawRow = new Object[]{10L, new BigDecimal("1234.56")};
        when(searchRepository.findNearbyCourseIdsAndDistances(
                eq(10.8231), eq(106.6299), eq(5000.0), any(Pageable.class)))
                .thenReturn(java.util.Collections.singletonList(rawRow));
        when(courseRepository.findAllById(List.of(10L))).thenReturn(List.of(testCourse));
        when(dataVersionRepository.findLatestPublishedByCourseId(10L)).thenReturn(Optional.of(testDataVersion));

        PageResponse<CourseSearchResultDto> result = service.searchCourses(request);

        assertNotNull(result);
        assertEquals(1, result.getContent().size());
        CourseSearchResultDto dto = result.getContent().get(0);
        assertEquals(new BigDecimal("1234.56"), dto.getDistanceMeters());
    }

    @Test
    void searchCourses_combinedTextAndNearby_returnsResults() {
        CourseSearchRequest request = new CourseSearchRequest();
        request.setQ("Championship");
        request.setLat(10.8231);
        request.setLng(106.6299);
        request.setRadiusMeters(10000.0);
        request.setPage(0);
        request.setSize(20);

        Object[] rawRow = new Object[]{10L, new BigDecimal("500.0")};
        when(searchRepository.findNearbyCourseIdsAndDistancesWithText(
                eq(10.8231), eq(106.6299), eq(10000.0), eq("Championship"), any(Pageable.class)))
                .thenReturn(java.util.Collections.singletonList(rawRow));
        when(courseRepository.findAllById(List.of(10L))).thenReturn(List.of(testCourse));
        when(dataVersionRepository.findLatestPublishedByCourseId(10L)).thenReturn(Optional.of(testDataVersion));

        PageResponse<CourseSearchResultDto> result = service.searchCourses(request);

        assertNotNull(result);
        assertEquals(1, result.getContent().size());
        assertEquals("Championship Course", result.getContent().get(0).getCourseName());
    }

    @Test
    void searchCourses_radiusExceedsMax_throwsException() {
        CourseSearchRequest request = new CourseSearchRequest();
        request.setLat(10.8231);
        request.setLng(106.6299);
        request.setRadiusMeters(100_000.0); // 100km > 50km max
        request.setPage(0);
        request.setSize(20);

        assertThrows(VspApiException.class, () -> service.searchCourses(request));
    }

    @Test
    void searchCourses_noFilters_browsesAllCourses() {
        // With no text or geo filters, the service browses the full catalogue
        // via an empty text query (q="") — the browse-all behavior.
        CourseSearchRequest request = new CourseSearchRequest();
        request.setPage(0);
        request.setSize(20);

        Page<Course> mockPage = new PageImpl<>(List.of(testCourse));
        when(searchRepository.searchByText(eq(""), any(Pageable.class))).thenReturn(mockPage);

        PageResponse<CourseSearchResultDto> result = service.searchCourses(request);

        assertNotNull(result);
        assertFalse(result.getContent().isEmpty());
        assertEquals(testCourse.getId(), result.getContent().get(0).getCourseId());
    }

    @Test
    void searchCourses_withDownloadedVersionOld_setsUpdateAvailable() {
        CourseSearchRequest request = new CourseSearchRequest();
        request.setQ("Thuyle");
        request.setPage(0);
        request.setSize(20);
        request.setDownloadedVersion(2); // older than latest (3)

        Page<Course> mockPage = new PageImpl<>(List.of(testCourse));
        when(searchRepository.searchByText(eq("Thuyle"), any(Pageable.class))).thenReturn(mockPage);
        when(dataVersionRepository.findLatestPublishedByCourseId(10L)).thenReturn(Optional.of(testDataVersion));

        PageResponse<CourseSearchResultDto> result = service.searchCourses(request);

        assertTrue(result.getContent().get(0).isUpdateAvailable());
    }

    @Test
    void searchCourses_withDownloadedVersionCurrent_noUpdateAvailable() {
        CourseSearchRequest request = new CourseSearchRequest();
        request.setQ("Thuyle");
        request.setPage(0);
        request.setSize(20);
        request.setDownloadedVersion(3); // same as latest

        Page<Course> mockPage = new PageImpl<>(List.of(testCourse));
        when(searchRepository.searchByText(eq("Thuyle"), any(Pageable.class))).thenReturn(mockPage);
        when(dataVersionRepository.findLatestPublishedByCourseId(10L)).thenReturn(Optional.of(testDataVersion));

        PageResponse<CourseSearchResultDto> result = service.searchCourses(request);

        assertFalse(result.getContent().get(0).isUpdateAvailable());
    }

    // ─── Favorites Tests ──────────────────────────────────────────────────

    @Test
    void getFavorites_returnsFavoriteCourseDtos() {
        FavoriteCourse fav = new FavoriteCourse();
        fav.setId(1L);
        fav.setUserId(100L);
        fav.setCourse(testCourse);
        fav.setCreatedAt(Instant.parse("2026-08-01T12:00:00Z"));

        when(favoriteRepository.findByUserIdOrderByCreatedAtDesc(100L)).thenReturn(List.of(fav));

        List<FavoriteCourseDto> result = service.getFavorites(100L);

        assertEquals(1, result.size());
        assertEquals(10L, result.get(0).getCourseId());
        assertEquals("Thuyle Golf Club", result.get(0).getFacilityName());
    }

    @Test
    void addFavorite_newFavorite_savesAndReturns() {
        when(favoriteRepository.existsByUserIdAndCourseId(100L, 10L)).thenReturn(false);
        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(favoriteRepository.save(any(FavoriteCourse.class))).thenAnswer(inv -> {
            FavoriteCourse f = inv.getArgument(0);
            f.setId(1L);
            return f;
        });

        FavoriteCourse result = service.addFavorite(100L, 10L);

        assertNotNull(result);
        assertEquals(100L, result.getUserId());
        assertEquals(10L, result.getCourse().getId());
        verify(favoriteRepository).save(any(FavoriteCourse.class));
    }

    @Test
    void addFavorite_alreadyExists_returnsExisting() {
        FavoriteCourse existing = new FavoriteCourse();
        existing.setId(1L);
        existing.setUserId(100L);
        existing.setCourse(testCourse);

        when(favoriteRepository.existsByUserIdAndCourseId(100L, 10L)).thenReturn(true);
        when(favoriteRepository.findByUserIdAndCourseId(100L, 10L)).thenReturn(Optional.of(existing));

        FavoriteCourse result = service.addFavorite(100L, 10L);

        assertEquals(1L, result.getId());
        verify(favoriteRepository, never()).save(any(FavoriteCourse.class));
    }

    @Test
    void addFavorite_courseNotFound_throwsException() {
        when(favoriteRepository.existsByUserIdAndCourseId(100L, 999L)).thenReturn(false);
        when(courseRepository.findById(999L)).thenReturn(Optional.empty());

        assertThrows(VspApiException.class, () -> service.addFavorite(100L, 999L));
    }

    @Test
    void removeFavorite_exists_deletes() {
        when(favoriteRepository.existsByUserIdAndCourseId(100L, 10L)).thenReturn(true);

        service.removeFavorite(100L, 10L);

        verify(favoriteRepository).deleteByUserIdAndCourseId(100L, 10L);
    }

    @Test
    void removeFavorite_notFound_throwsException() {
        when(favoriteRepository.existsByUserIdAndCourseId(100L, 10L)).thenReturn(false);

        assertThrows(VspApiException.class, () -> service.removeFavorite(100L, 10L));
    }

    // ─── Recent Tests ─────────────────────────────────────────────────────

    @Test
    void getRecent_returnsRecentCourseDtos() {
        RecentCourse recent = new RecentCourse();
        recent.setId(1L);
        recent.setUserId(100L);
        recent.setCourse(testCourse);
        recent.setViewedAt(Instant.parse("2026-08-01T12:00:00Z"));

        when(recentRepository.findByUserIdOrderByViewedAtDesc(eq(100L), any(Pageable.class)))
                .thenReturn(List.of(recent));

        List<RecentCourseDto> result = service.getRecent(100L, 10);

        assertEquals(1, result.size());
        assertEquals(10L, result.get(0).getCourseId());
        assertEquals("Championship Course", result.get(0).getCourseName());
    }

    @Test
    void recordRecentView_newView_savesNew() {
        when(recentRepository.findByUserIdAndCourseId(100L, 10L)).thenReturn(Optional.empty());
        when(courseRepository.findById(10L)).thenReturn(Optional.of(testCourse));
        when(recentRepository.save(any(RecentCourse.class))).thenAnswer(inv -> {
            RecentCourse r = inv.getArgument(0);
            r.setId(1L);
            return r;
        });
        when(recentRepository.countByUserId(100L)).thenReturn(5L);

        RecentCourse result = service.recordRecentView(100L, 10L);

        assertNotNull(result);
        assertEquals(100L, result.getUserId());
        assertEquals(10L, result.getCourse().getId());
        verify(recentRepository).save(any(RecentCourse.class));
        verify(recentRepository, never()).deleteOldestByUserIdIfExceedsLimit(anyLong(), anyInt());
    }

    @Test
    void recordRecentView_courseNotFound_throwsException() {
        when(recentRepository.findByUserIdAndCourseId(100L, 999L)).thenReturn(Optional.empty());
        when(courseRepository.findById(999L)).thenReturn(Optional.empty());

        assertThrows(VspApiException.class, () -> service.recordRecentView(100L, 999L));
    }
}
