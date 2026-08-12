// RoundService Tournament Policy Propagation Test — VSP API
//
// Per Story 12.1 Slice F: tournament policy auto-assignment and propagation
//
// Tests:
// - POST /rounds with tournamentId auto-populates tournamentPolicyId from tournament
// - Tournament policy version captured at round creation
// - Tournament policy locked on round start

package vnpt.vsp.module.round;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.course.CourseService;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.round.dto.RoundCreateRequest;
import vnpt.vsp.module.round.dto.RoundResponse;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.round.repository.RoundSegmentRepository;
import vnpt.vsp.module.round.repository.ScoreRepository;
import vnpt.vsp.module.tournament.TournamentPolicyService;
import vnpt.vsp.module.tournament.TournamentService;
import vnpt.vsp.module.tournament.dto.TournamentPolicyResponse;
import vnpt.vsp.module.tournament.entity.Tournament;
import vnpt.vsp.module.tournament.entity.TournamentFormat;
import vnpt.vsp.module.tournament.entity.TournamentStatus;
import vnpt.vsp.module.tournament.repository.*;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RoundServiceTournamentPolicyTest {

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

    @Test
    void createRound_withTournamentId_autoPopulatesTournamentPolicyId() {
        // Given
        UUID tournamentId = UUID.randomUUID();
        UUID policyId = UUID.randomUUID();

        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);
        tournament.setTournamentPolicyId(policyId);
        tournament.setFormat(TournamentFormat.STROKE_PLAY);
        tournament.setStatus(TournamentStatus.REGISTRATION_OPEN);

        Course course = new Course();
        course.setId(1L);
        course.setName("Test Course");

        TournamentPolicyResponse policy = new TournamentPolicyResponse();
        policy.setId(policyId);
        policy.setVersion(3);

        RoundCreateRequest request = new RoundCreateRequest();
        request.setCourseId(1L);
        request.setTournamentId(tournamentId);
        // tournamentPolicyId is NOT set — should be auto-populated

        Round savedRound = new Round();
        savedRound.setId(UUID.randomUUID());
        savedRound.setTournamentPolicyId(policyId);
        savedRound.setTournamentId(tournamentId);
        savedRound.setTournamentPolicyVersion(3);
        savedRound.setCourseId(1L);

        when(courseService.getCourse(1L)).thenReturn(course);
        when(golferAccountRepository.existsById(any())).thenReturn(true);
        when(tournamentService.getTournamentEntity(tournamentId)).thenReturn(tournament);
        when(tournamentPolicyService.getPolicy(policyId)).thenReturn(policy);
        when(roundRepository.save(any(Round.class))).thenReturn(savedRound);

        // When
        RoundResponse response = service.createRound(100L, request);

        // Then
        assertNotNull(response);
        assertEquals(policyId, response.getTournamentPolicyId());
        assertEquals(tournamentId, response.getTournamentId());
        assertEquals(3, response.getTournamentPolicyVersion());
        verify(tournamentPolicyService).lockPolicy(policyId, 0L);
    }

    @Test
    void createRound_withExplicitPolicyId_usesProvidedPolicy() {
        // Given
        UUID policyId = UUID.randomUUID();

        Course course = new Course();
        course.setId(1L);
        course.setName("Test Course");

        TournamentPolicyResponse policy = new TournamentPolicyResponse();
        policy.setId(policyId);
        policy.setVersion(5);

        RoundCreateRequest request = new RoundCreateRequest();
        request.setCourseId(1L);
        request.setTournamentPolicyId(policyId);
        // tournamentId is NOT set

        Round savedRound = new Round();
        savedRound.setId(UUID.randomUUID());
        savedRound.setTournamentPolicyId(policyId);
        savedRound.setTournamentPolicyVersion(5);

        when(courseService.getCourse(1L)).thenReturn(course);
        when(golferAccountRepository.existsById(any())).thenReturn(true);
        when(tournamentPolicyService.getPolicy(policyId)).thenReturn(policy);
        when(roundRepository.save(any(Round.class))).thenReturn(savedRound);

        // When
        RoundResponse response = service.createRound(100L, request);

        // Then
        assertNotNull(response);
        assertEquals(policyId, response.getTournamentPolicyId());
        assertEquals(5, response.getTournamentPolicyVersion());
        // tournamentService.getTournamentEntity should NOT be called
        verify(tournamentService, never()).getTournamentEntity(any());
    }

    @Test
    void createRound_casualRound_noPolicyIdSet() {
        // Given
        Course course = new Course();
        course.setId(1L);
        course.setName("Test Course");

        RoundCreateRequest request = new RoundCreateRequest();
        request.setCourseId(1L);
        // No tournamentId, no tournamentPolicyId

        Round savedRound = new Round();
        savedRound.setId(UUID.randomUUID());
        savedRound.setCourseId(1L);

        when(courseService.getCourse(1L)).thenReturn(course);
        when(golferAccountRepository.existsById(any())).thenReturn(true);
        when(roundRepository.save(any(Round.class))).thenReturn(savedRound);

        // When
        RoundResponse response = service.createRound(100L, request);

        // Then
        assertNotNull(response);
        assertNull(response.getTournamentPolicyId());
        assertNull(response.getTournamentId());
        verify(tournamentPolicyService, never()).lockPolicy(any(), any());
    }
}
