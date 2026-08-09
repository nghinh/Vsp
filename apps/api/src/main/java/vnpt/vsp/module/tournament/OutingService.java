package vnpt.vsp.module.tournament;

import vnpt.vsp.module.tournament.dto.OutingResultsResponse;
import vnpt.vsp.module.tournament.dto.OutingRosterEntryRequest;
import vnpt.vsp.module.tournament.dto.ScoreEntryRequest;
import vnpt.vsp.module.tournament.dto.TechnicalEntryRequest;
import vnpt.vsp.module.tournament.dto.TechnicalEntryResponse;
import vnpt.vsp.module.tournament.dto.TournamentPlayerResponse;
import vnpt.vsp.module.tournament.scoring.OutingRules;

import java.util.List;
import java.util.UUID;

/**
 * Running a club outing: the rules, the roster, the scores, the prize table.
 *
 * The shape of this interface follows the day rather than the data model. An
 * organiser configures the rules and imports the roster in the week before;
 * on the day the only calls that happen are {@link #saveScores} once per
 * flight and {@link #results} on repeat, and both of those need to be quick
 * enough to run while people are queuing for lunch.
 */
public interface OutingService {

    /** This outing's rules, or the transcribed default when none are set. */
    OutingRules getRules(UUID tournamentId);

    /** Replace this outing's rules. */
    OutingRules saveRules(UUID tournamentId, OutingRules rules, Long actorId);

    /**
     * Replace the roster.
     *
     * Whole-list rather than per-player because that is how it arrives: an
     * organiser pastes the flight sheet, sees what parsed, and pastes it again
     * when a name is wrong. Players already holding scores keep them, matched
     * on VGA code and then on name.
     */
    List<TournamentPlayerResponse> importRoster(
            UUID tournamentId, List<OutingRosterEntryRequest> entries, Long actorId);

    /** The roster, in flight then name order. */
    List<TournamentPlayerResponse> roster(UUID tournamentId);

    /**
     * Save scores for a batch of players — normally one flight's four cards.
     *
     * Batched per flight so two people can type two flights at once without
     * either overwriting the other, and so a save is one request rather than
     * seventy-two.
     */
    List<TournamentPlayerResponse> saveScores(
            UUID tournamentId, List<ScoreEntryRequest> entries, Long actorId);

    /** Measurements already recorded, so the board can be reopened. */
    List<TechnicalEntryResponse> technicalEntries(UUID tournamentId);

    /** Record nearest-to-pin and longest-drive measurements. */
    void saveTechnicalEntries(
            UUID tournamentId, List<TechnicalEntryRequest> entries, Long actorId);

    /**
     * The prize table, computed from whatever has been entered so far.
     *
     * Read-only and safe to call repeatedly — this is what the leaderboard
     * screen polls while the flights are still coming in.
     */
    OutingResultsResponse results(UUID tournamentId);

    /**
     * Freeze the prize table into tournament_results and publish it.
     *
     * Separate from {@link #results} because the two answer different
     * questions: results says "what would the prizes be right now", publish
     * says "these are the prizes". Only the second is quotable.
     */
    OutingResultsResponse publish(UUID tournamentId, Long actorId);
}
