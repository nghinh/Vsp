package vnpt.vsp.module.shot.dto;

import java.util.List;

/**
 * Response DTO for listing shots with sync cursor.
 * Per Story 10.3 Slice 1.
 */
public record ShotListResponse(
        List<ShotDto> shots,
        String cursor,
        boolean hasMore
) {}
