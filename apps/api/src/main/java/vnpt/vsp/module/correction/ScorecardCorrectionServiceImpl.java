package vnpt.vsp.module.correction;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.correction.dto.ScorecardSubmissionRequest;
import vnpt.vsp.module.correction.entity.CorrectionType;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.Scorecard;
import vnpt.vsp.module.course.entity.ScorecardHole;
import vnpt.vsp.module.course.entity.ScorecardSegment;
import vnpt.vsp.module.course.entity.ScorecardTee;
import vnpt.vsp.module.course.entity.ScorecardTeeYardage;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.ScorecardRepository;
import vnpt.vsp.module.course.repository.ScorecardTeeRepository;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
public class ScorecardCorrectionServiceImpl implements ScorecardCorrectionService {

    private static final Logger log = LoggerFactory.getLogger(ScorecardCorrectionServiceImpl.class);

    private final CourseCorrectionRepository correctionRepository;
    private final ScorecardRepository scorecardRepository;
    private final ScorecardTeeRepository scorecardTeeRepository;
    private final CourseRepository courseRepository;
    private final ObjectMapper objectMapper;

    public ScorecardCorrectionServiceImpl(
            CourseCorrectionRepository correctionRepository,
            ScorecardRepository scorecardRepository,
            ScorecardTeeRepository scorecardTeeRepository,
            CourseRepository courseRepository,
            ObjectMapper objectMapper) {
        this.correctionRepository = correctionRepository;
        this.scorecardRepository = scorecardRepository;
        this.scorecardTeeRepository = scorecardTeeRepository;
        this.courseRepository = courseRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    @Transactional
    public CourseCorrection submit(Long courseId, Long reporterId, ScorecardSubmissionRequest request) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));

        validate(course, request);

        CourseCorrection correction = new CourseCorrection();
        correction.setCourseId(courseId);
        correction.setReporterId(reporterId);
        correction.setCorrectionType(CorrectionType.SCORECARD);
        correction.setReporterNote(request.note());
        correction.setReporterEvidenceUrl(request.evidenceUrl());
        correction.getMetadata().setPublisher("golfer:" + reporterId);
        correction.getMetadata().setSource("golfer-submitted-scorecard");
        correction.setProposedScorecard(writeJson(request));

        CourseCorrection saved = correctionRepository.save(correction);
        log.info("Scorecard submitted for course {} by {} — {} holes, correction {}",
                courseId, reporterId, request.holes().size(), saved.getId());
        return saved;
    }

    /**
     * A card has to be a whole round of numbers, and each number has to be one
     * a golfer could have read.
     *
     * <p>The database enforces the ranges and the uniqueness of a stroke
     * index; this is here so the golfer is told which line is wrong while the
     * card is still in front of them, rather than being handed a constraint
     * violation.
     */
    private void validate(Course course, ScorecardSubmissionRequest request) {
        List<Integer> numbers = request.holes().stream().map(ScorecardSubmissionRequest.HoleLine::hole).toList();
        if (numbers.stream().distinct().count() != numbers.size()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "holes",
                    Map.of("holes", "a hole appears twice on this card"));
        }
        for (int expected = 1; expected <= numbers.size(); expected++) {
            if (!numbers.contains(expected)) {
                throw VspApiException.forField(VspErrorCode.VALIDATION_001, "holes",
                        Map.of("holes", "hole " + expected + " is missing"));
            }
        }

        List<Integer> indexes = request.holes().stream()
                .map(ScorecardSubmissionRequest.HoleLine::strokeIndex)
                .filter(java.util.Objects::nonNull)
                .toList();
        if (indexes.stream().distinct().count() != indexes.size()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "strokeIndex",
                    Map.of("strokeIndex", "two holes share a stroke index"));
        }

        for (Long segmentCourseId : request.segmentCourseIds()) {
            Course segment = courseRepository.findById(segmentCourseId)
                    .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
            if (!segment.getFacility().getId().equals(course.getFacility().getId())) {
                throw VspApiException.forField(VspErrorCode.VALIDATION_001, "segmentCourseIds",
                        Map.of("segmentCourseIds", "đường " + segmentCourseId + " belongs to another club"));
            }
        }
    }

    @Override
    @Transactional
    public void applyIfScorecard(CourseCorrection correction) {
        if (correction.getCorrectionType() != CorrectionType.SCORECARD
                || correction.getProposedScorecard() == null) {
            return;
        }

        ScorecardSubmissionRequest proposed = readJson(correction.getProposedScorecard());
        Course course = courseRepository.findById(correction.getCourseId())
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
        Long facilityId = course.getFacility().getId();

        // A club reprints its card; the approved one replaces what was there
        // under the same name rather than sitting beside it, because two cards
        // with one name is a question nobody can answer at scoring time.
        Scorecard card = scorecardRepository
                .findByFacilityIdAndName(facilityId, proposed.name())
                .orElseGet(Scorecard::new);

        card.setFacilityId(facilityId);
        card.setName(proposed.name());
        card.setHolesCount(proposed.holes().size());
        card.setParTotal(proposed.holes().stream()
                .mapToInt(ScorecardSubmissionRequest.HoleLine::par).sum());
        String publisher = correction.getMetadata().getPublisher();
        card.setPublisher(publisher == null ? "review" : publisher);
        card.setSource(correction.getMetadata().getSource());
        card.setAccuracyClass("D_UNVERIFIED_COMMUNITY");
        card.setVerificationStatus("VERIFIED");
        card.getSegments().clear();
        card.getHoles().clear();
        card.getTees().clear();

        Scorecard saved = scorecardRepository.saveAndFlush(card);

        List<ScorecardSegment> segments = new ArrayList<>();
        int position = 1;
        for (Long courseId : proposed.segmentCourseIds()) {
            segments.add(new ScorecardSegment(saved, position++, courseId));
        }
        saved.getSegments().addAll(segments);

        for (ScorecardSubmissionRequest.HoleLine line : proposed.holes()) {
            saved.getHoles().add(
                    new ScorecardHole(saved, line.hole(), line.par(), line.strokeIndex()));
        }

        int yardagesWritten = applyTees(saved, proposed);

        scorecardRepository.save(saved);
        log.info("Scorecard '{}' published for facility {} from correction {} — {} tee(s), {} yardage(s)",
                saved.getName(), facilityId, correction.getId(),
                saved.getTees().size(), yardagesWritten);
    }

    /**
     * The tee rows of an approved card, written as rows rather than kept in
     * the correction's JSON.
     *
     * <p>Until this ran, an approved card published its pars and its stroke
     * indexes and dropped the rest of the photograph on the floor: the
     * yardages and the course and slope ratings stayed in the correction
     * payload, where nothing that scores a round can reach them. They are the
     * numbers that make a score comparable at all — the same 82 is a different
     * round off 7,311 yards than off 5,631 — so they belong beside the pars.
     *
     * <p>A card need not carry them. Photographs get taken with the rating
     * table outside the frame, and a card with no tee rows is still worth
     * publishing for its pars, so an empty list here is silence rather than an
     * error.
     *
     * @return how many yardages were written, for the log
     */
    private int applyTees(Scorecard card, ScorecardSubmissionRequest proposed) {
        if (proposed.tees() == null || proposed.tees().isEmpty()) {
            return 0;
        }

        // A card names each tee once, and the table says so. Two rows called
        // GOLD is one column read twice, and keeping both would put two
        // ratings on one tee with nothing to choose between them.
        var seenNames = new HashSet<String>();
        var pairs = new ArrayList<Map.Entry<ScorecardTee, ScorecardSubmissionRequest.TeeLine>>();
        for (ScorecardSubmissionRequest.TeeLine line : proposed.tees()) {
            String name = line.name() == null ? "" : line.name().trim();
            if (name.isEmpty() || !seenNames.add(name.toUpperCase(Locale.ROOT))) {
                continue;
            }
            var tee = new ScorecardTee(card, name, line.courseRating(), line.slopeRating());
            card.getTees().add(tee);
            pairs.add(Map.entry(tee, line));
        }
        if (pairs.isEmpty()) {
            return 0;
        }

        // The yardage's key is the tee's id, so the tees have to exist before
        // their yardages can name them.
        scorecardRepository.saveAndFlush(card);

        int written = 0;
        for (var pair : pairs) {
            ScorecardTee tee = pair.getKey();
            List<ScorecardSubmissionRequest.Yardage> yardages = pair.getValue().yardages();
            if (yardages == null) {
                continue;
            }
            var seenHoles = new HashSet<Integer>();
            for (ScorecardSubmissionRequest.Yardage yardage : yardages) {
                if (!seenHoles.add(yardage.hole())) {
                    continue;
                }
                tee.getYardages().add(
                        new ScorecardTeeYardage(tee, yardage.hole(), yardage.yards()));
                written++;
            }
        }

        // Saved through the tee rather than left to cascade a second level
        // from the card. Cascading is what this did first, and the yardages
        // did not arrive: the log said "2 tee(s), 36 yardage(s)" and
        // `scorecard_tee_yardages` was empty, because they were added to a
        // collection after the card had already been flushed and nothing
        // carried them to an insert. One save, one cascade — the same single
        // step that has always worked for the holes.
        scorecardTeeRepository.saveAllAndFlush(
                pairs.stream().map(Map.Entry::getKey).toList());
        return written;
    }

    private String writeJson(ScorecardSubmissionRequest request) {
        try {
            return objectMapper.writeValueAsString(request);
        } catch (Exception e) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "holes",
                    Map.of("holes", "could not be read"));
        }
    }

    private ScorecardSubmissionRequest readJson(String json) {
        try {
            return objectMapper.readValue(json, new TypeReference<ScorecardSubmissionRequest>() {});
        } catch (Exception e) {
            throw new VspApiException(VspErrorCode.CORRECTION_001,
                    "the stored scorecard cannot be read: " + e.getMessage());
        }
    }
}
