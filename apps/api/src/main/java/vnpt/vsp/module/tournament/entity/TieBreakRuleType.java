package vnpt.vsp.module.tournament.entity;

/**
 * Tie-break rule type enumeration.
 * Per Story 12.1: scorecardPlayoff, exactHandicap, lowestRound, mostBirdies, draw.
 */
public enum TieBreakRuleType {
    SCORECARD_PLAYOFF,
    EXACT_HANDICAP,
    LOWEST_ROUND,
    MOST_BIRDIES,
    DRAW
}
