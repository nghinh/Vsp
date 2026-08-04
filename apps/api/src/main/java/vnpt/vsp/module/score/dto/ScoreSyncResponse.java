package vnpt.vsp.module.score.dto;

import java.util.List;
import java.util.UUID;

/**
 * Response DTO for batch score sync.
 *
 * Per Story 5.4 AC2: server deduplicates, client needs per-score result.
 *
 * @param roundId       round these results belong to
 * @param syncedScores  list of score IDs that were successfully synced
 * @param failedScores  scores that could not be synced (client error, data issue)
 */
public record ScoreSyncResponse(
        UUID roundId,
        List<SyncedScoreEntry> syncedScores,
        List<FailedScoreEntry> failedScores
) {

    public record SyncedScoreEntry(
            UUID scoreId,
            int version
    ) {}

    public record FailedScoreEntry(
            UUID scoreId,
            String reason
    ) {}
}
