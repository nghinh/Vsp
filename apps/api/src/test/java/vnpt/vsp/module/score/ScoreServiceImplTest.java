package vnpt.vsp.module.score;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.score.dto.FieldCorrection;
import vnpt.vsp.module.score.dto.ScoreCorrectionRequest;
import vnpt.vsp.module.score.dto.ScoreSyncRequest;
import vnpt.vsp.module.score.entity.Score;
import vnpt.vsp.module.score.entity.ScoreEntry;
import vnpt.vsp.module.score.repository.ScoreCorrectionRepository;
import vnpt.vsp.module.score.repository.ScoreEntryRepository;
import vnpt.vsp.module.score.repository.ScoreRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Tests for score sync.
 *
 * <p>The entire {@code score} module — the controller, this service, both sync
 * DTOs, {@code ScoreEntry} and all three repositories — had no tests at all.
 * It is the path the product's loudest promise runs through: "scorecard data is
 * never lost". Sixteen files, zero coverage.</p>
 *
 * <p>The par tests below are the reason this file exists now. Every new entry
 * was stamped {@code par = 4} unconditionally, because par was read from the
 * client and {@code ScoreSyncRequest.ScoreUpdate} has no par field — so the
 * branch was taken every time. On a standard course that is eight holes in
 * eighteen where every server-side score-to-par, handicap input and derived
 * statistic was wrong, and wrong quietly.</p>
 */
@ExtendWith(MockitoExtension.class)
class ScoreServiceImplTest {

    @Mock private ScoreRepository scoreRepository;
    @Mock private ScoreEntryRepository scoreEntryRepository;
    @Mock private ScoreCorrectionRepository scoreCorrectionRepository;
    @Mock private RoundRepository roundRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private AuditService auditService;

    private ScoreServiceImpl service;

    private static final Long ACCOUNT_ID = 100L;
    private static final Long COURSE_ID = 7L;
    private static final UUID ROUND_ID = UUID.randomUUID();
    private static final UUID SCORE_ID = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ScoreServiceImpl(
                scoreRepository,
                scoreEntryRepository,
                scoreCorrectionRepository,
                roundRepository,
                holeRepository,
                auditService);
    }

    // ─── Harness ───────────────────────────────────────────────────────────

    private Round round(Long courseId) {
        Round round = new Round();
        round.setId(ROUND_ID);
        round.setGolferAccountId(ACCOUNT_ID);
        round.setCourseId(courseId);
        return round;
    }

    private Score score() {
        Score score = new Score();
        score.setId(SCORE_ID);
        score.setRoundId(ROUND_ID);
        score.setGolferAccountId(ACCOUNT_ID);
        return score;
    }

    private Hole hole(int number, Integer par) {
        Hole hole = new Hole();
        hole.setHoleNumber(number);
        hole.setPar(par);
        return hole;
    }

    private ScoreSyncRequest request(int holeNumber, Integer grossScore) {
        return new ScoreSyncRequest(
                ROUND_ID,
                null,
                List.of(new ScoreSyncRequest.ScoreUpdate(
                        SCORE_ID, holeNumber, ACCOUNT_ID, grossScore,
                        null, null, null, null, null, null, 1)),
                UUID.randomUUID());
    }

    private void givenRoundOnCourse(Long courseId) {
        when(roundRepository.findById(ROUND_ID)).thenReturn(Optional.of(round(courseId)));
        when(scoreRepository.findByRoundIdAndDeletedAtIsNull(ROUND_ID))
                .thenReturn(List.of(score()));
    }

    private ScoreEntry syncAndCaptureEntry() {
        ArgumentCaptor<ScoreEntry> captor = ArgumentCaptor.forClass(ScoreEntry.class);
        verify(scoreEntryRepository).save(captor.capture());
        return captor.getValue();
    }

    // ─── Par ───────────────────────────────────────────────────────────────

    @Test
    void parComesFromTheCourse_notFromAGuess() {
        givenRoundOnCourse(COURSE_ID);
        when(scoreEntryRepository.findByScoreIdAndHoleNumber(SCORE_ID, 8))
                .thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdAndHoleNumber(COURSE_ID, 8))
                .thenReturn(Optional.of(hole(8, 3)));

        service.syncScores(ACCOUNT_ID, "key-1", request(8, 2));

        // A par 3 recorded as par 4 turns a birdie into a par, in every
        // statistic derived from it, silently.
        assertThat(syncAndCaptureEntry().getPar()).isEqualTo(3);
    }

    @Test
    void parFiveIsRecordedAsFive() {
        givenRoundOnCourse(COURSE_ID);
        when(scoreEntryRepository.findByScoreIdAndHoleNumber(SCORE_ID, 13))
                .thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdAndHoleNumber(COURSE_ID, 13))
                .thenReturn(Optional.of(hole(13, 5)));

        service.syncScores(ACCOUNT_ID, "key-2", request(13, 6));

        assertThat(syncAndCaptureEntry().getPar()).isEqualTo(5);
    }

    @Test
    void theServerDoesNotAskTheClientForPar() {
        givenRoundOnCourse(COURSE_ID);
        when(scoreEntryRepository.findByScoreIdAndHoleNumber(SCORE_ID, 8))
                .thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdAndHoleNumber(COURSE_ID, 8))
                .thenReturn(Optional.of(hole(8, 3)));

        service.syncScores(ACCOUNT_ID, "key-3", request(8, 2));

        // Par is course data. The device holds a copy, and a copy is not a
        // source — the wire format has no par field precisely because of this.
        verify(holeRepository).findByCourseIdAndHoleNumber(COURSE_ID, 8);
    }

    @Test
    void anAdHocRoundWithNoCourseStillRecordsAScore() {
        givenRoundOnCourse(null);
        when(scoreEntryRepository.findByScoreIdAndHoleNumber(SCORE_ID, 4))
                .thenReturn(Optional.empty());

        service.syncScores(ACCOUNT_ID, "key-4", request(4, 5));

        // Nothing to look par up against, and a not-null column to satisfy.
        // Refusing the score would be the one unacceptable outcome.
        ScoreEntry entry = syncAndCaptureEntry();
        assertThat(entry.getPar()).isEqualTo(4);
        assertThat(entry.getStrokes()).isEqualTo(5);
        verifyNoInteractions(holeRepository);
    }

    @Test
    void aHoleTheCourseDoesNotCoverStillRecordsAScore() {
        givenRoundOnCourse(COURSE_ID);
        when(scoreEntryRepository.findByScoreIdAndHoleNumber(SCORE_ID, 19))
                .thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdAndHoleNumber(COURSE_ID, 19))
                .thenReturn(Optional.empty());

        service.syncScores(ACCOUNT_ID, "key-5", request(19, 4));

        assertThat(syncAndCaptureEntry().getPar()).isEqualTo(4);
    }

    @Test
    void aCourseWithNonsenseParDoesNotOverwriteWithNonsense() {
        givenRoundOnCourse(COURSE_ID);
        when(scoreEntryRepository.findByScoreIdAndHoleNumber(SCORE_ID, 2))
                .thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdAndHoleNumber(COURSE_ID, 2))
                .thenReturn(Optional.of(hole(2, 0)));

        service.syncScores(ACCOUNT_ID, "key-6", request(2, 4));

        // A par of zero is a data defect, not a hole. Fall back rather than
        // write it into a golfer's scorecard.
        assertThat(syncAndCaptureEntry().getPar()).isEqualTo(4);
    }

    @Test
    void anExistingEntryKeepsTheParItWasRecordedWith() {
        givenRoundOnCourse(COURSE_ID);
        ScoreEntry existing = new ScoreEntry();
        existing.setScoreId(SCORE_ID);
        existing.setHoleNumber(8);
        existing.setPar(3);
        when(scoreEntryRepository.findByScoreIdAndHoleNumber(SCORE_ID, 8))
                .thenReturn(Optional.of(existing));

        service.syncScores(ACCOUNT_ID, "key-7", request(8, 4));

        // Re-syncing a corrected score must not re-derive par from a course
        // that may have been re-published since the round was played.
        assertThat(syncAndCaptureEntry().getPar()).isEqualTo(3);
        verifyNoInteractions(holeRepository);
    }

    // ─── The rest of the sync contract ─────────────────────────────────────

    @Test
    void aHoleWithNoStrokesYetCreatesNoEntry() {
        givenRoundOnCourse(COURSE_ID);

        service.syncScores(ACCOUNT_ID, "key-8", request(5, null));

        // The device queues placeholders for unplayed holes. Persisting them
        // would fill a scorecard with holes nobody has played.
        verify(scoreEntryRepository, never()).save(any());
    }

    @Test
    void aRoundThatDoesNotExistIsRefused() {
        when(roundRepository.findById(ROUND_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.syncScores(ACCOUNT_ID, "key-9", request(1, 4)))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    void aGolferCannotSyncIntoSomebodyElsesRound() {
        when(roundRepository.findById(ROUND_ID)).thenReturn(Optional.of(round(COURSE_ID)));

        assertThatThrownBy(() -> service.syncScores(999L, "key-10", request(1, 4)))
                .isInstanceOf(VspApiException.class);
    }

    // ─── Corrections ───────────────────────────────────────────────────────

    private ScoreCorrectionRequest correction(String field, int holeNumber, String newValue) {
        FieldCorrection fc = new FieldCorrection();
        fc.setField(field);
        fc.setHoleNumber(holeNumber);
        fc.setNewValue(newValue);
        ScoreCorrectionRequest request = new ScoreCorrectionRequest();
        request.setPlayerId(ACCOUNT_ID);
        request.setCorrections(List.of(fc));
        return request;
    }

    private Round completedRound(Long courseId) {
        Round round = round(courseId);
        round.setStatus(Round.RoundStatus.COMPLETED);
        return round;
    }

    @Test
    void correctingAHoleWithNoEntryYetLooksParUpRatherThanWritingZero() {
        when(roundRepository.findById(ROUND_ID))
                .thenReturn(Optional.of(completedRound(COURSE_ID)));
        when(scoreRepository.findByRoundIdAndDeletedAtIsNull(ROUND_ID))
                .thenReturn(List.of(score()));
        when(scoreEntryRepository.findByScoreIdAndHoleNumber(SCORE_ID, 8))
                .thenReturn(Optional.empty());
        when(holeRepository.findByCourseIdAndHoleNumber(COURSE_ID, 8))
                .thenReturn(Optional.of(hole(8, 3)));

        service.correctScoreEntries(ROUND_ID, ACCOUNT_ID, correction("putts", 8, "2"));

        // This path used to write par = 0 with the comment "client should send
        // it" — the client has no way to send one here, and a par of zero is
        // not a hole.
        assertThat(syncAndCaptureEntry().getPar()).isEqualTo(3);
    }

    @Test
    void anIncompleteRoundCannotBeCorrected() {
        Round inProgress = round(COURSE_ID);
        inProgress.setStatus(Round.RoundStatus.IN_PROGRESS);
        when(roundRepository.findById(ROUND_ID)).thenReturn(Optional.of(inProgress));

        // Corrections are an after-the-round act with an audit trail. Allowing
        // them mid-round would make "corrected" indistinguishable from "played".
        assertThatThrownBy(() ->
                service.correctScoreEntries(ROUND_ID, ACCOUNT_ID, correction("putts", 8, "2")))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    void aFieldOutsideThePermittedSetIsRefused() {
        when(roundRepository.findById(ROUND_ID))
                .thenReturn(Optional.of(completedRound(COURSE_ID)));
        when(scoreRepository.findByRoundIdAndDeletedAtIsNull(ROUND_ID))
                .thenReturn(List.of(score()));

        assertThatThrownBy(() ->
                service.correctScoreEntries(ROUND_ID, ACCOUNT_ID, correction("par", 8, "3")))
                .isInstanceOf(VspApiException.class);
        verify(scoreEntryRepository, never()).save(any());
    }

    @Test
    void aGolferCannotCorrectSomebodyElsesRound() {
        when(roundRepository.findById(ROUND_ID))
                .thenReturn(Optional.of(completedRound(COURSE_ID)));

        assertThatThrownBy(() ->
                service.correctScoreEntries(ROUND_ID, 999L, correction("putts", 8, "2")))
                .isInstanceOf(VspApiException.class);
    }
}
