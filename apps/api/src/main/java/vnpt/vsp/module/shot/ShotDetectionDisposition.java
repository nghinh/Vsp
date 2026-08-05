package vnpt.vsp.module.shot;

import java.math.BigDecimal;

/**
 * Disposition applied to an automatic shot-detection candidate based on its
 * confidence score.
 *
 * <p>Per Story 10.4: Detect Shots with Confidence — "Confidence thresholds
 * determine automatic, review-later, confirm, or discard behavior."
 *
 * <p>The multi-signal sensor fusion (accelerometer, gyroscope, GPS, time,
 * hole context) that produces the confidence score runs on-device (see the
 * mobile {@code shot_detection} domain). The API is the authoritative owner of
 * the threshold policy so that server and client stay in agreement and the
 * disposition is auditable.
 *
 * <p>Confidence boundaries (inclusive-lower, exclusive-upper):
 * <ul>
 *   <li>{@code [0.00, 0.20)} → {@link #DISCARD} — not a shot; dropped, nothing persisted.</li>
 *   <li>{@code [0.20, 0.50)} → {@link #REVIEW_LATER} — persisted silently for later review.</li>
 *   <li>{@code [0.50, 0.75)} → {@link #CONFIRM} — persisted; client should prompt the golfer.</li>
 *   <li>{@code [0.75, 1.00]} → {@link #AUTOMATIC} — persisted and treated as confirmed.</li>
 * </ul>
 */
public enum ShotDetectionDisposition {
    DISCARD,
    REVIEW_LATER,
    CONFIRM,
    AUTOMATIC;

    /** Upper bound (exclusive) of the discard band. */
    public static final BigDecimal DISCARD_MAX = new BigDecimal("0.20");
    /** Upper bound (exclusive) of the review-later band. */
    public static final BigDecimal REVIEW_LATER_MAX = new BigDecimal("0.50");
    /** Upper bound (exclusive) of the confirm band. */
    public static final BigDecimal CONFIRM_MAX = new BigDecimal("0.75");

    /**
     * Resolve the disposition for a given confidence score in [0.0, 1.0].
     *
     * @param confidence confidence score; {@code null} is treated as 0.0 (discard).
     * @return the disposition band the score falls into.
     */
    public static ShotDetectionDisposition forConfidence(BigDecimal confidence) {
        BigDecimal c = confidence != null ? confidence : BigDecimal.ZERO;
        if (c.compareTo(DISCARD_MAX) < 0) return DISCARD;
        if (c.compareTo(REVIEW_LATER_MAX) < 0) return REVIEW_LATER;
        if (c.compareTo(CONFIRM_MAX) < 0) return CONFIRM;
        return AUTOMATIC;
    }

    /**
     * Whether a candidate with this disposition should be persisted as a
     * {@code detected} shot. {@link #DISCARD} candidates are never persisted.
     */
    public boolean shouldPersist() {
        return this != DISCARD;
    }
}
