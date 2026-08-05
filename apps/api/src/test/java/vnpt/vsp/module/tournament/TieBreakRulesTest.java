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

/**
 * Tests for the LOWEST_ROUND, MOST_BIRDIES, and SCORECARD_PLAYOFF tie-break rules
 * implemented for Story 12.1 — verifying they actually reorder tied players and
 * assign distinct ranks.
 */
@ExtendWith(MockitoExtension.class)
class TieBreakRulesTest {

    @Mock private TieBreakRuleRepository tieBreakRuleRepository;
    @Mock private TournamentPlayerRepository playerRepository;

    private TieBreakServiceImpl service;
    private final UUID tournamentId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new TieBreakServiceImpl(tieBreakRuleRepository, playerRepository);
    }

    private TournamentResult result(Long playerId, int score) {
        Tournament t = new Tournament();
        t.setId(tournamentId);
        TournamentResult r = new TournamentResult();
        r.setId(UUID.randomUUID());
        r.setTournament(t);
        r.setPlayerId(playerId);
        r.setScore(score);
        return r;
    }

    private TieBreakRule rule(TieBreakRuleType type) {
        TieBreakRule r = new TieBreakRule();
        r.setId(UUID.randomUUID());
        r.setOrder(1);
        r.setRuleType(type);
        return r;
    }

    private TournamentResult find(List<TournamentResult> list, Long playerId) {
        return list.stream().filter(r -> r.getPlayerId().equals(playerId)).findFirst().orElseThrow();
    }

    @Test
    void lowestRound_lowerBestRoundWins() {
        TournamentResult p1 = result(1L, 72);
        p1.setBestRoundScore(35);
        TournamentResult p2 = result(2L, 72);
        p2.setBestRoundScore(34);
        List<TournamentResult> results = new ArrayList<>(List.of(p1, p2));

        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of(rule(TieBreakRuleType.LOWEST_ROUND)));

        List<TournamentResult> resolved = service.resolveTies(tournamentId, results);

        // Player 2 (lower best round) ranks ahead.
        assertEquals(2L, resolved.get(0).getPlayerId());
        assertEquals(1, find(resolved, 2L).getRank());
        assertEquals(2, find(resolved, 1L).getRank());
        assertTrue(find(resolved, 1L).isTieBreakApplied());
    }

    @Test
    void mostBirdies_moreBirdiesWins() {
        TournamentResult p1 = result(1L, 72);
        p1.setBirdieCount(2);
        TournamentResult p2 = result(2L, 72);
        p2.setBirdieCount(5);
        List<TournamentResult> results = new ArrayList<>(List.of(p1, p2));

        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of(rule(TieBreakRuleType.MOST_BIRDIES)));

        List<TournamentResult> resolved = service.resolveTies(tournamentId, results);

        assertEquals(2L, resolved.get(0).getPlayerId());
        assertEquals(1, find(resolved, 2L).getRank());
        assertEquals(2, find(resolved, 1L).getRank());
    }

    @Test
    void scorecardPlayoff_lowerBackNineWins() {
        // Both total 72; p2 has a lower back-9 (35 vs 36).
        String p1Holes = "4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4"; // back9 = 36
        String p2Holes = "5,4,4,4,4,4,4,4,4,3,4,4,4,4,4,4,4,4"; // front 37, back 35, total 72
        TournamentResult p1 = result(1L, 72);
        p1.setHoleScores(p1Holes);
        TournamentResult p2 = result(2L, 72);
        p2.setHoleScores(p2Holes);
        List<TournamentResult> results = new ArrayList<>(List.of(p1, p2));

        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of(rule(TieBreakRuleType.SCORECARD_PLAYOFF)));

        List<TournamentResult> resolved = service.resolveTies(tournamentId, results);

        assertEquals(2L, resolved.get(0).getPlayerId());
        assertEquals(1, find(resolved, 2L).getRank());
        assertEquals(2, find(resolved, 1L).getRank());
    }

    @Test
    void missingData_leavesPlayersTied() {
        // No best-round data on either player → rule is a no-op, players stay tied.
        TournamentResult p1 = result(1L, 72);
        TournamentResult p2 = result(2L, 72);
        List<TournamentResult> results = new ArrayList<>(List.of(p1, p2));

        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of(rule(TieBreakRuleType.LOWEST_ROUND)));

        List<TournamentResult> resolved = service.resolveTies(tournamentId, results);

        assertEquals(2, resolved.size());
        assertEquals(resolved.get(0).getRank(), resolved.get(1).getRank());
        assertFalse(resolved.get(0).isTieBreakApplied());
    }

    @Test
    void ruleChain_secondRuleBreaksWhatFirstLeftTied() {
        // Rule 1 (LOWEST_ROUND) can't separate (equal best rounds); rule 2 (MOST_BIRDIES) does.
        TournamentResult p1 = result(1L, 72);
        p1.setBestRoundScore(36);
        p1.setBirdieCount(1);
        TournamentResult p2 = result(2L, 72);
        p2.setBestRoundScore(36);
        p2.setBirdieCount(4);
        List<TournamentResult> results = new ArrayList<>(List.of(p1, p2));

        TieBreakRule r1 = rule(TieBreakRuleType.LOWEST_ROUND);
        r1.setOrder(1);
        TieBreakRule r2 = rule(TieBreakRuleType.MOST_BIRDIES);
        r2.setOrder(2);
        when(tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId))
                .thenReturn(List.of(r1, r2));

        List<TournamentResult> resolved = service.resolveTies(tournamentId, results);

        assertEquals(2L, resolved.get(0).getPlayerId());
        assertEquals(1, find(resolved, 2L).getRank());
    }
}
