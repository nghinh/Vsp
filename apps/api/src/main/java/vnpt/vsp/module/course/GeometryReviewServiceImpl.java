package vnpt.vsp.module.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.dto.CorrectParRequest;
import vnpt.vsp.module.course.dto.CorrectParResponse;
import vnpt.vsp.module.course.dto.GeometryReviewSummary;
import vnpt.vsp.module.course.dto.VerifyGeometryRequest;
import vnpt.vsp.module.course.dto.VerifyGeometryResponse;
import vnpt.vsp.module.course.entity.AccuracyClass;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.entity.VerificationStatus;
import vnpt.vsp.module.course.repository.BunkerRepository;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.GreenRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.course.repository.TeeBoxRepository;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/** Default {@link GeometryReviewService}. */
@Service
public class GeometryReviewServiceImpl implements GeometryReviewService {

    private static final Logger log = LoggerFactory.getLogger(GeometryReviewServiceImpl.class);

    /// Confidence recorded once a person has confirmed the coordinates.
    ///
    /// The OSM import writes 60; a human check is worth more than that and less
    /// than a survey. It stays inside class C: verifying digitised geometry does
    /// not turn it into an RTK survey, and the class is a claim about method.
    private static final java.math.BigDecimal VERIFIED_CONFIDENCE =
            new java.math.BigDecimal("85.00");

    private final CourseRepository courseRepository;
    private final HoleRepository holeRepository;
    private final GreenRepository greenRepository;
    private final BunkerRepository bunkerRepository;
    private final TeeBoxRepository teeBoxRepository;
    private final AuditService auditService;

    public GeometryReviewServiceImpl(
            CourseRepository courseRepository,
            HoleRepository holeRepository,
            GreenRepository greenRepository,
            BunkerRepository bunkerRepository,
            TeeBoxRepository teeBoxRepository,
            AuditService auditService) {
        this.courseRepository = courseRepository;
        this.holeRepository = holeRepository;
        this.greenRepository = greenRepository;
        this.bunkerRepository = bunkerRepository;
        this.teeBoxRepository = teeBoxRepository;
        this.auditService = auditService;
    }

    @Override
    @Transactional(readOnly = true)
    public GeometryReviewSummary getReviewSummary(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001, "courseId"));

        List<Hole> holes = holeRepository.findByCourseIdOrderByHoleNumber(courseId);
        List<GeometryReviewSummary.HoleReviewItem> items = new ArrayList<>();
        int pending = 0;
        int verified = 0;
        int unverified = 0;

        for (Hole hole : holes) {
            DataQualityMetadata quality = hole.getDataQuality();
            VerificationStatus status = quality != null ? quality.getVerificationStatus() : null;
            boolean hasCoordinates = hole.getTeeingGroundLocation() != null
                    && hole.getGreenLocation() != null;

            if (status == VerificationStatus.VERIFIED) {
                verified++;
            } else if (status == VerificationStatus.PENDING_REVIEW) {
                pending++;
            } else {
                unverified++;
            }

            items.add(new GeometryReviewSummary.HoleReviewItem(
                    hole.getHoleNumber(),
                    hole.getPar(),
                    hole.getPlayingLengthMeters() != null
                            ? hole.getPlayingLengthMeters().doubleValue() : null,
                    quality != null ? quality.getSource() : null,
                    quality != null && quality.getAccuracyClass() != null
                            ? quality.getAccuracyClass().name() : null,
                    status != null ? status.name() : null,
                    hasCoordinates,
                    greenRepository.findByHoleId(hole.getId()).size(),
                    bunkerRepository.findByHoleId(hole.getId()).size(),
                    teeBoxRepository.findByHoleId(hole.getId()).size(),
                    isReviewable(hole),
                    ParPlausibility.isPlausible(
                            hole.getPar(), hole.getPlayingLengthMeters()),
                    ParPlausibility.suggestionFor(
                            hole.getPar(), hole.getPlayingLengthMeters())
                            .orElse(null)));
        }

        int holeParTotal = holes.stream()
                .map(Hole::getPar)
                .filter(java.util.Objects::nonNull)
                .mapToInt(Integer::intValue)
                .sum();

        return new GeometryReviewSummary(
                courseId, course.getName(), items, pending, verified, unverified,
                holeParTotal, course.getParTotal());
    }

    @Override
    @Transactional
    public CorrectParResponse correctPar(
            Long courseId, CorrectParRequest request, String reviewer) {

        courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001, "courseId"));

        List<Integer> changed = new ArrayList<>();
        List<Integer> unchanged = new ArrayList<>();
        List<Integer> unknown = new ArrayList<>();
        List<Integer> stillImplausible = new ArrayList<>();
        Instant now = Instant.now();

        for (CorrectParRequest.HolePar entry : request.holes()) {
            Hole hole = holeRepository
                    .findByCourseIdAndHoleNumber(courseId, entry.holeNumber())
                    .orElse(null);

            if (hole == null) {
                // Reported rather than ignored: a reviewer typing eighteen rows
                // needs to know which one landed nowhere.
                unknown.add(entry.holeNumber());
                continue;
            }

            if (entry.par().equals(hole.getPar())) {
                unchanged.add(entry.holeNumber());
                continue;
            }

            // Par is a scorecard fact and this is a person reading the card, so
            // the hole's own provenance is untouched: correcting par says
            // nothing about whether the coordinates were checked.
            hole.setPar(entry.par());
            holeRepository.save(hole);
            changed.add(entry.holeNumber());

            if (!ParPlausibility.isPlausible(entry.par(), hole.getPlayingLengthMeters())) {
                // Applied anyway, and flagged. A scorecard that disagrees with
                // a measured length means one of the two is wrong, and neither
                // this service nor the reviewer can tell which from here.
                stillImplausible.add(entry.holeNumber());
            }
        }

        log.info("Par correction on course {} by {}: {} changed, {} unchanged, {} unknown",
                courseId, reviewer, changed.size(), unchanged.size(), unknown.size());

        auditService.log(
                AuditAction.HOLE_PAR_CORRECTED,
                "Course",
                String.valueOf(courseId),
                null,
                null,
                String.format(
                        "{\"reviewer\":\"%s\",\"changed\":%s,\"stillImplausible\":%s,\"note\":\"%s\"}",
                        reviewer, changed, stillImplausible,
                        request.note().replace("\"", "'")));

        return new CorrectParResponse(
                changed, unchanged, unknown, stillImplausible, now, reviewer);
    }

    @Override
    @Transactional
    public VerifyGeometryResponse verify(
            Long courseId, VerifyGeometryRequest request, String reviewer) {

        courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001, "courseId"));

        List<Integer> verified = new ArrayList<>();
        List<Integer> refused = new ArrayList<>();
        Instant now = Instant.now();

        for (Integer holeNumber : request.holeNumbers()) {
            Hole hole = holeRepository
                    .findByCourseIdAndHoleNumber(courseId, holeNumber)
                    .orElse(null);

            if (hole == null || !isReviewable(hole)) {
                // A hole whose coordinates the seed generated has nothing for a
                // reviewer to have looked at. Marking it verified would be the
                // exact claim this gate exists to stop, so it is refused and
                // reported rather than quietly skipped.
                refused.add(holeNumber);
                continue;
            }

            markVerified(hole.getDataQuality(), now);
            holeRepository.save(hole);

            // The shapes hang off the hole and were imported in the same pass,
            // so confirming the hole's coordinates confirms them too — a green
            // is positioned relative to the hole it belongs to.
            greenRepository.saveAll(greenRepository.findByHoleId(hole.getId()).stream()
                    .peek(g -> markVerified(g.getMetadata(), now)).toList());
            bunkerRepository.saveAll(bunkerRepository.findByHoleId(hole.getId()).stream()
                    .peek(b -> markVerified(b.getMetadata(), now)).toList());
            teeBoxRepository.saveAll(teeBoxRepository.findByHoleId(hole.getId()).stream()
                    .peek(t -> markVerified(t.getMetadata(), now)).toList());

            verified.add(holeNumber);
        }

        log.info("Geometry review on course {} by {}: {} verified, {} refused",
                courseId, reviewer, verified.size(), refused.size());

        auditService.log(
                AuditAction.GEOMETRY_VERIFIED,
                "Course",
                String.valueOf(courseId),
                null,
                null,
                String.format(
                        "{\"reviewer\":\"%s\",\"verified\":%s,\"refused\":%s,\"note\":\"%s\"}",
                        reviewer, verified, refused, request.note().replace("\"", "'")));

        return new VerifyGeometryResponse(verified, refused, now, reviewer);
    }

    /// True when there is something here a person could actually have checked.
    ///
    /// Two conditions, and both matter. The hole needs coordinates at all, and
    /// they need to have come from somewhere — a seeded hole carries a tee that
    /// is the clubhouse pin walked along a fixed diagonal, and no amount of
    /// looking at it makes it right.
    private boolean isReviewable(Hole hole) {
        if (hole.getTeeingGroundLocation() == null || hole.getGreenLocation() == null) {
            return false;
        }
        DataQualityMetadata quality = hole.getDataQuality();
        if (quality == null) {
            return false;
        }
        String source = quality.getSource();
        return source != null && !source.isBlank() && !"SEED".equalsIgnoreCase(source);
    }

    private void markVerified(DataQualityMetadata quality, Instant now) {
        if (quality == null) {
            return;
        }
        quality.setVerificationStatus(VerificationStatus.VERIFIED);
        // D → C, and only that step.
        //
        // The first cut of this left the class alone, on the reasoning that a
        // person looking at geometry has not surveyed it. That is right about
        // class A and it made verification completely inert: the app's gate
        // reads `verified && class != D`, so eighteen confirmed holes stayed
        // invisible to it and the whole review flow did nothing.
        //
        // PRD §9.4 defines class C as "verified satellite digitisation" —
        // which is exactly what digitised geometry a reviewer has confirmed is.
        // Promoting past C would be the overclaim; stopping at it is the
        // definition. B and A are claims about licensing and survey equipment
        // and no amount of looking earns them, so anything already better than
        // D is left where it is.
        if (quality.getAccuracyClass() == AccuracyClass.D_UNVERIFIED_COMMUNITY) {
            quality.setAccuracyClass(AccuracyClass.C_VERIFIED_SATELLITE);
        }
        quality.setLastVerifiedAt(now);
        quality.setConfidence(VERIFIED_CONFIDENCE);
        quality.setUpdatedAt(now);
    }
}
