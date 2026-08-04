package vnpt.vsp.module.tournament.service;

import vnpt.vsp.module.tournament.entity.TournamentResult;

import java.util.List;
import java.util.UUID;

/**
 * Service interface for tie-break resolution.
 * Per Story 12.1 Slice D: applies configured tie-break rules in order.
 */
public interface TieBreakService {

    /**
     * Resolves ties in a list of tournament results by applying configured tie-break rules.
     *
     * @param tournamentId the tournament UUID
     * @param results mutable list of results (will be modified in place)
     * @return the same list with ranks adjusted for tied players
     */
    List<TournamentResult> resolveTies(UUID tournamentId, List<TournamentResult> results);
}
