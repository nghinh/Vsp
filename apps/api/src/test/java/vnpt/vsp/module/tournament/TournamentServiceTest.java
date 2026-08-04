// TournamentService Test — VSP API
//
// Per Story 12.1 Slice I: unit tests for TournamentService
//
// Tests:
// - Happy path: create tournament, register players, create flights, tee times
// - Negative: create with missing required fields, modify after inProgress

package vnpt.vsp.module.tournament;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.tournament.dto.*;
import vnpt.vsp.module.tournament.entity.*;
import vnpt.vsp.module.tournament.repository.*;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class TournamentServiceTest {

    @Mock private TournamentRepository tournamentRepository;
    @Mock private TournamentPlayerRepository playerRepository;
    @Mock private FlightRepository flightRepository;
    @Mock private TeeTimeRepository teeTimeRepository;
    @Mock private TournamentResultRepository resultRepository;
    @Mock private TieBreakRuleRepository tieBreakRuleRepository;

    private TournamentServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new TournamentServiceImpl(
                tournamentRepository,
                playerRepository,
                flightRepository,
                teeTimeRepository,
                resultRepository,
                tieBreakRuleRepository
        );
    }

    // ─── createTournament ────────────────────────────────────────────────

    @Test
    void createTournament_withValidRequest_createsTournament() {
        // Given
        TournamentCreateRequest request = new TournamentCreateRequest();
        request.setName("Club Championship 2026");
        request.setFormat(TournamentFormat.STROKE_PLAY);
        request.setCourseId(1L);
        request.setStartDate(Instant.parse("2026-09-01T00:00:00Z"));
        request.setEndDate(Instant.parse("2026-09-02T23:59:59Z"));

        UUID savedId = UUID.randomUUID();
        Tournament saved = new Tournament();
        saved.setId(savedId);
        saved.setName("Club Championship 2026");
        saved.setFormat(TournamentFormat.STROKE_PLAY);
        saved.setStatus(TournamentStatus.DRAFT);

        when(tournamentRepository.save(any(Tournament.class))).thenReturn(saved);

        // When
        TournamentResponse response = service.createTournament(request, 100L);

        // Then
        assertNotNull(response);
        assertEquals(savedId, response.getId());
        assertEquals("Club Championship 2026", response.getName());
        assertEquals("DRAFT", response.getStatus());
        verify(tournamentRepository).save(any(Tournament.class));
    }

    // ─── getTournament ──────────────────────────────────────────────────

    @Test
    void getTournament_existingId_returnsTournament() {
        // Given
        UUID id = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(id);
        tournament.setName("Test Tournament");
        tournament.setFormat(TournamentFormat.STROKE_PLAY);
        tournament.setStatus(TournamentStatus.DRAFT);

        when(tournamentRepository.findById(id)).thenReturn(Optional.of(tournament));

        // When
        TournamentResponse response = service.getTournament(id);

        // Then
        assertNotNull(response);
        assertEquals(id, response.getId());
        assertEquals("Test Tournament", response.getName());
    }

    @Test
    void getTournament_nonExistingId_throws() {
        // Given
        UUID id = UUID.randomUUID();
        when(tournamentRepository.findById(id)).thenReturn(Optional.empty());

        // When / Then
        assertThrows(VspApiException.class, () -> service.getTournament(id));
    }

    // ─── openRegistration ───────────────────────────────────────────────

    @Test
    void openRegistration_draftTournament_setsStatusToRegistrationOpen() {
        // Given
        UUID id = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(id);
        tournament.setName("Test");
        tournament.setStatus(TournamentStatus.DRAFT);
        tournament.setFormat(TournamentFormat.STROKE_PLAY);

        when(tournamentRepository.findById(id)).thenReturn(Optional.of(tournament));
        when(tournamentRepository.save(any(Tournament.class))).thenAnswer(i -> i.getArgument(0));

        // When
        service.openRegistration(id);

        // Then
        verify(tournamentRepository).save(argThat(t -> t.getStatus() == TournamentStatus.REGISTRATION_OPEN));
    }

    @Test
    void openRegistration_nonDraft_throws() {
        // Given
        UUID id = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(id);
        tournament.setStatus(TournamentStatus.IN_PROGRESS);

        when(tournamentRepository.findById(id)).thenReturn(Optional.of(tournament));

        // When / Then
        assertThrows(VspApiException.class, () -> service.openRegistration(id));
    }

    // ─── startTournament ────────────────────────────────────────────────

    @Test
    void startTournament_withRegisteredPlayers_setsStatusToInProgress() {
        // Given
        UUID id = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(id);
        tournament.setStatus(TournamentStatus.REGISTRATION_OPEN);

        TournamentPlayer player = new TournamentPlayer();
        player.setId(UUID.randomUUID());

        tournament.setPlayers(List.of(player));
        when(tournamentRepository.findById(id)).thenReturn(Optional.of(tournament));
        when(playerRepository.findByTournamentId(id)).thenReturn(List.of(player));
        when(tournamentRepository.save(any(Tournament.class))).thenAnswer(i -> i.getArgument(0));

        // When
        service.startTournament(id);

        // Then
        verify(tournamentRepository).save(argThat(t -> t.getStatus() == TournamentStatus.IN_PROGRESS));
    }

    // ─── registerPlayer ──────────────────────────────────────────────────

    @Test
    void registerPlayer_validPlayer_createsPlayerRecord() {
        // Given
        UUID tournamentId = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);
        tournament.setStatus(TournamentStatus.REGISTRATION_OPEN);

        TournamentPlayer saved = new TournamentPlayer();
        saved.setId(UUID.randomUUID());
        saved.setTournament(tournament);
        saved.setPlayerId(42L);
        saved.setStatus(TournamentPlayerStatus.REGISTERED);

        when(tournamentRepository.findById(tournamentId)).thenReturn(Optional.of(tournament));
        when(playerRepository.save(any(TournamentPlayer.class))).thenReturn(saved);

        // When
        TournamentPlayerResponse response = service.registerPlayer(tournamentId, 42L, 5.0);

        // Then
        assertNotNull(response);
        assertEquals(42L, response.getPlayerId());
        assertEquals("REGISTERED", response.getStatus());
    }

    // ─── listTournaments ─────────────────────────────────────────────────

    @Test
    void listTournaments_noFilter_returnsAll() {
        // Given
        Tournament t1 = new Tournament();
        t1.setId(UUID.randomUUID());
        t1.setName("Tournament 1");
        t1.setFormat(TournamentFormat.STROKE_PLAY);
        t1.setStatus(TournamentStatus.DRAFT);

        Tournament t2 = new Tournament();
        t2.setId(UUID.randomUUID());
        t2.setName("Tournament 2");
        t2.setFormat(TournamentFormat.MATCH_PLAY);
        t2.setStatus(TournamentStatus.REGISTRATION_OPEN);

        when(tournamentRepository.findAll()).thenReturn(List.of(t1, t2));

        // When
        List<TournamentResponse> result = service.listTournaments(null, null);

        // Then
        assertEquals(2, result.size());
    }

    // ─── createFlight ────────────────────────────────────────────────────

    @Test
    void createFlight_withValidRequest_createsFlight() {
        // Given
        UUID tournamentId = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);
        tournament.setStatus(TournamentStatus.REGISTRATION_OPEN);

        FlightCreateRequest request = new FlightCreateRequest();
        request.setFlightNumber(1);
        request.setStartingTee(StartingTee.FRONT);

        Flight saved = new Flight();
        saved.setId(UUID.randomUUID());
        saved.setTournament(tournament);
        saved.setFlightNumber(1);
        saved.setStartingTee(StartingTee.FRONT);

        when(tournamentRepository.findById(tournamentId)).thenReturn(Optional.of(tournament));
        when(flightRepository.save(any(Flight.class))).thenReturn(saved);

        // When
        FlightResponse response = service.createFlight(tournamentId, request);

        // Then
        assertNotNull(response);
        assertEquals(1, response.getFlightNumber());
    }

    // ─── getLeaderboard ──────────────────────────────────────────────────

    @Test
    void getLeaderboard_existingTournament_returnsLeaderboard() {
        // Given
        UUID tournamentId = UUID.randomUUID();
        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);
        tournament.setLeaderboardVersion(5);

        when(tournamentRepository.findById(tournamentId)).thenReturn(Optional.of(tournament));

        // When
        LeaderboardResponse response = service.getLeaderboard(tournamentId);

        // Then
        assertNotNull(response);
        assertEquals(tournamentId, response.getTournamentId());
        assertEquals(5, response.getVersion());
    }
}
