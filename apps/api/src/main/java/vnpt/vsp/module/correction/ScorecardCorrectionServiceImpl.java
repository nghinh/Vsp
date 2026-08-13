package vnpt.vsp.module.correction;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
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
import vnpt.vsp.module.identity.entity.GolferAccount;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class ScorecardCorrectionServiceImpl implements ScorecardCorrectionService {

    private static final Logger log = LoggerFactory.getLogger(ScorecardCorrectionServiceImpl.class);

    private final CourseCorrectionRepository correctionRepository;
    private final ScorecardRepository scorecardRepository;
    private final ScorecardTeeRepository scorecardTeeRepository;
    private final CourseRepository courseRepository;
    private final ScorecardPhotoStore photoStore;
    private final GolferAccountRepository golferAccountRepository;
    private final ObjectMapper objectMapper;

    /// Reporters whose cards publish on submission, by email, lower-cased.
    private final Set<String> trustedReporters;

    public ScorecardCorrectionServiceImpl(
            CourseCorrectionRepository correctionRepository,
            ScorecardRepository scorecardRepository,
            ScorecardTeeRepository scorecardTeeRepository,
            CourseRepository courseRepository,
            ScorecardPhotoStore photoStore,
            GolferAccountRepository golferAccountRepository,
            @Value("${vsp.corrections.trusted-reporters:}") String trustedReporters,
            ObjectMapper objectMapper) {
        this.correctionRepository = correctionRepository;
        this.scorecardRepository = scorecardRepository;
        this.scorecardTeeRepository = scorecardTeeRepository;
        this.courseRepository = courseRepository;
        this.photoStore = photoStore;
        this.golferAccountRepository = golferAccountRepository;
        this.objectMapper = objectMapper;
        this.trustedReporters = Arrays.stream(
                        (trustedReporters == null ? "" : trustedReporters).split(","))
                .map(entry -> entry.trim().toLowerCase(Locale.ROOT))
                .filter(entry -> !entry.isEmpty())
                .collect(Collectors.toUnmodifiableSet());

        if (!this.trustedReporters.isEmpty()) {
            // Said out loud at startup. A deployment that publishes some
            // golfers' cards without review should never be a surprise to
            // whoever is reading the log.
            log.info("Scorecards from {} reporter(s) will publish without review: {}",
                    this.trustedReporters.size(), this.trustedReporters);
        }
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
        correction.setReporterEvidenceUrl(evidenceFor(courseId, reporterId, request));
        correction.getMetadata().setPublisher("golfer:" + reporterId);
        correction.getMetadata().setSource("golfer-submitted-scorecard");
        correction.setProposedScorecard(writeJson(request));

        CourseCorrection saved = correctionRepository.save(correction);
        log.info("Scorecard submitted for course {} by {} — {} holes, correction {}",
                courseId, reporterId, request.holes().size(), saved.getId());

        if (isTrusted(reporterId)) {
            applyIfScorecard(saved);
            saved.approve("Published on submission: the reporter is a trusted operator.",
                    reporterId, "Auto-approved — reporter is on vsp.corrections.trusted-reporters.");
            saved = correctionRepository.save(saved);
            log.info("Correction {} published without review: {} is a trusted reporter",
                    saved.getId(), reporterId);
        }
        return saved;
    }

    /**
     * Whether this reporter's cards publish on submission.
     *
     * <p>The review step exists because a misread stroke index misallocates
     * strokes for everyone who plays that card afterwards, and a golfer typing
     * at the first tee is the step where numbers go wrong. That reasoning does
     * not apply to the operator loading the country's cards from photographs:
     * they are the reviewer, and sending their own work to their own queue is a
     * round trip that checks nothing.
     *
     * <p>Named by email and configured per deployment, so the list is visible
     * in the environment rather than compiled in, and an empty list — the
     * default — means every card is reviewed exactly as before. Nothing else is
     * relaxed: every check in {@link #validate} still runs, the correction row
     * is still written, and it still records who approved it and why, so the
     * audit trail reads the same as a card an admin clicked through.
     */
    private boolean isTrusted(Long reporterId) {
        if (trustedReporters.isEmpty() || reporterId == null) {
            return false;
        }
        return golferAccountRepository.findById(reporterId)
                .map(GolferAccount::getEmail)
                .filter(email -> email != null && !email.isBlank())
                .map(email -> trustedReporters.contains(email.trim().toLowerCase(Locale.ROOT)))
                .orElse(false);
    }

    /**
     * Refuses a card that carries another course's pars and stroke indexes.
     *
     * <p>No two real courses agree on all thirty-six of those numbers. Twelve
     * of the tables supplied for this project agreed on every one, because they
     * came off one template, and nine were published before anyone compared
     * them to each other. Every other check passed all twelve: a generated
     * table computes its totals from the numbers it invented, so it agrees with
     * itself perfectly. This is the only question here asked about the world
     * rather than about the card.
     *
     * <p>A card with no stroke index row is not judged on this. Par alone is
     * far too weak — real courses share par sequences, and Kings Island's
     * photographed card and Sky Lake's do — so a card that prints no index row
     * would be condemned for a coincidence.
     *
     * <p>The card being rewritten is excluded, so a club reprinting its own
     * card under its own name does not collide with the copy it replaces.
     */
    private void refuseIfAnotherCourseAlreadyCarriesThisCard(
            Long cardBeingWritten, ScorecardSubmissionRequest proposed) {

        List<ScorecardSubmissionRequest.HoleLine> holes = proposed.holes().stream()
                .sorted(java.util.Comparator.comparingInt(ScorecardSubmissionRequest.HoleLine::hole))
                .toList();
        if (holes.stream().anyMatch(line -> line.strokeIndex() == null)) {
            return;
        }

        String pars = holes.stream()
                .map(line -> String.valueOf(line.par()))
                .collect(Collectors.joining(","));
        String indexes = holes.stream()
                .map(line -> String.valueOf(line.strokeIndex()))
                .collect(Collectors.joining(","));

        // -1 is never written here — every hole has an index by the check
        // above — but it is what the query coalesces a null to, so the two
        // sides are built the same way.
        List<Long> clashes = scorecardRepository.findIdsWithSameParAndStrokeIndex(
                cardBeingWritten == null ? -1L : cardBeingWritten, pars, indexes);
        if (clashes.isEmpty()) {
            return;
        }

        String named = clashes.stream()
                .map(id -> scorecardRepository.findById(id).map(Scorecard::getName).orElse("#" + id))
                .collect(Collectors.joining(", "));
        log.warn("Refused a card carrying the same {} pars and stroke indexes as {}",
                holes.size(), named);
        throw VspApiException.forField(VspErrorCode.VALIDATION_001, "holes",
                Map.of("holes", "this card has the same " + holes.size() + " pars AND the same "
                        + holes.size() + " stroke indexes as " + named
                        + ". Two real courses do not agree on all " + (2 * holes.size())
                        + " of those numbers — check the card is the right club's."));
    }

    /**
     * The photograph this card should be reviewed against.
     *
     * <p>What the app sent, when it sent anything. An app that reads
     * {@code photoUrl} back off the card reader puts it here itself, and so
     * does a golfer who typed a URL of their own into the evidence box.
     *
     * <p>Otherwise, the photograph this golfer just had read for this course.
     * Every app already on a phone predates {@code photoUrl} and sends nothing,
     * and a card approved with no image behind it cannot be checked afterwards
     * — which is how nine fabricated cards were published. This closes that
     * without waiting for a release to reach every handset.
     */
    private String evidenceFor(Long courseId, Long reporterId, ScorecardSubmissionRequest request) {
        String submitted = request.evidenceUrl();
        if (submitted != null && !submitted.isBlank()) {
            return submitted;
        }
        String remembered = photoStore.recall(reporterId, courseId);
        if (remembered != null) {
            log.info("Card for course {} arrived with no evidence; attached the photograph"
                    + " golfer {} had read for it", courseId, reporterId);
        }
        return remembered;
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

        int declared = 0;
        boolean everySegmentKnowsItsSize = true;
        for (Long segmentCourseId : request.segmentCourseIds()) {
            Course segment = courseRepository.findById(segmentCourseId)
                    .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
            if (!segment.getFacility().getId().equals(course.getFacility().getId())) {
                throw VspApiException.forField(VspErrorCode.VALIDATION_001, "segmentCourseIds",
                        Map.of("segmentCourseIds", "đường " + segmentCourseId + " belongs to another club"));
            }
            Integer size = segment.getHolesCount();
            if (size == null || size <= 0) {
                everySegmentKnowsItsSize = false;
            } else {
                declared += size;
            }
        }

        // The đường this card covers have to add up to the card. Two segments
        // are for a card printed across two nines — "A + B" — and nothing said
        // so: Kings Island's photographed card is attached to the eighteen-hole
        // Championship course AND to the eighteen-hole Kings Course, so an
        // eighteen-hole card claims to span thirty-six holes, and its pars
        // match neither. Only judged where every segment knows its own size.
        if (everySegmentKnowsItsSize && declared != numbers.size()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "segmentCourseIds",
                    Map.of("segmentCourseIds", "this card has " + numbers.size()
                            + " holes but the đường chosen add up to " + declared
                            + " — pick the đường this card was printed for"));
        }

        checkAgainstPrintedTotals(request);
    }

    /**
     * The card against the sums the club printed beside it.
     *
     * <p>Everything else here tests the card against itself. These are the one
     * independent fact a photograph carries: eighteen holes over five tees is
     * ninety numbers, and a row that adds up to the OUT, IN and TOTAL printed
     * next to it was not misread. It is the check the offline loader has had
     * since nine fabricated cards got published, and the live path — the one
     * actual golfers use — had nothing of the kind.
     *
     * <p>It refuses rather than warns. A row that misses its own printed total
     * has a digit wrong in it and the card does not say which, so there is
     * nothing to publish; and the golfer is holding the card, which is the one
     * moment the wrong cell can still be found. Now that a trusted reporter's
     * cards publish on submission there is also no reviewer downstream who
     * would otherwise have caught it.
     *
     * <p>Only what was sent is judged. A card that prints no totals, or a
     * photograph that cut them off, is still a card worth having.
     */
    private void checkAgainstPrintedTotals(ScorecardSubmissionRequest request) {
        int holes = request.holes().size();

        int parOut = request.holes().stream()
                .filter(line -> line.hole() <= 9)
                .mapToInt(ScorecardSubmissionRequest.HoleLine::par).sum();
        int parIn = request.holes().stream()
                .filter(line -> line.hole() > 9)
                .mapToInt(ScorecardSubmissionRequest.HoleLine::par).sum();

        requireAgrees("par", "OUT", request.parOut(), parOut);
        requireAgrees("par", "IN", request.parIn(), parIn);
        requireAgrees("par", "TOTAL", request.parTotal(), parOut + parIn);

        if (request.tees() == null) {
            return;
        }
        for (ScorecardSubmissionRequest.TeeLine tee : request.tees()) {
            if (tee.yardages() == null || tee.yardages().isEmpty()) {
                continue;
            }
            // A nine that is only half photographed sums to less than its
            // printed OUT without a single digit being wrong, so a row that
            // does not carry every hole is not judged against the club's sums.
            if (tee.yardages().size() != holes) {
                continue;
            }
            int out = tee.yardages().stream()
                    .filter(y -> y.hole() <= 9)
                    .mapToInt(ScorecardSubmissionRequest.Yardage::yards).sum();
            int in = tee.yardages().stream()
                    .filter(y -> y.hole() > 9)
                    .mapToInt(ScorecardSubmissionRequest.Yardage::yards).sum();

            String name = tee.name() == null ? "this tee" : tee.name();
            requireAgrees(name, "OUT", tee.yardsOut(), out);
            requireAgrees(name, "IN", tee.yardsIn(), in);
            requireAgrees(name, "TOTAL", tee.yardsTotal(), out + in);
        }
    }

    private void requireAgrees(String row, String column, Integer printed, int read) {
        if (printed == null || printed == read) {
            return;
        }
        throw VspApiException.forField(VspErrorCode.VALIDATION_001, "holes",
                Map.of("holes", row + " adds up to " + read + " but the card prints "
                        + printed + " in its " + column + " column — one number in that"
                        + " row is wrong, and the card does not say which"));
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

        refuseIfAnotherCourseAlreadyCarriesThisCard(card.getId(), proposed);

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
