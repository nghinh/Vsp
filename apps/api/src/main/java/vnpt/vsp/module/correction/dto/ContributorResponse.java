package vnpt.vsp.module.correction.dto;

import java.time.LocalDate;

/**
 * One person who filled in course data, and how much of it.
 *
 * <p>Display name only: the account behind a contribution also holds a phone
 * number and an email, and neither belongs on a leaderboard.
 */
public record ContributorResponse(
        String displayName,
        int approvedCorrections,
        int coursesCovered,
        LocalDate lastContributedOn) {}
