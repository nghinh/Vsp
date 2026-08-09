package vnpt.vsp.module.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.dto.CorrectParRequest;
import vnpt.vsp.module.course.dto.CorrectParResponse;
import vnpt.vsp.module.course.dto.VerifyGeometryRequest;
import vnpt.vsp.module.course.dto.VerifyGeometryResponse;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Tests for the gate between imported geometry and geometry the app will draw.
 *
 * <p>Four courses now carry 18/18 holes of real OSM coordinates, and the mobile
 * app treats every one of them exactly like the 831 holes a seed script
 * invented — because both are PENDING_REVIEW and the provenance gate only
 * trusts VERIFIED. This service is how a hole crosses that line.</p>
 *
 * <p>Which makes the refusal path the important one. A seeded hole carries a
 * tee that is the clubhouse pin walked along a fixed 0.0008°/0.0006° diagonal
 * with the green placed due north of it; there is nothing there a reviewer
 * could have looked at, and marking it verified would put a fabricated distance
 * in front of a golfer under a badge that says the opposite. If this service
 * can be talked into verifying one of those, every honest label added to this
 * codebase is worth nothing.</p>
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GeometryReviewServiceImplTest {

    @Mock private CourseRepository courseRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private GreenRepository greenRepository;
    @Mock private BunkerRepository bunkerRepository;
    @Mock private TeeBoxRepository teeBoxRepository;
    @Mock private AuditService auditService;

    private GeometryReviewServiceImpl service;

    private static final Long COURSE_ID = 7L;

    @BeforeEach
    void setUp() {
        service = new GeometryReviewServiceImpl(
                courseRepository, holeRepository, greenRepository,
                bunkerRepository, teeBoxRepository, auditService);

        Course course = new Course();
        course.setId(COURSE_ID);
        course.setName("Long Thành — Championship");
        course.setParTotal(72);
        when(courseRepository.findById(COURSE_ID)).thenReturn(Optional.of(course));

        when(greenRepository.findByHoleId(any())).thenReturn(List.of());
        when(bunkerRepository.findByHoleId(any())).thenReturn(List.of());
        when(teeBoxRepository.findByHoleId(any())).thenReturn(List.of());
        when(greenRepository.saveAll(any())).thenReturn(List.of());
        when(bunkerRepository.saveAll(any())).thenReturn(List.of());
        when(teeBoxRepository.saveAll(any())).thenReturn(List.of());
    }

    // ─── Harness ───────────────────────────────────────────────────────────

    private Hole hole(int number, String source, boolean withCoordinates) {
        Hole hole = new Hole();
        hole.setId((long) number);
        hole.setHoleNumber(number);
        hole.setPar(4);
        if (withCoordinates) {
            hole.setTeeingGroundLocation("POINT(106.7 10.7)");
            hole.setGreenLocation("POINT(106.702 10.703)");
        }
        DataQualityMetadata quality = new DataQualityMetadata();
        quality.setSource(source);
        quality.setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
        quality.setVerificationStatus(VerificationStatus.PENDING_REVIEW);
        hole.setMetadata(quality);
        when(holeRepository.findByCourseIdAndHoleNumber(COURSE_ID, number))
                .thenReturn(Optional.of(hole));
        return hole;
    }

    private VerifyGeometryRequest request(Integer... holes) {
        return new VerifyGeometryRequest(List.of(holes), "Checked against satellite imagery");
    }

    // ─── The refusal that matters ──────────────────────────────────────────

    @Test
    void aSeededHoleCannotBeVerified() {
        Hole seeded = hole(3, "SEED", true);

        VerifyGeometryResponse response = service.verify(COURSE_ID, request(3), "admin@vsp");

        assertThat(response.refusedHoleNumbers()).containsExactly(3);
        assertThat(response.verifiedHoleNumbers()).isEmpty();
        // Still what it was. The reviewer looked at coordinates the seed
        // generated, and looking harder does not make them real.
        assertThat(seeded.getDataQuality().getVerificationStatus())
                .isEqualTo(VerificationStatus.PENDING_REVIEW);
        verify(holeRepository, never()).save(any());
    }

    @Test
    void aHoleWithNoCoordinatesCannotBeVerified() {
        hole(4, "osm:way/1017320363", false);

        VerifyGeometryResponse response = service.verify(COURSE_ID, request(4), "admin@vsp");

        assertThat(response.refusedHoleNumbers()).containsExactly(4);
    }

    @Test
    void aRefusalIsReportedRatherThanSilentlySkipped() {
        hole(1, "osm:way/1", true);
        hole(2, "SEED", true);

        VerifyGeometryResponse response = service.verify(COURSE_ID, request(1, 2), "admin@vsp");

        // A reviewer who ticked eighteen boxes and got sixteen holes needs to
        // be told which two, not left to compare counts.
        assertThat(response.verifiedHoleNumbers()).containsExactly(1);
        assertThat(response.refusedHoleNumbers()).containsExactly(2);
    }

    // ─── The happy path ────────────────────────────────────────────────────

    @Test
    void anImportedHoleIsVerifiedWithAConfidenceAndATimestamp() {
        Hole imported = hole(7, "osm:way/1017320363", true);

        VerifyGeometryResponse response = service.verify(COURSE_ID, request(7), "admin@vsp");

        assertThat(response.verifiedHoleNumbers()).containsExactly(7);
        DataQualityMetadata quality = imported.getDataQuality();
        assertThat(quality.getVerificationStatus()).isEqualTo(VerificationStatus.VERIFIED);
        assertThat(quality.getLastVerifiedAt()).isNotNull();
        assertThat(quality.getConfidence().doubleValue()).isGreaterThan(60.0);
    }

    @Test
    void verifyingPromotesUnverifiedCommunityDataToVerifiedSatellite() {
        Hole imported = hole(7, "osm:way/1", true);

        service.verify(COURSE_ID, request(7), "admin@vsp");

        // PRD §9.4 defines class C as "verified satellite digitisation", which
        // is exactly what this is. Leaving it at D made verification inert —
        // the app's gate reads `verified && class != D`, so a confirmed hole
        // stayed invisible to the very thing confirming it was for.
        assertThat(imported.getDataQuality().getAccuracyClass())
                .isEqualTo(AccuracyClass.C_VERIFIED_SATELLITE);
    }

    @Test
    void verifyingNeverClaimsASurveyOrALicence() {
        Hole imported = hole(7, "osm:way/1", true);
        imported.getDataQuality().setAccuracyClass(AccuracyClass.B_LICENSED_PROVIDER);

        service.verify(COURSE_ID, request(7), "admin@vsp");

        // B and A are claims about licensing and survey equipment. No amount of
        // looking earns them, and nothing already better than D is touched.
        assertThat(imported.getDataQuality().getAccuracyClass())
                .isEqualTo(AccuracyClass.B_LICENSED_PROVIDER);
    }

    @Test
    void onlyTheHolesNamedAreTouched() {
        Hole reviewed = hole(1, "osm:way/1", true);
        Hole notReviewed = hole(2, "osm:way/2", true);

        service.verify(COURSE_ID, request(1), "admin@vsp");

        // Verifying a whole course from one button would make VERIFIED mean
        // "somebody pressed a button" instead of "somebody looked".
        assertThat(reviewed.getDataQuality().getVerificationStatus())
                .isEqualTo(VerificationStatus.VERIFIED);
        assertThat(notReviewed.getDataQuality().getVerificationStatus())
                .isEqualTo(VerificationStatus.PENDING_REVIEW);
    }

    @Test
    void theShapesHangingOffTheHoleAreVerifiedWithIt() {
        hole(7, "osm:way/1", true);
        Green green = new Green();
        green.setMetadata(pending());
        Bunker bunker = new Bunker();
        bunker.setMetadata(pending());
        when(greenRepository.findByHoleId(7L)).thenReturn(List.of(green));
        when(bunkerRepository.findByHoleId(7L)).thenReturn(List.of(bunker));

        service.verify(COURSE_ID, request(7), "admin@vsp");

        // A green is positioned relative to the hole it belongs to, so
        // confirming the hole's coordinates confirms it.
        assertThat(green.getMetadata().getVerificationStatus())
                .isEqualTo(VerificationStatus.VERIFIED);
        assertThat(bunker.getMetadata().getVerificationStatus())
                .isEqualTo(VerificationStatus.VERIFIED);
    }

    // ─── Accountability ────────────────────────────────────────────────────

    @Test
    void theAuditTrailNamesWhoMadeTheClaim() {
        hole(7, "osm:way/1", true);

        service.verify(COURSE_ID, request(7), "nghi@vsp");

        // This action is what lets the app draw a map and walk a golfer to a
        // hole. Years later, "who said this was right" has to be answerable.
        verify(auditService).log(
                eq(AuditAction.GEOMETRY_VERIFIED),
                eq("Course"),
                eq("7"),
                isNull(),
                isNull(),
                contains("nghi@vsp"));
    }

    // ─── Summary ───────────────────────────────────────────────────────────

    @Test
    void theSummaryCountsWhatIsWaitingAndWhatCannotBeReviewed() {
        Hole imported = hole(1, "osm:way/1", true);
        Hole seeded = hole(2, "SEED", true);
        seeded.getDataQuality().setVerificationStatus(VerificationStatus.UNVERIFIED);
        when(holeRepository.findByCourseIdOrderByHoleNumber(COURSE_ID))
                .thenReturn(List.of(imported, seeded));

        var summary = service.getReviewSummary(COURSE_ID);

        assertThat(summary.pendingHoles()).isEqualTo(1);
        assertThat(summary.unverifiedHoles()).isEqualTo(1);
        assertThat(summary.holes()).hasSize(2);
        // The reviewer needs to know which rows they can act on before they
        // start ticking boxes.
        assertThat(summary.holes().get(0).reviewable()).isTrue();
        assertThat(summary.holes().get(1).reviewable()).isFalse();
    }

    @Test
    void aCourseThatDoesNotExistIsRefused() {
        when(courseRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getReviewSummary(99L))
                .isInstanceOf(VspApiException.class);
    }

    private DataQualityMetadata pending() {
        DataQualityMetadata quality = new DataQualityMetadata();
        quality.setSource("osm:way/1");
        quality.setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
        quality.setVerificationStatus(VerificationStatus.PENDING_REVIEW);
        return quality;
    }

    // ─── Par ───────────────────────────────────────────────────────────────
    //
    // Par came from the same seed script as the coordinates, and the OSM import
    // replaced every length with a measured one while leaving par alone. Long
    // Thanh ships a par 5 of 326 m and a par 4 of 476 m, and every
    // over/under-par figure on a golfer's scorecard is arithmetic against those.

    private CorrectParRequest parRequest(int holeNumber, int par) {
        return new CorrectParRequest(
                List.of(new CorrectParRequest.HolePar(holeNumber, par)),
                "From the club's printed scorecard");
    }

    @Test
    void aReviewerWithTheScorecardCanCorrectPar() {
        Hole hole = hole(13, "osm:way/1", true);
        hole.setPar(5);
        hole.setPlayingLengthMeters(new java.math.BigDecimal("326.00"));

        CorrectParResponse response = service.correctPar(COURSE_ID, parRequest(13, 4), "admin@vsp");

        assertThat(response.changedHoleNumbers()).containsExactly(13);
        assertThat(hole.getPar()).isEqualTo(4);
    }

    @Test
    void correctingParSaysNothingAboutTheCoordinates() {
        Hole hole = hole(13, "osm:way/1", true);
        hole.setPar(5);

        service.correctPar(COURSE_ID, parRequest(13, 4), "admin@vsp");

        // Reading a scorecard is not checking a map. Letting one imply the
        // other would put unverified geometry in front of a golfer under a
        // badge earned by a different act entirely.
        assertThat(hole.getDataQuality().getVerificationStatus())
                .isEqualTo(VerificationStatus.PENDING_REVIEW);
    }

    @Test
    void aParThatStillContradictsTheLengthIsAppliedAndFlagged() {
        Hole hole = hole(13, "osm:way/1", true);
        hole.setPar(4);
        hole.setPlayingLengthMeters(new java.math.BigDecimal("326.00"));

        // 326 m cannot be a par 5, but the reviewer is holding the card.
        CorrectParResponse response = service.correctPar(COURSE_ID, parRequest(13, 5), "admin@vsp");

        assertThat(hole.getPar()).isEqualTo(5);
        // Applied, because a person with the card outranks a rule of thumb —
        // and recorded, because a card and a measurement that disagree mean one
        // of them is wrong and somebody should find out which.
        assertThat(response.stillImplausible()).containsExactly(13);
    }

    @Test
    void aParAlreadyCorrectIsReportedAsUnchanged() {
        Hole hole = hole(7, "osm:way/1", true);
        hole.setPar(4);

        CorrectParResponse response = service.correctPar(COURSE_ID, parRequest(7, 4), "admin@vsp");

        // A reviewer who typed eighteen rows and got five changes has learned
        // something; "18 updated" would tell them nothing.
        assertThat(response.unchangedHoleNumbers()).containsExactly(7);
        assertThat(response.changedHoleNumbers()).isEmpty();
    }

    @Test
    void aHoleThisCourseDoesNotHaveIsReportedRatherThanIgnored() {
        CorrectParResponse response = service.correctPar(COURSE_ID, parRequest(19, 4), "admin@vsp");

        assertThat(response.unknownHoleNumbers()).containsExactly(19);
        verify(holeRepository, never()).save(any());
    }

    @Test
    void theAuditTrailNamesWhoChangedTheParAndToWhat() {
        Hole hole = hole(13, "osm:way/1", true);
        hole.setPar(5);

        service.correctPar(COURSE_ID, parRequest(13, 4), "nghi@vsp");

        // Every over/under-par number a golfer sees is computed from this.
        verify(auditService).log(
                eq(AuditAction.HOLE_PAR_CORRECTED),
                eq("Course"),
                eq(String.valueOf(COURSE_ID)),
                isNull(),
                isNull(),
                contains("nghi@vsp"));
    }

    // ─── The summary a reviewer reads ──────────────────────────────────────

    @Test
    void theSummaryFlagsAParItsOwnHoleContradicts() {
        Hole implausible = hole(13, "osm:way/1", true);
        implausible.setPar(5);
        implausible.setPlayingLengthMeters(new java.math.BigDecimal("326.00"));
        when(holeRepository.findByCourseIdOrderByHoleNumber(COURSE_ID))
                .thenReturn(List.of(implausible));

        var item = service.getReviewSummary(COURSE_ID).holes().get(0);

        assertThat(item.parMatchesLength()).isFalse();
        assertThat(item.suggestedPar()).isEqualTo(4);
    }

    @Test
    void theSummaryOffersNoSuggestionForAConsistentHole() {
        Hole fine = hole(1, "osm:way/1", true);
        fine.setPar(4);
        fine.setPlayingLengthMeters(new java.math.BigDecimal("361.00"));
        when(holeRepository.findByCourseIdOrderByHoleNumber(COURSE_ID))
                .thenReturn(List.of(fine));

        var item = service.getReviewSummary(COURSE_ID).holes().get(0);

        assertThat(item.parMatchesLength()).isTrue();
        assertThat(item.suggestedPar()).isNull();
    }

    @Test
    void theSummaryComparesTheHoleParsAgainstTheCoursesOwnTotal() {
        Hole one = hole(1, "osm:way/1", true);
        one.setPar(4);
        Hole two = hole(2, "osm:way/2", true);
        two.setPar(5);
        when(holeRepository.findByCourseIdOrderByHoleNumber(COURSE_ID))
                .thenReturn(List.of(one, two));

        var summary = service.getReviewSummary(COURSE_ID);

        // A course's total par is a published fact. When it disagrees with the
        // sum of its holes, at least one hole is wrong — including holes whose
        // par is individually plausible and so flagged by nothing else. On Long
        // Thành the individual checks cleared three holes and the total still
        // came out 71 against an advertised 72.
        assertThat(summary.holeParTotal()).isEqualTo(9);
        assertThat(summary.courseParTotal()).isEqualTo(72);
    }
}
