package vnpt.vsp.module.shot.dto;

import vnpt.vsp.module.shot.ShotDetectionDisposition;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Response DTO for a shot-detection candidate.
 *
 * <p>Per Story 10.4. Reports the {@link ShotDetectionDisposition} the API
 * assigned based on the confidence score. For persisted dispositions
 * ({@code REVIEW_LATER}, {@code CONFIRM}, {@code AUTOMATIC}) the created
 * {@code detected} shot and its event id are included; for {@code DISCARD}
 * both are {@code null} (nothing was persisted).
 *
 * @param disposition the disposition applied
 * @param confidence  the confidence score echoed back
 * @param persisted   whether a shot was persisted
 * @param shot        the persisted shot, or {@code null} for {@code DISCARD}
 * @param eventId     the persisted shot event id, or {@code null} for {@code DISCARD}
 */
public record ShotDetectionResponse(
        ShotDetectionDisposition disposition,
        BigDecimal confidence,
        boolean persisted,
        ShotDto shot,
        UUID eventId
) {
    public static ShotDetectionResponse discarded(BigDecimal confidence) {
        return new ShotDetectionResponse(ShotDetectionDisposition.DISCARD, confidence, false, null, null);
    }

    public static ShotDetectionResponse persisted(ShotDetectionDisposition disposition,
                                                  BigDecimal confidence,
                                                  ShotDto shot,
                                                  UUID eventId) {
        return new ShotDetectionResponse(disposition, confidence, true, shot, eventId);
    }
}
