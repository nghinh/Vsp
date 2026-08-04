// TieBreakService Test — VSP API
//
// Per Story 12.1 Slice I: unit tests for TieBreakService
//
// Tests:
// - resolveTies with no ties
// - resolveTies with configured tie-break rules

package vnpt.vsp.module.tournament;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.tournament.entity.*;
import vnpt.vsp.module.tournament.repository.*;
import vnpt.vsp.module.tournament.service.TieBreakServiceImpl;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TieBreakServiceTest {

    @Mock private TieBreakRuleRepository tieBreakRuleRepository;
    @Mock private TournamentPlayerRepository playerRepository;

    private TieBreakServiceImpl tieBreakService;

    @BeforeEach
    void setUp() {
        tieBreakService = new TieBreakServiceImpl(tieBreakRuleRepository, playerRepository);
    }

    private TournamentResult makeResult(UUID tournamentId, Long playerId, int score) {
        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);

        TournamentResult result = new TournamentResult();
        result.setId(UUID.randomUUID());
        result.setTournament(tournament);
        result.setPlayerId(playerId);
        result.setScore(score);
        result.setRank(0);
        result.setTieBreakApplied(false);
        return result;
    }

    @Test
    void resolveTies_noTies_returnsUnchanged() {
        UUID tournamentId = UUID.randomUUID();

        List<TournamentResult> results = new ArrayList<>();
        results.add(makeResult(tournamentId, 1L, 70));
        results.add(makeResult(tournamentId, 2L, 75));

        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of());

        List<TournamentResult> resolved = tieBreakService.resolveTies(tournamentId, results);

        assertEquals(2, resolved.size());
        assertEquals(70, resolved.get(0).getScore());
        assertEquals(75, resolved.get(1).getScore());
    }

    @Test
    void resolveTies_withTiesAndNoRules_appliesDefaultTieBreak() {
        UUID tournamentId = UUID.randomUUID();

        List<TournamentResult> results = new ArrayList<>();
        results.add(makeResult(tournamentId, 1L, 72));
        results.add(makeResult(tournamentId, 2L, 72));

        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of());

        List<TournamentResult> resolved = tieBreakService.resolveTies(tournamentId, results);

        assertEquals(2, resolved.size());
        // Default tie-break: sorted by player ID ascending
        assertEquals(1L, resolved.get(0).getPlayerId());
        assertEquals(2L, resolved.get(1).getPlayerId());
    }

    @Test
    void resolveTies_withExactHandicapRule_fetchesPlayerHandicaps() {
        // EXACT_HANDICAP resolves ties by looking up each player's handicap.
        // The allSameRank guard prevents re-application to already-ranked groups.
        // To trigger the rule, results start with different ranks.
        UUID tournamentId = UUID.randomUUID();

        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);

        TournamentResult result1 = makeResult(tournamentId, 1L, 72);
        result1.setRank(1);
        TournamentResult result2 = makeResult(tournamentId, 2L, 72);
        result2.setRank(2); // Different rank bypasses allSameRank guard

        TournamentPlayer player1 = new TournamentPlayer();
        player1.setId(UUID.randomUUID());
        player1.setTournament(tournament);
        player1.setPlayerId(1L);
        player1.setHandicap(5.0);

        TournamentPlayer player2 = new TournamentPlayer();
        player2.setId(UUID.randomUUID());
        player2.setTournament(tournament);
        player2.setPlayerId(2L);
        player2.setHandicap(3.0);

        TieBreakRule rule = new TieBreakRule();
        rule.setId(UUID.randomUUID());
        rule.setTournament(tournament);
        rule.setOrder(1);
        rule.setRuleType(TieBreakRuleType.EXACT_HANDICAP);

        List<TournamentResult> results = new ArrayList<>();
        results.add(result1);
        results.add(result2);

        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of(rule));
        when(playerRepository.findByTournamentIdAndPlayerId(tournamentId, 1L))
                .thenReturn(Optional.of(player1));
        when(playerRepository.findByTournamentIdAndPlayerId(tournamentId, 2L))
                .thenReturn(Optional.of(player2));

        tieBreakService.resolveTies(tournamentId, results);

        // Verify the service fetched both players' handicap data from repository
        verify(playerRepository).findByTournamentIdAndPlayerId(tournamentId, 1L);
        verify(playerRepository).findByTournamentIdAndPlayerId(tournamentId, 2L);
    }

    @Test
    void resolveTies_withDrawRule_doesNotThrow() {
        UUID tournamentId = UUID.randomUUID();

        List<TournamentResult> results = new ArrayList<>();
        results.add(makeResult(tournamentId, 1L, 72));
        results.add(makeResult(tournamentId, 2L, 72));

        Tournament tournament = new Tournament();
        tournament.setId(tournamentId);

        TieBreakRule rule = new TieBreakRule();
        rule.setId(UUID.randomUUID());
        rule.setTournament(tournament);
        rule.setOrder(1);
        rule.setRuleType(TieBreakRuleType.DRAW);

        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of(rule));

        // DRAW just shuffles — should not throw
        List<TournamentResult> resolved = tieBreakService.resolveTies(tournamentId, results);

        assertNotNull(resolved);
        assertEquals(2, resolved.size());
    }
}
