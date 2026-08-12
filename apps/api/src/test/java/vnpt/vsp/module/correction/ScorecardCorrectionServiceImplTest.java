package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.correction.dto.ScorecardSubmissionRequest;
import vnpt.vsp.module.correction.entity.CorrectionType;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.entity.Scorecard;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.ScorecardRepository;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * A club's card, from the golfer's hands to the scoring table.
 *
 * <p>Stroke index is printed on that card and exists in no open dataset, so
 * this path is the only way it can ever reach the app. What it writes is used
 * to allocate strokes, which means a card approved with two holes sharing an
 * index, or a hole missing altogether, misallocates every net score computed
 * from it — quietly, and for everyone who plays there.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ScorecardCorrectionServiceImplTest {

    @Mock private CourseCorrectionRepository correctionRepository;
    @Mock private ScorecardRepository scorecardRepository;
    @Mock private CourseRepository courseRepository;

    private ScorecardCorrectionServiceImpl service;

    private static final Long FACILITY_ID = 7L;
    private static final Long DUONG_A = 21L;
    private static final Long DUONG_B = 22L;

    @BeforeEach
    void setUp() {
        service = new ScorecardCorrectionServiceImpl(
                correctionRepository, scorecardRepository, courseRepository, new ObjectMapper());

        when(courseRepository.findById(DUONG_A)).thenReturn(Optional.of(duong(DUONG_A, FACILITY_ID)));
        when(courseRepository.findById(DUONG_B)).thenReturn(Optional.of(duong(DUONG_B, FACILITY_ID)));
        when(correctionRepository.save(any(CourseCorrection.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(scorecardRepository.saveAndFlush(any(Scorecard.class)))
                .thenAnswer(inv -> {
                    // A save assigns an id to a new row and leaves an existing
                    // one alone, which is the whole point of the reprint case.
                    Scorecard card = inv.getArgument(0);
                    if (card.getId() == null) {
                        card.setId(99L);
                    }
                    return card;
                });
        when(scorecardRepository.save(any(Scorecard.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private Course duong(Long id, Long facilityId) {
        GolfFacility facility = new GolfFacility();
        facility.setId(facilityId);
        Course course = new Course();
        course.setId(id);
        course.setFacility(facility);
        course.setName("Đường " + id);
        course.setHolesCount(9);
        return course;
    }

    private ScorecardSubmissionRequest card(List<ScorecardSubmissionRequest.HoleLine> holes) {
        return card(holes, null);
    }

    private ScorecardSubmissionRequest card(
            List<ScorecardSubmissionRequest.HoleLine> holes,
            List<ScorecardSubmissionRequest.TeeLine> tees) {
        return new ScorecardSubmissionRequest(
                "A + B", List.of(DUONG_A, DUONG_B), holes, tees,
                "https://example/card.jpg", "chụp ở tee 1");
    }

    private ScorecardSubmissionRequest.TeeLine tee(String name, String rating, Integer slope, int holes) {
        return new ScorecardSubmissionRequest.TeeLine(
                name,
                rating == null ? null : new java.math.BigDecimal(rating),
                slope,
                java.util.stream.IntStream.rangeClosed(1, holes)
                        .mapToObj(i -> new ScorecardSubmissionRequest.Yardage(i, 300 + i))
                        .toList());
    }

    private List<ScorecardSubmissionRequest.HoleLine> eighteen() {
        return java.util.stream.IntStream.rangeClosed(1, 18)
                .mapToObj(i -> new ScorecardSubmissionRequest.HoleLine(i, i % 3 == 0 ? 3 : 4, i))
                .toList();
    }

    @Test
    void aSubmittedCardIsQueuedAsOneCorrection() {
        // One photograph, one queue item, one decision — not eighteen
        // decisions about the same piece of evidence.
        CourseCorrection saved = service.submit(DUONG_A, 11L, card(eighteen()));

        assertThat(saved.getCorrectionType()).isEqualTo(CorrectionType.SCORECARD);
        assertThat(saved.getReporterEvidenceUrl()).isEqualTo("https://example/card.jpg");
        assertThat(saved.getProposedScorecard()).contains("\"strokeIndex\":18");
        verify(correctionRepository).save(any(CourseCorrection.class));
    }

    @Test
    void aCardMissingAHoleIsRefused() {
        List<ScorecardSubmissionRequest.HoleLine> holes =
                new java.util.ArrayList<>(eighteen());
        holes.remove(4); // hole 5 never typed

        assertThatThrownBy(() -> service.submit(DUONG_A, 11L, card(holes)))
                .isInstanceOf(VspApiException.class);
        verify(correctionRepository, never()).save(any());
    }

    @Test
    void twoHolesSharingAStrokeIndexAreRefused() {
        // The pair would misallocate strokes on both of them, and on a card
        // reviewed from a photograph it is the likeliest typing error there is.
        List<ScorecardSubmissionRequest.HoleLine> holes =
                new java.util.ArrayList<>(eighteen());
        holes.set(3, new ScorecardSubmissionRequest.HoleLine(4, 4, 5));

        assertThatThrownBy(() -> service.submit(DUONG_A, 11L, card(holes)))
                .isInstanceOf(VspApiException.class);
        verify(correctionRepository, never()).save(any());
    }

    @Test
    void aDuongFromAnotherClubIsRefused() {
        when(courseRepository.findById(DUONG_B)).thenReturn(Optional.of(duong(DUONG_B, 999L)));

        assertThatThrownBy(() -> service.submit(DUONG_A, 11L, card(eighteen())))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    void approvingPublishesTheCardWithItsPairingAndIndexes() {
        CourseCorrection correction = service.submit(DUONG_A, 11L, card(eighteen()));
        correction.setId(500L);
        when(scorecardRepository.findByFacilityIdAndName(FACILITY_ID, "A + B"))
                .thenReturn(Optional.empty());

        service.applyIfScorecard(correction);

        ArgumentCaptor<Scorecard> captor = ArgumentCaptor.forClass(Scorecard.class);
        verify(scorecardRepository).save(captor.capture());
        Scorecard published = captor.getValue();

        assertThat(published.getName()).isEqualTo("A + B");
        assertThat(published.getFacilityId()).isEqualTo(FACILITY_ID);
        assertThat(published.getHolesCount()).isEqualTo(18);
        assertThat(published.getHoles()).hasSize(18);
        assertThat(published.getSegments()).hasSize(2);
        assertThat(published.getSegments().get(0).getCourseId()).isEqualTo(DUONG_A);
        assertThat(published.getSegments().get(1).getCourseId()).isEqualTo(DUONG_B);
        assertThat(published.getParTotal()).isEqualTo(
                eighteen().stream().mapToInt(ScorecardSubmissionRequest.HoleLine::par).sum());
    }

    @Test
    void approvingAGeometryCorrectionPublishesNothing() {
        CourseCorrection geometry = new CourseCorrection();
        geometry.setCorrectionType(CorrectionType.BUNKER);

        service.applyIfScorecard(geometry);

        verify(scorecardRepository, never()).save(any());
    }

    @Test
    void aReprintReplacesTheCardOfTheSameName() {
        // Two cards called "A + B" is a question nobody can answer while
        // someone is standing on the first tee.
        Scorecard existing = new Scorecard();
        existing.setId(42L);
        existing.setFacilityId(FACILITY_ID);
        existing.setName("A + B");
        when(scorecardRepository.findByFacilityIdAndName(FACILITY_ID, "A + B"))
                .thenReturn(Optional.of(existing));

        CourseCorrection correction = service.submit(DUONG_A, 11L, card(eighteen()));
        service.applyIfScorecard(correction);

        ArgumentCaptor<Scorecard> captor = ArgumentCaptor.forClass(Scorecard.class);
        verify(scorecardRepository).save(captor.capture());
        assertThat(captor.getValue().getId()).isEqualTo(42L);
    }

    @Test
    void approvingWritesTheTeeRowsAndTheirYardages() {
        // Until this existed, approving a card published its pars and its
        // stroke indexes and dropped the rest of the photograph on the floor:
        // the yardages and the ratings stayed in the correction payload, where
        // nothing that scores a round can reach them. A score is only
        // comparable against the tee it was played from, and course rating and
        // slope are what make it a handicap differential at all.
        CourseCorrection correction = service.submit(DUONG_A, 11L,
                card(eighteen(), List.of(
                        tee("GOLD", "75.5", 138, 18),
                        tee("RED", "72.9", 129, 18))));
        correction.setId(501L);
        when(scorecardRepository.findByFacilityIdAndName(FACILITY_ID, "A + B"))
                .thenReturn(Optional.empty());

        service.applyIfScorecard(correction);

        ArgumentCaptor<Scorecard> captor = ArgumentCaptor.forClass(Scorecard.class);
        verify(scorecardRepository).save(captor.capture());
        Scorecard published = captor.getValue();

        assertThat(published.getTees()).hasSize(2);
        assertThat(published.getTees().get(0).getName()).isEqualTo("GOLD");
        assertThat(published.getTees().get(0).getCourseRating())
                .isEqualByComparingTo(new java.math.BigDecimal("75.5"));
        assertThat(published.getTees().get(0).getSlopeRating()).isEqualTo(138);
        assertThat(published.getTees().get(0).getYardages()).hasSize(18);
        assertThat(published.getTees().get(0).getYardages().get(0).getYards()).isEqualTo(301);
        assertThat(published.getTees().get(1).getName()).isEqualTo("RED");
    }

    @Test
    void aCardWithNoTeeRowsIsStillPublished() {
        // Photographs get taken with the rating table outside the frame, and a
        // card with no tee rows is still worth its pars and its indexes.
        // Refusing it would cost the whole card for the sake of the yardages.
        CourseCorrection correction = service.submit(DUONG_A, 11L, card(eighteen(), List.of()));
        when(scorecardRepository.findByFacilityIdAndName(FACILITY_ID, "A + B"))
                .thenReturn(Optional.empty());

        service.applyIfScorecard(correction);

        ArgumentCaptor<Scorecard> captor = ArgumentCaptor.forClass(Scorecard.class);
        verify(scorecardRepository).save(captor.capture());
        assertThat(captor.getValue().getHoles()).hasSize(18);
        assertThat(captor.getValue().getTees()).isEmpty();
    }

    @Test
    void oneTeeNamedTwiceIsOneTee() {
        // The card names each tee once, and the table says so. Two rows called
        // GOLD is one column read twice, and keeping both would put two
        // ratings on one tee with nothing to choose between them — and break
        // the unique constraint on the way.
        CourseCorrection correction = service.submit(DUONG_A, 11L,
                card(eighteen(), List.of(
                        tee("GOLD", "75.5", 138, 9),
                        tee("gold", "74.1", 136, 9))));
        when(scorecardRepository.findByFacilityIdAndName(FACILITY_ID, "A + B"))
                .thenReturn(Optional.empty());

        service.applyIfScorecard(correction);

        ArgumentCaptor<Scorecard> captor = ArgumentCaptor.forClass(Scorecard.class);
        verify(scorecardRepository).save(captor.capture());
        assertThat(captor.getValue().getTees()).hasSize(1);
        assertThat(captor.getValue().getTees().get(0).getSlopeRating()).isEqualTo(138);
    }

    @Test
    void aReprintReplacesTheTeesToo() {
        // A club that reprints its card with new ratings has new ratings. The
        // old tee rows going with the old card is the point of hanging them
        // off the card rather than the course.
        Scorecard existing = new Scorecard();
        existing.setId(42L);
        existing.setFacilityId(FACILITY_ID);
        existing.setName("A + B");
        existing.getTees().add(
                new vnpt.vsp.module.course.entity.ScorecardTee(
                        existing, "OLD", new java.math.BigDecimal("70.0"), 120));
        when(scorecardRepository.findByFacilityIdAndName(FACILITY_ID, "A + B"))
                .thenReturn(Optional.of(existing));

        CourseCorrection correction = service.submit(DUONG_A, 11L,
                card(eighteen(), List.of(tee("GOLD", "75.5", 138, 18))));
        service.applyIfScorecard(correction);

        ArgumentCaptor<Scorecard> captor = ArgumentCaptor.forClass(Scorecard.class);
        verify(scorecardRepository).save(captor.capture());
        assertThat(captor.getValue().getTees()).hasSize(1);
        assertThat(captor.getValue().getTees().get(0).getName()).isEqualTo("GOLD");
    }
}
