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
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.ScorecardRepository;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class ScorecardCorrectionServiceImpl implements ScorecardCorrectionService {

    private static final Logger log = LoggerFactory.getLogger(ScorecardCorrectionServiceImpl.class);

    private final CourseCorrectionRepository correctionRepository;
    private final ScorecardRepository scorecardRepository;
    private final CourseRepository courseRepository;
    private final ObjectMapper objectMapper;

    public ScorecardCorrectionServiceImpl(
            CourseCorrectionRepository correctionRepository,
            ScorecardRepository scorecardRepository,
            CourseRepository courseRepository,
            ObjectMapper objectMapper) {
        this.correctionRepository = correctionRepository;
        this.scorecardRepository = scorecardRepository;
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

        scorecardRepository.save(saved);
        log.info("Scorecard '{}' published for facility {} from correction {}",
                saved.getName(), facilityId, correction.getId());
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
