// A round the phone had already named — VSP API
//
// A phone persists a round and lets the golfer tee off before it has told
// anyone. When it finally reaches the network it has to be able to say which
// round it means, and the only name it has is the one it gave itself.
//
// Without this the phone kept a local UUID, the server issued a different one,
// and every later message about that round — POST /rounds/{id}/complete above
// all — was addressed to an id the server had never seen. Verified against the
// live API on 18/8/2026: HTTP 404, VSP-ERR-ROUND-001. The mobile sync worker
// treats a 4xx as permanent, so the round could never be finished and never
// appeared in a history that is read from the server. It simply vanished.
//
// Three properties, and the second two matter more than the first: a retry
// must not create a second round, and an id is a name, never a permission.

package vnpt.vsp.module.round;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.CourseService;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;
import vnpt.vsp.module.round.dto.RoundCreateRequest;
import vnpt.vsp.module.round.dto.RoundResponse;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.round.repository.RoundSegmentRepository;
import vnpt.vsp.module.round.repository.ScoreRepository;
import vnpt.vsp.module.tournament.TournamentPolicyService;
import vnpt.vsp.module.tournament.TournamentService;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RoundServiceClientIdTest {

    @Mock private RoundRepository roundRepository;
    @Mock private RoundSegmentRepository roundSegmentRepository;
    @Mock private ScoreRepository scoreRepository;
    @Mock private CourseService courseService;
    @Mock private GolferAccountRepository golferAccountRepository;
    @Mock private AuditService auditService;
    @Mock private TournamentPolicyService tournamentPolicyService;
    @Mock private TournamentService tournamentService;

    private RoundServiceImpl service;

    private static final long GOLFER = 100L;
    private static final long SOMEBODY_ELSE = 101L;

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

    private Course course() {
        Course course = new Course();
        course.setId(1L);
        course.setName("Long Biên Golf Course");
        return course;
    }

    private RoundCreateRequest requestWith(UUID clientRoundId) {
        RoundCreateRequest request = new RoundCreateRequest();
        request.setCourseId(1L);
        request.setClientRoundId(clientRoundId);
        return request;
    }

    @Test
    void theRoundIsSavedUnderTheNameThePhoneGaveIt() {
        UUID chosen = UUID.randomUUID();

        when(courseService.getCourse(1L)).thenReturn(course());
        when(golferAccountRepository.existsById(any())).thenReturn(true);
        when(roundRepository.findById(chosen)).thenReturn(Optional.empty());
        when(roundRepository.save(any(Round.class))).thenAnswer(i -> i.getArgument(0));

        RoundResponse response = service.createRound(GOLFER, requestWith(chosen));

        ArgumentCaptor<Round> saved = ArgumentCaptor.forClass(Round.class);
        verify(roundRepository).save(saved.capture());
        assertEquals(chosen, saved.getValue().getId(),
                "the phone is already using this id for the round it is playing");
        assertEquals(chosen, response.getId());
    }

    @Test
    void withoutOneTheRoundStillGetsAnId() {
        // Older clients send nothing and must be unaffected. The id now comes
        // from the entity rather than from Hibernate, so this asks that it is
        // still there at all.
        when(courseService.getCourse(1L)).thenReturn(course());
        when(golferAccountRepository.existsById(any())).thenReturn(true);
        when(roundRepository.save(any(Round.class))).thenAnswer(i -> i.getArgument(0));

        RoundResponse response = service.createRound(GOLFER, requestWith(null));

        assertNotNull(response.getId());
        verify(roundRepository, never()).findById(any(UUID.class));
    }

    @Test
    void sendingTheSameNameTwiceReturnsTheRoundRatherThanASecondOne() {
        // What a retry after a lost response looks like, and what a phone
        // reporting a round it played out of signal looks like. A duplicate
        // here puts one afternoon in the golfer's history twice.
        UUID chosen = UUID.randomUUID();

        Round already = new Round();
        already.setId(chosen);
        already.setCourseId(1L);
        already.setGolferAccountId(GOLFER);
        already.setStatus(Round.RoundStatus.IN_PROGRESS);

        when(roundRepository.findById(chosen)).thenReturn(Optional.of(already));
        when(courseService.getCourse(1L)).thenReturn(course());

        RoundResponse response = service.createRound(GOLFER, requestWith(chosen));

        assertEquals(chosen, response.getId());
        verify(roundRepository, never()).save(any(Round.class));
        verify(scoreRepository, never()).saveAll(any());
    }

    @Test
    void anIdIsANameAndNeverAPermission() {
        // The client chooses this value, so it cannot also be what proves the
        // round is theirs. Answering with somebody else's round would hand
        // over their course, their start time and their scorecard id.
        UUID chosen = UUID.randomUUID();

        Round theirs = new Round();
        theirs.setId(chosen);
        theirs.setCourseId(1L);
        theirs.setGolferAccountId(SOMEBODY_ELSE);
        theirs.setStatus(Round.RoundStatus.IN_PROGRESS);

        when(roundRepository.findById(chosen)).thenReturn(Optional.of(theirs));

        VspApiException thrown = assertThrows(
                VspApiException.class,
                () -> service.createRound(GOLFER, requestWith(chosen)));

        assertEquals("clientRoundId", thrown.getField());
        verify(roundRepository, never()).save(any(Round.class));
    }
}
