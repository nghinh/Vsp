// RoundService abandon tests — VSP API
//
// Covers POST /rounds/{roundId}/abandon at the service layer: a golfer
// discarding a round they started but will not finish.
//
// The mobile Rounds tab rebuilds its list from GET /rounds and filters out
// ABANDONED rounds, so this call is the only thing that makes an unfinished
// round disappear. That puts three properties on the critical path and each
// has a test here:
//
//   - it is idempotent, because the client retries it with an Idempotency-Key
//     and the second attempt must not be an error;
//   - it never touches a round belonging to somebody else;
//   - it refuses to rewrite the status of a COMPLETED round, which carries a
//     scorecard and a handicap-relevant result.

package vnpt.vsp.module.round;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.CourseService;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;
import vnpt.vsp.module.round.dto.RoundResponse;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.round.repository.RoundSegmentRepository;
import vnpt.vsp.module.round.repository.ScoreRepository;
import vnpt.vsp.module.tournament.TournamentPolicyService;
import vnpt.vsp.module.tournament.TournamentService;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RoundServiceAbandonTest {

    private static final Long GOLFER_ID = 100L;
    private static final Long OTHER_GOLFER_ID = 200L;
    private static final Long COURSE_ID = 1L;

    @Mock private RoundRepository roundRepository;
    @Mock private RoundSegmentRepository roundSegmentRepository;
    @Mock private ScoreRepository scoreRepository;
    @Mock private CourseService courseService;
    @Mock private GolferAccountRepository golferAccountRepository;
    @Mock private AuditService auditService;
    @Mock private TournamentPolicyService tournamentPolicyService;
    @Mock private TournamentService tournamentService;

    private RoundServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new RoundServiceImpl(
                roundRepository,
                roundSegmentRepository,
                scoreRepository,
                courseService,
                golferAccountRepository,
                auditService,
                tournamentPolicyService,
                tournamentService
        );
    }

    private Round round(UUID id, Round.RoundStatus status, Long ownerId) {
        Round round = new Round();
        round.setId(id);
        round.setCourseId(COURSE_ID);
        round.setGolferAccountId(ownerId);
        round.setStatus(status);
        round.setStartedAt(Instant.now().minus(2, ChronoUnit.HOURS));
        return round;
    }

    private void stubCourse() {
        Course course = new Course();
        course.setId(COURSE_ID);
        course.setName("Test Course");
        when(courseService.getCourse(COURSE_ID)).thenReturn(course);
    }

    @Test
    void abandonRound_inProgressRound_marksAbandonedAndSetsEndedAt() {
        UUID roundId = UUID.randomUUID();
        Round round = round(roundId, Round.RoundStatus.IN_PROGRESS, GOLFER_ID);
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(round));
        stubCourse();

        Instant before = Instant.now();
        RoundResponse response = service.abandonRound(GOLFER_ID, roundId);

        assertEquals(Round.RoundStatus.ABANDONED, response.getStatus());
        assertNotNull(response.getEndedAt(), "an abandoned round must be closed off with an end time");
        assertFalse(response.getEndedAt().isBefore(before));
        assertEquals("Test Course", response.getCourseName());
        verify(roundRepository).save(round);
        assertEquals(Round.RoundStatus.ABANDONED, round.getStatus());
    }

    @Test
    void abandonRound_inProgressRound_isAudited() {
        UUID roundId = UUID.randomUUID();
        Round round = round(roundId, Round.RoundStatus.IN_PROGRESS, GOLFER_ID);
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(round));
        stubCourse();

        service.abandonRound(GOLFER_ID, roundId);

        verify(auditService).log(
                eq(AuditAction.ROUND_ABANDON),
                eq("Round"),
                eq(roundId.toString()),
                isNull(),
                contains("ABANDONED"),
                contains(String.valueOf(GOLFER_ID))
        );
    }

    @Test
    void abandonRound_keepsAnEndedAtThatIsAlreadySet() {
        UUID roundId = UUID.randomUUID();
        Round round = round(roundId, Round.RoundStatus.IN_PROGRESS, GOLFER_ID);
        Instant playedUntil = Instant.now().minus(30, ChronoUnit.MINUTES);
        round.setEndedAt(playedUntil);
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(round));
        stubCourse();

        RoundResponse response = service.abandonRound(GOLFER_ID, roundId);

        assertEquals(playedUntil, response.getEndedAt(),
                "when the round already recorded when play stopped, abandoning must not overwrite it");
    }

    @Test
    void abandonRound_alreadyAbandoned_isIdempotentAndDoesNotWriteAgain() {
        UUID roundId = UUID.randomUUID();
        Round round = round(roundId, Round.RoundStatus.ABANDONED, GOLFER_ID);
        Instant abandonedAt = Instant.now().minus(1, ChronoUnit.HOURS);
        round.setEndedAt(abandonedAt);
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(round));
        stubCourse();

        RoundResponse response = service.abandonRound(GOLFER_ID, roundId);

        assertEquals(Round.RoundStatus.ABANDONED, response.getStatus());
        assertEquals(abandonedAt, response.getEndedAt(),
                "a repeat abandon must not move the end time — the retry would rewrite history");
        verify(roundRepository, never()).save(any(Round.class));
        verify(auditService, never()).log(any(), any(), any(), any(), any(), any());
    }

    @Test
    void abandonRound_completedRound_isRefusedAsAlreadyCompleted() {
        UUID roundId = UUID.randomUUID();
        Round round = round(roundId, Round.RoundStatus.COMPLETED, GOLFER_ID);
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(round));

        VspApiException ex = assertThrows(VspApiException.class,
                () -> service.abandonRound(GOLFER_ID, roundId));

        assertEquals(VspErrorCode.ROUND_003, ex.getErrorCode());
        assertEquals("roundId", ex.getField());
        assertEquals(Round.RoundStatus.COMPLETED, round.getStatus(), "the round must be left alone");
        verify(roundRepository, never()).save(any(Round.class));
    }

    @Test
    void abandonRound_someoneElsesRound_isRefused() {
        UUID roundId = UUID.randomUUID();
        Round round = round(roundId, Round.RoundStatus.IN_PROGRESS, OTHER_GOLFER_ID);
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(round));

        VspApiException ex = assertThrows(VspApiException.class,
                () -> service.abandonRound(GOLFER_ID, roundId));

        assertEquals(VspErrorCode.AUTH_010, ex.getErrorCode());
        assertEquals(Round.RoundStatus.IN_PROGRESS, round.getStatus());
        verify(roundRepository, never()).save(any(Round.class));
    }

    @Test
    void abandonRound_unknownRound_isNotFound() {
        UUID roundId = UUID.randomUUID();
        when(roundRepository.findById(roundId)).thenReturn(Optional.empty());

        VspApiException ex = assertThrows(VspApiException.class,
                () -> service.abandonRound(GOLFER_ID, roundId));

        assertEquals(VspErrorCode.ROUND_001, ex.getErrorCode());
    }

    @Test
    void abandonRound_roundWithoutACourse_doesNotAskForACourseName() {
        UUID roundId = UUID.randomUUID();
        Round round = round(roundId, Round.RoundStatus.IN_PROGRESS, GOLFER_ID);
        round.setCourseId(null);
        when(roundRepository.findById(roundId)).thenReturn(Optional.of(round));

        RoundResponse response = service.abandonRound(GOLFER_ID, roundId);

        assertEquals(Round.RoundStatus.ABANDONED, response.getStatus());
        assertNull(response.getCourseName());
        verify(courseService, never()).getCourse(any());
    }
}
