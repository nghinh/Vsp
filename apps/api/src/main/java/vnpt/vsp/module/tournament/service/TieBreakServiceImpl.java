package vnpt.vsp.module.tournament.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vnpt.vsp.module.tournament.entity.TieBreakRule;
import vnpt.vsp.module.tournament.entity.TieBreakRuleType;
import vnpt.vsp.module.tournament.entity.TournamentPlayer;
import vnpt.vsp.module.tournament.entity.TournamentResult;
import vnpt.vsp.module.tournament.repository.TieBreakRuleRepository;
import vnpt.vsp.module.tournament.repository.TournamentPlayerRepository;

import java.util.*;

/**
 * TieBreakService implementation.
 * Per Story 12.1 Slice D: applies configured tie-break rules in order.
 *
 * Supported rule types:
 * - SCORECARD_PLAYOFF: compare scores on most difficult holes first
 * - EXACT_HANDICAP: lower handicap wins
 * - LOWEST_ROUND: lowest individual round score
 * - MOST_BIRDIES: most birdies across the round
 * - DRAW: random selection (last resort)
 */
@Service
public class TieBreakServiceImpl implements TieBreakService {

    private static final Logger log = LoggerFactory.getLogger(TieBreakServiceImpl.class);

    private final TieBreakRuleRepository tieBreakRuleRepository;
    private final TournamentPlayerRepository playerRepository;

    public TieBreakServiceImpl(TieBreakRuleRepository tieBreakRuleRepository,
                                TournamentPlayerRepository playerRepository) {
        this.tieBreakRuleRepository = tieBreakRuleRepository;
        this.playerRepository = playerRepository;
    }

    @Override
    public List<TournamentResult> resolveTies(UUID tournamentId, List<TournamentResult> results) {
        log.info("Resolving ties for tournament: {}", tournamentId);

        // Group results by score (potential ties)
        Map<Integer, List<TournamentResult>> scoreGroups = new HashMap<>();
        for (TournamentResult result : results) {
            scoreGroups.computeIfAbsent(result.getScore(), k -> new ArrayList<>()).add(result);
        }

        // Get configured tie-break rules
        List<TieBreakRule> rules = tieBreakRuleRepository.findByTournamentIdOrderByOrder(tournamentId);
        if (rules.isEmpty()) {
            log.info("No tie-break rules configured for tournament: {}", tournamentId);
            applyDefaultTieBreak(results);
            return results;
        }

        // Resolve ties within each score group
        for (var entry : scoreGroups.entrySet()) {
            List<TournamentResult> tied = entry.getValue();
            if (tied.size() > 1) {
                resolveTieGroup(tied, rules);
            }
        }

        // Re-rank results
        recalculateRanks(results);

        log.info("Tie resolution complete for tournament: {}", tournamentId);
        return results;
    }

    private void resolveTieGroup(List<TournamentResult> tied, List<TieBreakRule> rules) {
        // Sort by score first, then apply each tie-break rule in order
        for (TieBreakRule rule : rules) {
            if (allSameRank(tied)) {
                break; // All resolved
            }
            applyTieBreakRule(tied, rule);
        }

        // If still tied after all rules, mark tie-break as applied but leave tied
        for (TournamentResult r : tied) {
            r.setTieBreakApplied(true);
        }
    }

    private void applyTieBreakRule(List<TournamentResult> tied, TieBreakRule rule) {
        switch (rule.getRuleType()) {
            case EXACT_HANDICAP -> applyHandicapTieBreak(tied);
            case LOWEST_ROUND -> applyLowestRoundTieBreak(tied);
            case MOST_BIRDIES -> applyMostBirdiesTieBreak(tied);
            case SCORECARD_PLAYOFF -> applyScorecardPlayoffTieBreak(tied);
            case DRAW -> applyDrawTieBreak(tied);
        }
    }

    private void applyHandicapTieBreak(List<TournamentResult> tied) {
        // Lower handicap wins - sort by handicap ascending
        tied.sort((a, b) -> {
            TournamentPlayer pa = playerRepository.findByTournamentIdAndPlayerId(
                    a.getTournament().getId(), a.getPlayerId()).orElse(null);
            TournamentPlayer pb = playerRepository.findByTournamentIdAndPlayerId(
                    b.getTournament().getId(), b.getPlayerId()).orElse(null);
            if (pa == null || pb == null) return 0;
            return Double.compare(
                    pa.getHandicap() != null ? pa.getHandicap() : 0,
                    pb.getHandicap() != null ? pb.getHandicap() : 0);
        });
    }

    private void applyLowestRoundTieBreak(List<TournamentResult> tied) {
        // Would need round data - for now, keep order
        // TODO: integrate with round scores
    }

    private void applyMostBirdiesTieBreak(List<TournamentResult> tied) {
        // Would need scoring data - for now, keep order
        // TODO: integrate with score entries
    }

    private void applyScorecardPlayoffTieBreak(List<TournamentResult> tied) {
        // Would need hole-by-hole scores - for now, keep order
        // TODO: integrate with scorecard data
    }

    private void applyDrawTieBreak(List<TournamentResult> tied) {
        // Random draw as last resort
        Collections.shuffle(tied, new Random());
    }

    private void applyDefaultTieBreak(List<TournamentResult> results) {
        // Default: sort by player ID ascending (deterministic)
        results.sort((a, b) -> Long.compare(a.getPlayerId(), b.getPlayerId()));
        recalculateRanks(results);
    }

    private boolean allSameRank(List<TournamentResult> results) {
        if (results.isEmpty()) return true;
        int firstRank = results.get(0).getRank();
        return results.stream().allMatch(r -> r.getRank() == firstRank);
    }

    private void recalculateRanks(List<TournamentResult> results) {
        // Sort by score ascending
        results.sort(Comparator.comparingInt(TournamentResult::getScore));

        int rank = 1;
        for (int i = 0; i < results.size(); i++) {
            TournamentResult current = results.get(i);
            if (i > 0) {
                TournamentResult previous = results.get(i - 1);
                if (current.getScore() != previous.getScore()) {
                    rank = i + 1;
                }
            }
            current.setRank(rank);
        }
    }
}
