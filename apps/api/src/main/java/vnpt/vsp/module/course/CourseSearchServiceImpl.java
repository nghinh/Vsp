package vnpt.vsp.module.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

import static net.logstash.logback.marker.Markers.append;
import vnpt.vsp.module.geometry.TracedHoleGeometry;
import vnpt.vsp.module.pkg.repository.PackageManifestRepository;

/**
 * Implementation of {@link CourseSearchService}.
 * Per Story 3.2 SD-BACK-1: AC-1 (text + geographic search with pagination),
 * AC-2 (ST_DWithin with GIST index), AC-3 (DataFreshnessDto, hasPackage, updateAvailable).
 */
@Service
@CourseModule
public class CourseSearchServiceImpl implements CourseSearchService {

    private static final Logger log = LoggerFactory.getLogger(CourseSearchServiceImpl.class);
    private static final int MAX_RADIUS_METERS = 50_000; // 50km max
    private static final int MAX_RECENT_COURSES = 10;

    private final CourseRepository courseRepository;
    private final GolfFacilityRepository facilityRepository;
    private final CourseSearchRepository searchRepository;
    private final FavoriteCourseRepository favoriteRepository;
    private final RecentCourseRepository recentRepository;
    private final DataVersionRepository dataVersionRepository;
    private final PackageManifestRepository manifestRepository;
    private final HoleRepository holeRepository;
    private final TracedHoleGeometry tracedGeometry;

    public CourseSearchServiceImpl(
            CourseRepository courseRepository,
            GolfFacilityRepository facilityRepository,
            CourseSearchRepository searchRepository,
            FavoriteCourseRepository favoriteRepository,
            RecentCourseRepository recentRepository,
            DataVersionRepository dataVersionRepository,
            PackageManifestRepository manifestRepository,
            HoleRepository holeRepository,
            TracedHoleGeometry tracedGeometry) {
        this.courseRepository = courseRepository;
        this.facilityRepository = facilityRepository;
        this.searchRepository = searchRepository;
        this.favoriteRepository = favoriteRepository;
        this.recentRepository = recentRepository;
        this.dataVersionRepository = dataVersionRepository;
        this.manifestRepository = manifestRepository;
        this.holeRepository = holeRepository;
        this.tracedGeometry = tracedGeometry;
    }

    // ─── Search ───────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public PageResponse<CourseSearchResultDto> searchCourses(CourseSearchRequest request) {
        log.debug(append("action", "SEARCH_COURSES"), "q={}, lat={}, lng={}, radius={}",
                request.getQ(), request.getLat(), request.getLng(), request.getRadiusMeters());

        if (request.isTextOnly()) {
            return searchByText(request);
        } else if (request.isNearbyOnly()) {
            return searchByNearby(request);
        } else if (request.isCombined()) {
            return searchCombined(request);
        } else {
            // No filters — browse the full course catalogue (paginated).
            // An empty text query matches every course via LIKE '%%'.
            request.setQ("");
            return searchByText(request);
        }
    }

    @Override
    @Transactional(readOnly = true)
    public CourseSearchResultDto getCourseSearchResult(Long courseId, Integer downloadedVersion) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001, "courseId"));
        CourseSearchResultDto dto = toSearchResultDto(course);
        enrichUpdateAvailable(dto, downloadedVersion);
        return dto;
    }

    private PageResponse<CourseSearchResultDto> searchByText(CourseSearchRequest request) {
        Pageable pageable = PageRequest.of(request.getPage(), request.getSize());
        Page<Course> page = searchRepository.searchByText(request.getQ(), pageable);
        List<CourseSearchResultDto> results = page.getContent().stream()
                .map(course -> {
                    CourseSearchResultDto dto = toSearchResultDto(course);
                    enrichUpdateAvailable(dto, request.getDownloadedVersion());
                    return dto;
                })
                .collect(Collectors.toList());
        fillCourseCounts(results);
        return new PageResponse<>(results, page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }

    /**
     * How many playable courses each club on this page has.
     *
     * <p>A search result is a club now, and the app needs to know whether
     * tapping it opens a course or has to ask which đường first. Fetched for
     * the whole page in one query — asking per row is what turns a list of
     * twenty clubs into twenty-one round trips.
     *
     * <p>Defaults to one where the count comes back empty, which is the
     * honest answer: the club is on the page because it had a playable course.
     */
    private void fillCourseCounts(List<CourseSearchResultDto> results) {
        if (results.isEmpty()) {
            return;
        }
        List<Long> facilityIds = results.stream()
                .map(CourseSearchResultDto::getFacilityId)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        if (facilityIds.isEmpty()) {
            return;
        }

        var counts = new java.util.HashMap<Long, Integer>();
        for (Object[] row : searchRepository.countPlayableByFacility(facilityIds)) {
            counts.put(((Number) row[0]).longValue(), ((Number) row[1]).intValue());
        }
        for (CourseSearchResultDto dto : results) {
            dto.setCourseCount(counts.getOrDefault(dto.getFacilityId(), 1));
        }
    }

    private PageResponse<CourseSearchResultDto> searchByNearby(CourseSearchRequest request) {
        validateRadius(request.getRadiusMeters());
        Pageable pageable = PageRequest.of(request.getPage(), request.getSize());

        List<Object[]> rawResults = searchRepository.findNearbyCourseIdsAndDistances(
                request.getLat(), request.getLng(), request.getRadiusMeters(), pageable);

        List<CourseSearchResultDto> results = mapNearbyResults(rawResults, request);
        // Note: total count requires a separate count query for native SQL — use page size as estimate
        int totalPages = (int) Math.ceil((double) results.size() / request.getSize());
        return new PageResponse<>(results, request.getPage(), request.getSize(),
                results.size(), Math.max(1, totalPages));
    }

    private PageResponse<CourseSearchResultDto> searchCombined(CourseSearchRequest request) {
        validateRadius(request.getRadiusMeters());
        Pageable pageable = PageRequest.of(request.getPage(), request.getSize());

        List<Object[]> rawResults = searchRepository.findNearbyCourseIdsAndDistancesWithText(
                request.getLat(), request.getLng(), request.getRadiusMeters(), request.getQ(), pageable);

        List<CourseSearchResultDto> results = mapNearbyResults(rawResults, request);
        int totalPages = (int) Math.ceil((double) results.size() / request.getSize());
        return new PageResponse<>(results, request.getPage(), request.getSize(),
                results.size(), Math.max(1, totalPages));
    }

    private void validateRadius(Double radiusMeters) {
        if (radiusMeters != null && radiusMeters > MAX_RADIUS_METERS) {
            throw new VspApiException(VspErrorCode.COURSE_006,
                    "Search radius exceeds maximum of " + (MAX_RADIUS_METERS / 1000) + "km");
        }
    }

    // ─── Enrichment ───────────────────────────────────────────────────────

    /**
     * Maps raw [courseId, distanceMeters] results to enriched CourseSearchResultDto.
     */
    private List<CourseSearchResultDto> mapNearbyResults(List<Object[]> rawResults,
                                                         CourseSearchRequest request) {
        if (rawResults.isEmpty()) return List.of();

        // Extract course IDs in order
        List<Long> courseIds = rawResults.stream()
                .map(row -> ((Number) row[0]).longValue())
                .collect(Collectors.toList());

        // Load courses with facilities (maintain order)
        Map<Long, Course> courseMap = courseRepository.findAllById(courseIds).stream()
                .collect(Collectors.toMap(Course::getId, c -> c));

        // Build results preserving query order
        List<CourseSearchResultDto> results = new ArrayList<>();
        for (Object[] row : rawResults) {
            Long courseId = ((Number) row[0]).longValue();
            BigDecimal distanceMeters = row[1] != null ? new BigDecimal(row[1].toString()) : null;
            Course course = courseMap.get(courseId);
            if (course != null) {
                CourseSearchResultDto dto = toSearchResultDto(course);
                dto.setDistanceMeters(distanceMeters);
                enrichUpdateAvailable(dto, request.getDownloadedVersion());
                results.add(dto);
            }
        }
        return results;
    }

    /**
     * Converts a Course entity to CourseSearchResultDto and enriches with
     * DataFreshnessDto and hasPackage.
     */
    private CourseSearchResultDto toSearchResultDto(Course course) {
        CourseSearchResultDto dto = new CourseSearchResultDto();
        GolfFacility facility = course.getFacility();

        dto.setCourseId(course.getId());
        dto.setFacilityId(facility != null ? facility.getId() : null);
        dto.setFacilityName(facility != null ? facility.getName() : null);
        dto.setCourseName(course.getName());
        dto.setAddress(facility != null ? facility.getAddress() : null);
        dto.setHolesCount(course.getHolesCount());
        dto.setParTotal(course.getParTotal());

        // Coordinates from GolfFacility.location POINT via PostGIS (ST_X/ST_Y).
        // The location column is a geometry; reading it as a String yields EWKB hex
        // which is not human-parseable, so we query the projected lon/lat directly.
        if (facility != null && facility.getId() != null) {
            Double lon = facilityRepository.findLongitudeByFacilityId(facility.getId());
            Double lat = facilityRepository.findLatitudeByFacilityId(facility.getId());
            if (lat != null) dto.setLatitude(lat);
            if (lon != null) dto.setLongitude(lon);
        }

        // Enrich with data freshness from latest published DataVersion
        enrichDataFreshness(dto, course.getId());

        dto.setHasPackage(hasDownloadablePackage(course.getId()));

        return dto;
    }

    /// Whether there is actually something on the other end of Download.
    ///
    /// This used to answer "is there a published DataVersion", which is a
    /// different question with a different answer: publishing a course version
    /// and building a package from it are separate steps, and the second one
    /// has been failing quietly. So all 50 courses advertised a download while
    /// 8 had a manifest and every one of those had package_size_bytes = 0.
    ///
    /// A manifest with no bytes behind it is not a package. Requiring a real
    /// size is what keeps "offline ready" from being a promise the app cannot
    /// keep on the first tee with no signal.
    private boolean hasDownloadablePackage(Long courseId) {
        return manifestRepository
                .findActiveManifest(courseId, Instant.now())
                .filter(manifest -> manifest.getPackageSizeBytes() != null
                        && manifest.getPackageSizeBytes() > 0)
                .isPresent();
    }

    private void enrichDataFreshness(CourseSearchResultDto dto, Long courseId) {
        dataVersionRepository.findLatestPublishedByCourseId(courseId)
                .ifPresent(dv -> {
                    DataFreshnessDto freshness = new DataFreshnessDto();
                    freshness.setPublishedAt(dv.getPublishedAt() != null
                            ? dv.getPublishedAt().atOffset(ZoneOffset.UTC).toString() : null);
                    freshness.setVersionNumber(dv.getVersionNumber());
                    freshness.setPublisher(dv.getMetadata().getPublisher());
                    freshness.setVerificationStatus(
                            dv.getMetadata().getVerificationStatus() != null
                                    ? dv.getMetadata().getVerificationStatus().name() : null);
                    freshness.setAccuracyClass(
                            dv.getMetadata().getAccuracyClass() != null
                                    ? dv.getMetadata().getAccuracyClass().name() : null);
                    freshness.setLastVerifiedAt(dv.getMetadata().getLastVerifiedAt() != null
                            ? dv.getMetadata().getLastVerifiedAt().toString() : null);
                    applyHoleProvenance(freshness, courseId);
                    dto.setDataFreshness(freshness);
                });
    }

    /**
     * Overrides the course-level badge with what the holes actually say.
     *
     * <p>The badge came from the course's {@code data_version} metadata, and
     * geometry review does not touch that — it verifies holes. So Long Thành
     * listed itself as "Chưa xác minh" to every golfer while all eighteen of
     * its holes were verified and the app was drawing its strategic map from
     * them. Two sources of truth for one question, and the one shown was the
     * one nothing updated.</p>
     *
     * <p>Only a course whose every hole passes the app's own gate is badged
     * verified. A partially reviewed course is still unverified: a golfer
     * cannot tell from a course badge which of its holes they can trust, so the
     * badge has to describe the weakest one.</p>
     */
    private void applyHoleProvenance(DataFreshnessDto freshness, Long courseId) {
        long holes = holeRepository.countByCourseId(courseId);
        if (holes == 0) {
            return;
        }
        long surveyed = holeRepository.countSurveyedHoles(courseId);

        // A hole row saying VERIFIED is not the same as its shapes having
        // been checked, and the badge has to answer the question the map
        // does. Long Biên's twenty-seven hole rows all say VERIFIED /
        // C_VERIFIED_SATELLITE, so this badged the course verified — while
        // 465 of the 488 shapes its map draws came out of GolfSeg and no
        // person had looked at one of them. The app's own map says so on
        // every hole: "traced from satellite imagery by AI, not yet checked
        // by a human". The listing was contradicting it.
        //
        // Any unreviewed shape is enough to withhold the badge, for the
        // reason a partly-reviewed course is already withheld: a golfer
        // cannot tell from a course badge which bunker they can trust, so it
        // has to describe the weakest thing on the course.
        if (surveyed == holes && tracedGeometry.unreviewedShapes(courseId) > 0) {
            freshness.setVerificationStatus(VerificationStatus.PENDING_REVIEW.name());
            var weakest = holeRepository.weakestAccuracyClass(courseId);
            if (weakest != null) {
                freshness.setAccuracyClass(weakest.name());
            }
        } else if (surveyed == holes) {
            freshness.setVerificationStatus(VerificationStatus.VERIFIED.name());
            // The class has to move with the status. The client badges on both
            // — "verified" plus class D reads as unverified there, exactly as
            // the hole map treats it — so leaving the class on the stale
            // data_version left the two disagreeing and the badge kept showing
            // the old answer. Weakest class across the holes, because a course
            // badge describes what holds everywhere on the course.
            var weakest = holeRepository.weakestAccuracyClass(courseId);
            if (weakest != null) {
                freshness.setAccuracyClass(weakest.name());
            }
        } else if (freshness.getVerificationStatus() == null
                || VerificationStatus.VERIFIED.name().equals(freshness.getVerificationStatus())) {
            // The version row claimed verified while its holes are not. The
            // holes are what the app gates on, so they win.
            freshness.setVerificationStatus(
                    surveyed > 0
                            ? VerificationStatus.PENDING_REVIEW.name()
                            : VerificationStatus.UNVERIFIED.name());
        }
    }

    private void enrichUpdateAvailable(CourseSearchResultDto dto, Integer downloadedVersion) {
        if (downloadedVersion == null || dto.getDataFreshness() == null) {
            dto.setUpdateAvailable(false);
            return;
        }
        Integer latestVersion = dto.getDataFreshness().getVersionNumber();
        dto.setUpdateAvailable(latestVersion != null && !latestVersion.equals(downloadedVersion));
    }

    /**
     * Parses WKT POINT string (e.g., "POINT(106.6299 10.8231)") to [lng, lat].
     */
    private double[] parseWktPoint(String wkt) {
        // Accepts any "POINT(x y)" / "POINT (x y)" (JTS emits a space) and even an
        // SRID-prefixed EWKT — we simply read the two numbers between the parens.
        if (wkt == null) return null;
        try {
            int open = wkt.indexOf('(');
            int close = wkt.indexOf(')');
            if (open < 0 || close <= open) return null;
            String[] parts = wkt.substring(open + 1, close).trim().split("\\s+");
            if (parts.length < 2) return null;
            return new double[]{Double.parseDouble(parts[0]), Double.parseDouble(parts[1])};
        } catch (Exception e) {
            return null;
        }
    }

    // ─── Favorites ────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public List<FavoriteCourseDto> getFavorites(Long userId) {
        return favoriteRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::toFavoriteDto)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public FavoriteCourse addFavorite(Long userId, Long courseId) {
        if (favoriteRepository.existsByUserIdAndCourseId(userId, courseId)) {
            // Already favorited — return existing
            return favoriteRepository.findByUserIdAndCourseId(userId, courseId).orElse(null);
        }
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));

        FavoriteCourse favorite = new FavoriteCourse();
        favorite.setUserId(userId);
        favorite.setCourse(course);
        FavoriteCourse saved = favoriteRepository.save(favorite);
        log.info(append("action", "ADD_FAVORITE"), "userId={}, courseId={}", userId, courseId);
        return saved;
    }

    @Override
    @Transactional
    public void removeFavorite(Long userId, Long courseId) {
        if (!favoriteRepository.existsByUserIdAndCourseId(userId, courseId)) {
            throw new VspApiException(VspErrorCode.COURSE_008);
        }
        favoriteRepository.deleteByUserIdAndCourseId(userId, courseId);
        log.info(append("action", "REMOVE_FAVORITE"), "userId={}, courseId={}", userId, courseId);
    }

    private FavoriteCourseDto toFavoriteDto(FavoriteCourse fav) {
        FavoriteCourseDto dto = new FavoriteCourseDto();
        Course course = fav.getCourse();
        GolfFacility facility = course.getFacility();
        dto.setCourseId(course.getId());
        dto.setFacilityId(facility != null ? facility.getId() : null);
        dto.setFacilityName(facility != null ? facility.getName() : null);
        dto.setCourseName(course.getName());
        dto.setAddress(facility != null ? facility.getAddress() : null);
        dto.setHolesCount(course.getHolesCount());
        dto.setFavoritedAt(fav.getCreatedAt() != null
                ? fav.getCreatedAt().toString() : null);
        return dto;
    }

    // ─── Recent ───────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public List<RecentCourseDto> getRecent(Long userId, int limit) {
        Pageable pageable = PageRequest.of(0, Math.min(limit, MAX_RECENT_COURSES));
        return recentRepository.findByUserIdOrderByViewedAtDesc(userId, pageable).stream()
                .map(this::toRecentDto)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public RecentCourse recordRecentView(Long userId, Long courseId) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));

        RecentCourse recent = recentRepository.findByUserIdAndCourseId(userId, courseId)
                .orElseGet(() -> {
                    RecentCourse r = new RecentCourse();
                    r.setUserId(userId);
                    r.setCourse(course);
                    return r;
                });

        recent.setViewedAt(Instant.now());
        RecentCourse saved = recentRepository.save(recent);

        // Enforce 10-entry cap
        long count = recentRepository.countByUserId(userId);
        if (count > MAX_RECENT_COURSES) {
            recentRepository.deleteOldestByUserIdIfExceedsLimit(userId, MAX_RECENT_COURSES);
        }

        log.info(append("action", "RECORD_RECENT_VIEW"), "userId={}, courseId={}", userId, courseId);
        return saved;
    }

    private RecentCourseDto toRecentDto(RecentCourse recent) {
        RecentCourseDto dto = new RecentCourseDto();
        Course course = recent.getCourse();
        GolfFacility facility = course.getFacility();
        dto.setCourseId(course.getId());
        dto.setFacilityId(facility != null ? facility.getId() : null);
        dto.setFacilityName(facility != null ? facility.getName() : null);
        dto.setCourseName(course.getName());
        dto.setAddress(facility != null ? facility.getAddress() : null);
        dto.setHolesCount(course.getHolesCount());
        dto.setViewedAt(recent.getViewedAt() != null
                ? recent.getViewedAt().toString() : null);
        return dto;
    }
}
