package vnpt.vsp.module.course;

import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import vnpt.vsp.module.course.entity.ScorecardTee;
import vnpt.vsp.module.course.entity.ScorecardTeeYardage;
import vnpt.vsp.module.course.repository.ScorecardTeeRepository;

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
    private final ScorecardTeeRepository scorecardTeeRepository;
    private final CourseConditionRepository courseConditionRepository;
    private final DataVersionRepository dataVersionRepository;

    public CourseDetailServiceImpl(
            CourseRepository courseRepository,
            GolfFacilityRepository golfFacilityRepository,
            HoleRepository holeRepository,
            TeeSetRepository teeSetRepository,
            ScorecardTeeRepository scorecardTeeRepository,
            CourseConditionRepository courseConditionRepository,
            DataVersionRepository dataVersionRepository) {
        this.courseRepository = courseRepository;
        this.golfFacilityRepository = golfFacilityRepository;
        this.holeRepository = holeRepository;
        this.teeSetRepository = teeSetRepository;
        this.scorecardTeeRepository = scorecardTeeRepository;
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

        // Always null, and not for want of data.
        //
        // Neither `courses` nor `tee_sets` has ever had a rating or a slope
        // column; `scorecard_tees` is the only place in the schema that holds
        // either, and it holds them per tee row of a club's printed card. Two
        // things stand between those rows and this field, and neither is a
        // join:
        //
        // A card belongs to a facility and names the đường it was printed for.
        // A card printed for exactly this one đường rates it; a club with A, B
        // and C nines prints A+B, A+C and B+C, and none of those rates đường A
        // — A+B's rating is for the composite eighteen, and copying it here
        // would be inventing a number for a course nobody rated.
        //
        // And a rating is per tee. A card prints four or five, and this field
        // is one scalar that the app draws as an unlabelled "Course rating".
        // Picking the longest tee, or the highest number, or the first row is
        // a decision about what the screen claims, not a lookup — a golfer off
        // the white tees shown the black tee's 74.1/141 has been told something
        // false about their own round.
        //
        // What a client can do today: GET /facilities/{facilityId}/scorecards
        // carries every card's tees with their ratings and yardages. The client
        // knows which đường the golfer picked and which tee they are playing;
        // this endpoint knows neither.
        dto.setRating(null);
        dto.setSlope(null);

        // 5. Holes — eagerly load and map to HoleSummaryDto
        List<Hole> holes = holeRepository.findByCourseIdOrderByHoleNumber(courseId);
        dto.setHoles(holes.stream()
                .map(this::toHoleSummaryDto)
                .collect(Collectors.toList()));

        // 6. The tees a golfer picks between, off the club's published card
        // where there is one.
        //
        // `tee_sets` names them and holds no distance: tee_boxes carries the
        // teeing-ground point and nothing about how far the hole plays, so
        // this list has always gone out with an empty yardage map and the
        // picker has never been able to say what a tee measures. The card does
        // say — that is most of what a card is — so when the club has
        // published one, its rows are the answer.
        //
        // Falls back to `tee_sets` for a course with no card yet, which keeps
        // the names a club already has rather than emptying the picker.
        List<ScorecardTee> cardTees = scorecardTeeRepository.findWithYardagesByCourseId(courseId);
        if (!cardTees.isEmpty()) {
            dto.setTeeSets(cardTees.stream()
                    .map(CourseDetailServiceImpl::toTeeSummaryFromCard)
                    .collect(Collectors.toList()));
        } else {
            List<TeeSet> teeSets = teeSetRepository.findByCourseId(courseId);
            dto.setTeeSets(teeSets.stream()
                    .map(this::toTeeSetSummaryDto)
                    .collect(Collectors.toList()));
        }

        // 6b. The facility's other đường.
        //
        // A round is played on đường, and a club may hold several: Long Biên's
        // A, B and C are nine holes each and the golfer pairs two of them,
        // while Kings Island's three eighteens are each a round on their own.
        // The phone asks this endpoint what a course is; it also has to be
        // able to ask what else is here, and one round trip is enough.
        // Every one of them, each marked with whether it can be played yet.
        //
        // A course row is written when a club's structure is learned — Long
        // Biên's đường A, B and C, Kings Island's three sân — and it is written
        // with no hole rows on purpose, because a hole needs a par and a par
        // nobody read off the club's card is invented. `holes_count` says 9 or
        // 18 the whole time, since the club does have that many, so nothing on
        // the row itself tells the two states apart.
        //
        // Not filtered here, because the two screens that read this want
        // opposite things: round setup must not offer an empty đường, and
        // scorecard submission must, since that is where a golfer says which
        // đường their card was printed for. Filtering would leave exactly the
        // nines that need a card unable to receive one — empty because no card,
        // and no card because empty.
        List<Course> facilityCourses = courseRepository.findByFacilityId(facility.getId());
        Set<Long> withHoles = new HashSet<>(holeRepository.findCourseIdsWithHoles(
                facilityCourses.stream().map(Course::getId).toList()));
        dto.setFacilityCourses(facilityCourses.stream()
                .sorted(Comparator.comparing(Course::getName, String.CASE_INSENSITIVE_ORDER))
                .map(c -> new FacilityCourseDto(
                        c.getId(), c.getName(), c.getHolesCount(), c.getParTotal(),
                        withHoles.contains(c.getId())))
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

    /**
     * One tee of a published card, as the round-setup picker wants it.
     *
     * <p>Carries the yardages, which is the whole point: a golfer choosing
     * between GOLD and WHITE is choosing between seven thousand yards and six,
     * and until now the picker offered the names with no numbers behind them.
     * Course rating and slope come along because they are on the same row of
     * the same card and nothing else in the platform holds them.
     */
    private static TeeSetSummaryDto toTeeSummaryFromCard(ScorecardTee tee) {
        TeeSetSummaryDto dto = new TeeSetSummaryDto();
        dto.setId(tee.getId());
        dto.setName(tee.getName());
        dto.setRating(tee.getCourseRating());
        dto.setSlope(tee.getSlopeRating());
        Map<Integer, Integer> yardages = new HashMap<>();
        for (ScorecardTeeYardage y : tee.getYardages()) {
            yardages.put(y.getHoleNumber(), y.getYards());
        }
        dto.setYardages(yardages);
        dto.setTotalPar(null);   // par belongs to the hole, not to the tee
        return dto;
    }

    private TeeSetSummaryDto toTeeSetSummaryDto(TeeSet teeSet) {
        TeeSetSummaryDto dto = new TeeSetSummaryDto();
        dto.setId(teeSet.getId());
        dto.setName(teeSet.getName());
        dto.setTotalPar(teeSet.getTotalPar());
        dto.setRating(null);
        dto.setSlope(null);
        dto.setDataQuality(toDataQualityDto(teeSet.getDataQuality()));

        // No yardages, and no query to find that out with. This used to loop
        // over every hole asking tee_boxes for the same tee set eighteen times
        // over and throw all eighteen answers away — tee_boxes holds the
        // teeing-ground geometry and no distance, so there was never anything
        // in them to read. Yardages a golfer can trust are the ones printed on
        // the club's card, and those are published through
        // GET /facilities/{facilityId}/scorecards.
        dto.setYardages(new HashMap<>());
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
