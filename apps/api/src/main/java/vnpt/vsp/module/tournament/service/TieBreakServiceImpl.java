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
 * <p>Supported rule types, applied as a lexicographic chain in configured order
 * (an earlier rule's decision is kept; a later rule only separates entries the
 * earlier rules left equal):
 * <ul>
 *   <li>{@code EXACT_HANDICAP} — lower exact handicap wins (from TournamentPlayer).</li>
 *   <li>{@code LOWEST_ROUND} — lowest single-round gross score wins
 *       ({@link TournamentResult#getBestRoundScore()}).</li>
 *   <li>{@code MOST_BIRDIES} — most birdies (or better) wins
 *       ({@link TournamentResult#getBirdieCount()}).</li>
 *   <li>{@code SCORECARD_PLAYOFF} — USGA-style countback over the hole-by-hole
 *       scores ({@link TournamentResult#getHoleScores()}): back 9, 6, 3, then last hole.</li>
 *   <li>{@code DRAW} — random draw, applied last to any entries still tied.</li>
 * </ul>
 *
 * <p>Rules needing detail absent from the result (null {@code bestRoundScore},
 * {@code birdieCount}, or {@code holeScores}) treat those entries as tied and defer to
 * the next rule. Populating that scorecard detail is owned by the scoring/round-sync
 * path and is out of scope for this module.
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

        // Rebuild results so the resolved intra-group order is reflected in the
        // final standings (ascending score, tie-break order within each score).
        List<TournamentResult> ordered = new ArrayList<>();
        scoreGroups.keySet().stream().sorted().forEach(score -> ordered.addAll(scoreGroups.get(score)));
        results.clear();
        results.addAll(ordered);

        assignRanksPreservingOrder(results);

        log.info("Tie resolution complete for tournament: {}", tournamentId);
        return results;
    }

    /**
     * Orders a tied group by the configured rule chain. Non-DRAW rules form a
     * lexicographic comparator; a DRAW rule (if present) randomly separates any
     * entries still equal after the comparator chain.
     */
    private void resolveTieGroup(List<TournamentResult> tied, List<TieBreakRule> rules) {
        Comparator<TournamentResult> chain = null;
        boolean hasDraw = false;
        for (TieBreakRule rule : rules) {
            if (rule.getRuleType() == TieBreakRuleType.DRAW) {
                hasDraw = true;
                continue;
            }
            Comparator<TournamentResult> c = comparatorFor(rule.getRuleType(), tied);
            chain = (chain == null) ? c : chain.thenComparing(c);
        }

        boolean separated = false;
        if (chain != null) {
            separated = differentiatesAny(tied, chain);
            tied.sort(chain);
        }
        if (hasDraw) {
            boolean drawSeparated = shuffleStillTied(tied, chain);
            separated = separated || drawSeparated;
        }

        if (separated) {
            for (TournamentResult r : tied) {
                r.setTieBreakApplied(true);
            }
        }
    }

    private Comparator<TournamentResult> comparatorFor(TieBreakRuleType type, List<TournamentResult> tied) {
        return switch (type) {
            case EXACT_HANDICAP -> handicapComparator(tied);
            case LOWEST_ROUND -> nullsLastInt(TournamentResult::getBestRoundScore);
            case MOST_BIRDIES -> birdieComparator();
            case SCORECARD_PLAYOFF -> countbackComparator();
            case DRAW -> (a, b) -> 0; // handled separately
        };
    }

    private boolean differentiatesAny(List<TournamentResult> tied, Comparator<TournamentResult> cmp) {
        for (int i = 0; i < tied.size(); i++) {
            for (int j = i + 1; j < tied.size(); j++) {
                if (cmp.compare(tied.get(i), tied.get(j)) != 0) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Randomly shuffles any maximal runs of entries that are still equal under the
     * comparator chain (or the whole group when there is no chain).
     *
     * @return true if any run of size &gt; 1 was shuffled.
     */
    private boolean shuffleStillTied(List<TournamentResult> tied, Comparator<TournamentResult> chain) {
        Random random = new Random();
        if (chain == null) {
            if (tied.size() > 1) {
                Collections.shuffle(tied, random);
                return true;
            }
            return false;
        }
        boolean shuffled = false;
        int i = 0;
        while (i < tied.size()) {
            int j = i + 1;
            while (j < tied.size() && chain.compare(tied.get(j - 1), tied.get(j)) == 0) {
                j++;
            }
            if (j - i > 1) {
                List<TournamentResult> sub = new ArrayList<>(tied.subList(i, j));
                Collections.shuffle(sub, random);
                for (int k = i; k < j; k++) {
                    tied.set(k, sub.get(k - i));
                }
                shuffled = true;
            }
            i = j;
        }
        return shuffled;
    }

    // ─── Rule comparators ──────────────────────────────────────────────────

    private Comparator<TournamentResult> handicapComparator(List<TournamentResult> tied) {
        // Pre-fetch and cache each distinct player's handicap so the comparator is
        // consistent and issues one query per player.
        Map<Long, Double> handicaps = new HashMap<>();
        for (TournamentResult r : tied) {
            handicaps.computeIfAbsent(r.getPlayerId(), pid -> {
                TournamentPlayer p = playerRepository
                        .findByTournamentIdAndPlayerId(r.getTournament().getId(), pid)
                        .orElse(null);
                return (p != null && p.getHandicap() != null) ? p.getHandicap() : Double.MAX_VALUE;
            });
        }
        return Comparator.comparingDouble(r -> handicaps.getOrDefault(r.getPlayerId(), Double.MAX_VALUE));
    }

    private Comparator<TournamentResult> nullsLastInt(java.util.function.Function<TournamentResult, Integer> key) {
        return Comparator.comparingInt(r -> {
            Integer v = key.apply(r);
            return v != null ? v : Integer.MAX_VALUE;
        });
    }

    private Comparator<TournamentResult> birdieComparator() {
        // More birdies wins → descending; null treated as 0.
        return Comparator.comparingInt((TournamentResult r) ->
                r.getBirdieCount() != null ? r.getBirdieCount() : 0).reversed();
    }

    /**
     * USGA countback: compare cumulative totals over the last 9, 6, 3, then final
     * hole; lower total wins. Missing hole detail sorts last.
     */
    private Comparator<TournamentResult> countbackComparator() {
        return (a, b) -> {
            int[] sa = parseHoleScores(a.getHoleScores());
            int[] sb = parseHoleScores(b.getHoleScores());
            if (sa.length == 0 && sb.length == 0) return 0;
            if (sa.length == 0) return 1;
            if (sb.length == 0) return -1;
            for (int back : new int[]{9, 6, 3, 1}) {
                int cmp = Integer.compare(tailSum(sa, back), tailSum(sb, back));
                if (cmp != 0) return cmp;
            }
            return 0;
        };
    }

    private int[] parseHoleScores(String csv) {
        if (csv == null || csv.isBlank()) return new int[0];
        String[] parts = csv.split(",");
        int[] out = new int[parts.length];
        for (int i = 0; i < parts.length; i++) {
            try {
                out[i] = Integer.parseInt(parts[i].trim());
            } catch (NumberFormatException e) {
                return new int[0];
            }
        }
        return out;
    }

    private int tailSum(int[] scores, int n) {
        int from = Math.max(0, scores.length - n);
        int sum = 0;
        for (int i = from; i < scores.length; i++) sum += scores[i];
        return sum;
    }

    // ─── Ranking ───────────────────────────────────────────────────────────

    private void applyDefaultTieBreak(List<TournamentResult> results) {
        // Default: ascending score, then ascending player ID (deterministic).
        results.sort(Comparator.comparingInt(TournamentResult::getScore)
                .thenComparing(TournamentResult::getPlayerId));
        recalculateRanks(results);
    }

    /**
     * Assigns competition ranks (1,2,2,4 style) from the current list order. Since
     * tie-break has ordered the list, adjacent entries with equal score share a rank
     * only when neither was tie-broken; otherwise ranks are sequential.
     */
    private void assignRanksPreservingOrder(List<TournamentResult> results) {
        for (int i = 0; i < results.size(); i++) {
            TournamentResult current = results.get(i);
            if (i == 0) {
                current.setRank(1);
                continue;
            }
            TournamentResult previous = results.get(i - 1);
            boolean shareRank = current.getScore() == previous.getScore()
                    && !current.isTieBreakApplied()
                    && !previous.isTieBreakApplied();
            current.setRank(shareRank ? previous.getRank() : i + 1);
        }
    }

    private void recalculateRanks(List<TournamentResult> results) {
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
