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
        // Loaded before they are cleared, and that is not a formality.
        // Hibernate does not remove orphans from a lazy collection nothing
        // ever loaded: clear() on an uninitialised one is recorded as
        // "recreate this collection" and the existing rows are left where they
        // are. The reprint then dies on the very constraint it was replacing —
        // observed on production as "Key (scorecard_id, name)=(3, GOLD)
        // already exists" when republishing a card under its own name. Reading
        // the size loads them, which is what makes clear() mean delete.
        card.getSegments().size();
        card.getHoles().size();
        card.getTees().size();

        card.getSegments().clear();
        card.getHoles().clear();
        card.getTees().clear();
        scorecardRepository.flush();

        Scorecard saved = scorecardRepository.saveAndFlush(card);

        List<ScorecardSegment> segments = new ArrayList<>();
        int position = 1;
        for (Long courseId : proposed.segmentCourseIds()) {
            segments.add(new ScorecardSegment(saved, position++, courseId));
        }
        saved.getSegments().addAll(segments);

        for (ScorecardSubmissionRequest.HoleLine line : proposed.holes()) {
            ScorecardHole hole =
                    new ScorecardHole(saved, line.hole(), line.par(), line.strokeIndex());
            // The second index row, where the card prints one. Set rather than
            // passed to the constructor so cards submitted before this existed
            // keep working: they carry null, which is "the card printed one
            // row" and not "women play this hole unranked".
            hole.setStrokeIndexLadies(line.strokeIndexLadies());
            saved.getHoles().add(hole);
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
    /**
     * Whose rating a submitted tee row carries.
     *
     * <p>Anything unrecognised is UNSPECIFIED rather than a rejection: a card
     * whose rating table says something this does not know about is still
     * worth publishing for its yardages, and an unlabelled rating read as the
     * men's would be a guess that looks like data — a woman playing off it
     * would get a differential computed against the wrong number, with nothing
     * on the screen to show where it came from.
     */
    private ScorecardTee.Gender genderOf(String submitted) {
        if (submitted == null || submitted.isBlank()) {
            return ScorecardTee.Gender.UNSPECIFIED;
        }
        try {
            return ScorecardTee.Gender.valueOf(submitted.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            return ScorecardTee.Gender.UNSPECIFIED;
        }
    }

    private int applyTees(Scorecard card, ScorecardSubmissionRequest proposed) {
        if (proposed.tees() == null || proposed.tees().isEmpty()) {
            return 0;
        }

        // A card names each tee once per gender, and the table says so. Two
        // rows called GOLD for the same gender is one column read twice, and
        // keeping both would put two ratings on one tee with nothing to choose
        // between them. Two called RED, one men's and one ladies', is what a
        // rated card looks like — keying this on the name alone dropped the
        // second, silently, along with the ratings that were the point of it.
        var seenRows = new HashSet<String>();
        int written = 0;

        // What the reviewer approved and what got written can differ, and until
        // now it differed in silence. The portal shows them every tee row on
        // the card before they click approve, so a row that then vanishes is a
        // discrepancy someone will eventually ask about — and "GOLD appeared
        // twice on the photograph" has to be answerable from the log rather
        // than by re-reading the original image.
        var dropped = new ArrayList<String>();

        for (ScorecardSubmissionRequest.TeeLine line : proposed.tees()) {
            String name = line.name() == null ? "" : line.name().trim();
            if (name.isEmpty()) {
                dropped.add("a tee row with no name");
                continue;
            }
            ScorecardTee.Gender gender = genderOf(line.gender());
            if (!seenRows.add(name.toUpperCase(Locale.ROOT) + "/" + gender)) {
                dropped.add("a second tee row named '" + name + "' ("
                        + gender.name().toLowerCase(Locale.ROOT) + ")");
                continue;
            }

            // Saved one at a time, and the *returned* instance is the one used
            // from here on. Adding a new tee to the card's collection and
            // saving the card instead goes through merge, and merge does not
            // attach what it is given: it copies the state into fresh managed
            // instances, inserts those, and leaves the originals transient
            // with null ids. That is why the yardages went missing — they were
            // keyed on a tee id that did not exist yet and hung off an object
            // the persistence context had never heard of — and why saving
            // those originals afterwards inserted every tee a second time.
            ScorecardTee tee = scorecardTeeRepository.saveAndFlush(
                    new ScorecardTee(card, name, line.courseRating(), line.slopeRating(), gender));

            List<ScorecardSubmissionRequest.Yardage> yardages = line.yardages();
            if (yardages != null) {
                var seenHoles = new HashSet<Integer>();
                for (ScorecardSubmissionRequest.Yardage yardage : yardages) {
                    if (!seenHoles.add(yardage.hole())) {
                        dropped.add("a second yardage for hole " + yardage.hole()
                                + " on tee '" + name + "'");
                        continue;
                    }
                    // The tee is managed and its yardages cascade, so reaching
                    // them from it is enough: they are inserted at the flush
                    // below, the same way the card's holes are.
                    tee.getYardages().add(
                            new ScorecardTeeYardage(tee, yardage.hole(), yardage.yards()));
                    written++;
                }
            }

            card.getTees().add(tee);
        }

        scorecardTeeRepository.flush();

        if (!dropped.isEmpty()) {
            log.warn("Card '{}' (scorecard {}, facility {}) published without {} of what was approved: {}."
                            + " Where a name or hole repeats, the first reading was kept; a row the"
                            + " photograph gave no name to cannot be written at all.",
                    card.getName(), card.getId(), card.getFacilityId(), dropped.size(),
                    String.join(", ", dropped));
        }

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
