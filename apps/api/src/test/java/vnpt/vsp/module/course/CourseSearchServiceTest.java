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

    @Mock
    private vnpt.vsp.module.pkg.repository.PackageManifestRepository manifestRepository;

    @Mock
    private vnpt.vsp.module.course.repository.HoleRepository holeRepository;

    @Mock
    private vnpt.vsp.module.geometry.TracedHoleGeometry tracedGeometry;

    private CourseSearchServiceImpl service;

    private GolfFacility testFacility;
    private Course testCourse;
    private DataVersion testDataVersion;

    @BeforeEach
    void setUp() {
        service = new CourseSearchServiceImpl(
                courseRepository, facilityRepository, searchRepository,
                favoriteRepository, recentRepository, dataVersionRepository,
                manifestRepository, holeRepository, tracedGeometry);

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
        // A published DataVersion is no longer enough to claim a download —
        // see the offline-availability group below.
        assertFalse(dto.isHasPackage());
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

    // ─── Offline availability ──────────────────────────────────────────────
    //
    // hasPackage used to answer "is there a published DataVersion", which is a
    // different question: publishing a version and building a package from it
    // are separate steps and the second was failing quietly. So all 50 courses
    // advertised a download, 8 had a manifest, and every one of those had
    // package_size_bytes = 0 — a Download button with nothing behind it, which
    // a golfer discovers on the first tee with no signal.

    private vnpt.vsp.module.pkg.entity.CoursePackageManifest manifest(Long sizeBytes) {
        return new vnpt.vsp.module.pkg.entity.CoursePackageManifest(
                testCourse.getId(), 100L, "1.0.0", sizeBytes, "checksum",
                Instant.parse("2026-07-15T10:00:00Z"), "1.0.0",
                vnpt.vsp.module.pkg.entity.CoursePackageManifest.TilesFormat.PMTILES,
                "tiles", "geojson", Instant.parse("2026-07-15T10:00:00Z"), "tester");
    }

    private boolean hasPackageFor(Optional<vnpt.vsp.module.pkg.entity.CoursePackageManifest> manifest) {
        when(manifestRepository.findActiveManifest(eq(10L), any())).thenReturn(manifest);
        when(searchRepository.searchByText(eq("Championship"), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(testCourse)));

        CourseSearchRequest request = new CourseSearchRequest();
        request.setQ("Championship");
        request.setPage(0);
        request.setSize(20);

        return service.searchCourses(request).getContent().get(0).isHasPackage();
    }

    @Test
    void aCourseWithAPackageThatHasBytesIsDownloadable() {
        assertTrue(hasPackageFor(Optional.of(manifest(4_200_000L))));
    }

    @Test
    void aCourseWithNoManifestIsNotDownloadable() {
        assertFalse(hasPackageFor(Optional.empty()));
    }

    @Test
    void aManifestWithNoBytesBehindItIsNotAPackage() {
        // The exact state of all 8 manifests in the database today.
        assertFalse(hasPackageFor(Optional.of(manifest(0L))));
    }

    @Test
    void aManifestWithAnUnknownSizeIsNotAPackage() {
        assertFalse(hasPackageFor(Optional.of(manifest(null))));
    }

    // ─── The badge a golfer reads ──────────────────────────────────────────

    private CourseSearchResultDto badgeFor(long holes, long surveyed) {
        return badgeFor(holes, surveyed, 0);
    }

    private CourseSearchResultDto badgeFor(long holes, long surveyed, long unreviewedShapes) {
        CourseSearchRequest request = new CourseSearchRequest();
        request.setQ("Thuyle");
        request.setPage(0);
        request.setSize(20);

        when(searchRepository.searchByText(eq("Thuyle"), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(testCourse)));
        when(dataVersionRepository.findLatestPublishedByCourseId(10L))
                .thenReturn(Optional.of(testDataVersion));
        when(holeRepository.countByCourseId(10L)).thenReturn(holes);
        when(holeRepository.countSurveyedHoles(10L)).thenReturn(surveyed);
        when(holeRepository.weakestAccuracyClass(10L))
                .thenReturn(vnpt.vsp.module.course.entity.AccuracyClass.C_VERIFIED_SATELLITE);
        when(tracedGeometry.unreviewedShapes(10L)).thenReturn(unreviewedShapes);

        return service.searchCourses(request).getContent().get(0);
    }

    @Test
    void aCourseWithEveryHoleVerifiedIsBadgedVerified() {
        assertEquals("VERIFIED",
                badgeFor(18, 18).getDataFreshness().getVerificationStatus());
    }

    @Test
    void aPartlyReviewedCourseIsNotBadgedVerified() {
        // The version row says VERIFIED — the seed wrote it that way, and
        // geometry review does not touch it. The holes are what the app gates
        // on, and a golfer cannot tell from a course badge which eight holes to
        // distrust, so the badge describes the weakest one.
        assertEquals("PENDING_REVIEW",
                badgeFor(18, 10).getDataFreshness().getVerificationStatus());
    }

    @Test
    void aCourseWithNoVerifiedHolesIsUnverified() {
        assertEquals("UNVERIFIED",
                badgeFor(18, 0).getDataFreshness().getVerificationStatus());
    }

    @Test
    void aCourseWithNoHolesKeepsWhateverTheVersionSaid() {
        // Nothing to derive from. Inventing a status here would be the same
        // mistake in the other direction.
        assertEquals("VERIFIED",
                badgeFor(0, 0).getDataFreshness().getVerificationStatus());
    }

    @Test
    void aVerifiedCourseAlsoReportsTheClassItsHolesCarry() {
        // The client badges on status AND class — "verified" plus class D reads
        // as unverified there, exactly as the hole map treats it. Deriving one
        // from the holes and leaving the other on the stale data_version left
        // the two disagreeing, and Long Thành kept showing "Chưa xác minh" on
        // the device while the API said VERIFIED.
        assertEquals("C_VERIFIED_SATELLITE",
                badgeFor(18, 18).getDataFreshness().getAccuracyClass());
    }

    @Test
    void aCourseDrawnFromUncheckedShapesIsNotBadgedVerified() {
        // Long Biên. Twenty-seven hole rows all saying VERIFIED /
        // C_VERIFIED_SATELLITE, and 465 of the 488 shapes its map draws
        // traced by GolfSeg with nobody having looked at one of them. The map
        // told the golfer so on every hole — "traced from satellite imagery by
        // AI, not yet checked by a human" — while the listing badged the same
        // course "đã kiểm định".
        assertEquals("PENDING_REVIEW",
                badgeFor(18, 18, 465).getDataFreshness().getVerificationStatus());
    }

    @Test
    void aCourseWhoseShapesWereAllCheckedKeepsItsBadge() {
        // The badge is not being retired, only made to mean something. A
        // course somebody actually reviewed still says so.
        assertEquals("VERIFIED",
                badgeFor(18, 18, 0).getDataFreshness().getVerificationStatus());
    }

    @Test
    void anUncheckedCourseStillReportsTheClassItsHolesCarry() {
        // The client badges on status and class together. Withholding the
        // status while leaving the class stale is how the two came to
        // disagree in the first place.
        assertEquals("C_VERIFIED_SATELLITE",
                badgeFor(18, 18, 465).getDataFreshness().getAccuracyClass());
    }
}
