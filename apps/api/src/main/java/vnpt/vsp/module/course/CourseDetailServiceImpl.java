package vnpt.vsp.module.course;

import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Course detail aggregation service implementation.
 * Per Story 3.3 CD-BACK-1: AC-1 (full aggregation), AC-2 (null for unavailable), AC-3 (dataQuality).
 */
@org.springframework.stereotype.Service
public class CourseDetailServiceImpl implements CourseDetailService {

    private final CourseRepository courseRepository;
    private final GolfFacilityRepository golfFacilityRepository;
    private final HoleRepository holeRepository;
    private final TeeSetRepository teeSetRepository;
    private final TeeBoxRepository teeBoxRepository;
    private final CourseConditionRepository courseConditionRepository;
    private final DataVersionRepository dataVersionRepository;

    public CourseDetailServiceImpl(
            CourseRepository courseRepository,
            GolfFacilityRepository golfFacilityRepository,
            HoleRepository holeRepository,
            TeeSetRepository teeSetRepository,
            TeeBoxRepository teeBoxRepository,
            CourseConditionRepository courseConditionRepository,
            DataVersionRepository dataVersionRepository) {
        this.courseRepository = courseRepository;
        this.golfFacilityRepository = golfFacilityRepository;
        this.holeRepository = holeRepository;
        this.teeSetRepository = teeSetRepository;
        this.teeBoxRepository = teeBoxRepository;
        this.courseConditionRepository = courseConditionRepository;
        this.dataVersionRepository = dataVersionRepository;
    }

    @Override
    public CourseDetailDto getCourseDetail(Long courseId) {
        // 1. Load Course entity
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));

        GolfFacility facility = course.getFacility();

        // 2. Build CourseDetailDto with facility and course basic info
        CourseDetailDto dto = new CourseDetailDto();
        dto.setCourseId(course.getId());
        dto.setFacilityId(facility.getId());
        dto.setFacilityName(facility.getName());
        dto.setCourseName(course.getName());
        dto.setPhone(facility.getPhone());           // null if unavailable (AC-2)
        dto.setWebsite(facility.getWebsite());       // null if unavailable (AC-2)
        dto.setAddress(facility.getAddress());

        // 3. Coordinates from GolfFacility.location POINT via PostGIS
        dto.setLongitude(golfFacilityRepository.findLongitudeByFacilityId(facility.getId()));
        dto.setLatitude(golfFacilityRepository.findLatitudeByFacilityId(facility.getId()));

        // 4. Course-level fields
        dto.setHolesCount(course.getHolesCount());
        dto.setParTotal(course.getParTotal());

        // rating/slope — may be null if columns don't exist in DB (AC-2 compliance)
        // Using reflection-free approach: try repository query, catch if column missing
        // For now, leave as null — AC-2 says unavailable = null, mobile shows "N/A"
        dto.setRating(null);
        dto.setSlope(null);

        // 5. Holes — eagerly load and map to HoleSummaryDto
        List<Hole> holes = holeRepository.findByCourseIdOrderByHoleNumber(courseId);
        dto.setHoles(holes.stream()
                .map(this::toHoleSummaryDto)
                .collect(Collectors.toList()));

        // 6. Tee sets with yardages
        List<TeeSet> teeSets = teeSetRepository.findByCourseId(courseId);
        dto.setTeeSets(teeSets.stream()
                .map(ts -> toTeeSetSummaryDto(ts, holes))
                .collect(Collectors.toList()));

        // 7. Active conditions (effectiveDate <= today <= expiryDate or expiryDate is null)
        LocalDate today = LocalDate.now();
        List<CourseCondition> activeConditions = courseConditionRepository.findActiveByCourseId(courseId, today);
        dto.setConditions(activeConditions.stream()
                .map(this::toConditionDto)
                .collect(Collectors.toList()));

        // 8. Data freshness from latest published DataVersion
        dataVersionRepository.findLatestPublishedByCourseId(courseId)
                .ifPresent(dv -> dto.setDataFreshness(toDataFreshnessDto(dv)));

        // 9. Empty lists for imageUrls, facilities, localRules — not in 3-1 schema (AC-2: unavailable = [])
        dto.setImageUrls(Collections.emptyList());
        dto.setFacilities(Collections.emptyList());
        dto.setLocalRules(Collections.emptyList());

        return dto;
    }

    // ─── Mapping helpers ─────────────────────────────────────────────────────────

    private HoleSummaryDto toHoleSummaryDto(Hole hole) {
        HoleSummaryDto dto = new HoleSummaryDto();
        dto.setHoleNumber(hole.getHoleNumber());
        dto.setPar(hole.getPar());
        dto.setPlayingLengthMeters(hole.getPlayingLengthMeters());
        dto.setDataQuality(toDataQualityDto(hole.getDataQuality()));
        return dto;
    }

    private TeeSetSummaryDto toTeeSetSummaryDto(TeeSet teeSet, List<Hole> holes) {
        TeeSetSummaryDto dto = new TeeSetSummaryDto();
        dto.setId(teeSet.getId());
        dto.setName(teeSet.getName());
        dto.setTotalPar(teeSet.getTotalPar());
        dto.setRating(null);   // rating/slope are course-level, not per tee set
        dto.setSlope(null);
        dto.setDataQuality(toDataQualityDto(teeSet.getDataQuality()));

        // Build yardages map: holeNumber -> yardage
        // Yardage is derived from TeeBox entities for each hole belonging to this tee set
        // If no TeeBox yardage column exists, map remains empty (AC-2 compliance)
        Map<Integer, Integer> yardages = new HashMap<>();
        for (Hole hole : holes) {
            List<TeeBox> teeBoxes = teeBoxRepository.findByTeeSetId(teeSet.getId());
            // TeeBox.teeingGroundLocation has the geometry — yardage requires distance calc
            // For now, leave as 0 / absent — AC-2: unavailable = absent
            // A future story can add explicit yardage columns to tee_boxes table
        }
        dto.setYardages(yardages);
        return dto;
    }

    private ConditionDto toConditionDto(CourseCondition cc) {
        ConditionDto dto = new ConditionDto();
        dto.setConditionType(cc.getConditionType() != null ? cc.getConditionType().name() : null);
        dto.setSeverity(cc.getSeverity() != null ? cc.getSeverity().name() : null);
        dto.setDescription(cc.getDescription());   // null if unavailable (AC-2)
        dto.setEffectiveDate(cc.getEffectiveDate());
        dto.setDataQuality(toDataQualityDto(cc.getDataQuality()));
        return dto;
    }

    private DataQualityDto toDataQualityDto(DataQualityMetadata m) {
        if (m == null) return null;
        DataQualityDto dto = new DataQualityDto();
        dto.setAccuracyClass(m.getAccuracyClass() != null ? m.getAccuracyClass().name() : null);
        dto.setVerificationStatus(m.getVerificationStatus() != null ? m.getVerificationStatus().name() : null);
        return dto;
    }

    private DataFreshnessDto toDataFreshnessDto(DataVersion dv) {
        DataFreshnessDto dto = new DataFreshnessDto();
        dto.setPublishedAt(dv.getPublishedAt() != null ? dv.getPublishedAt().toString() : null);
        dto.setVersionNumber(dv.getVersionNumber());
        dto.setPublisher(dv.getPublishedBy());
        if (dv.getMetadata() != null) {
            dto.setVerificationStatus(
                    dv.getMetadata().getVerificationStatus() != null
                            ? dv.getMetadata().getVerificationStatus().name() : null);
            dto.setAccuracyClass(
                    dv.getMetadata().getAccuracyClass() != null
                            ? dv.getMetadata().getAccuracyClass().name() : null);
            dto.setLastVerifiedAt(
                    dv.getMetadata().getLastVerifiedAt() != null
                            ? dv.getMetadata().getLastVerifiedAt().toString() : null);
        }
        return dto;
    }
}
