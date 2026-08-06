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

    public CourseSearchServiceImpl(
            CourseRepository courseRepository,
            GolfFacilityRepository facilityRepository,
            CourseSearchRepository searchRepository,
            FavoriteCourseRepository favoriteRepository,
            RecentCourseRepository recentRepository,
            DataVersionRepository dataVersionRepository) {
        this.courseRepository = courseRepository;
        this.facilityRepository = facilityRepository;
        this.searchRepository = searchRepository;
        this.favoriteRepository = favoriteRepository;
        this.recentRepository = recentRepository;
        this.dataVersionRepository = dataVersionRepository;
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
        return new PageResponse<>(results, page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
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

        // Check if a published package exists
        dto.setHasPackage(dataVersionRepository.findLatestPublishedByCourseId(course.getId()).isPresent());

        return dto;
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
                    dto.setDataFreshness(freshness);
                });
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
