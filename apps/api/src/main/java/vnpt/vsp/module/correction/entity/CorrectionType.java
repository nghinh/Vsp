package vnpt.vsp.module.correction.entity;

/**
 * Types of course data that can be corrected by a golfer.
 *
 * <p>This enum intentionally covers a superset of plausible correction types so
 * that the mobile submission flow (Story 9.1) and the portal review flow
 * (Story 9.2) can align without coordination.  The portal UI only renders
 * the types that are actually submitted.</p>
 *
 * Per Story 9.2 Open Question: align enum values with Story 9.1 output.
 */
public enum CorrectionType {
    GEOMETRY,
    PIN_POSITION,
    BUNKER,
    WATER,
    OB,
    CART_PATH,
    LANDMARK,
    COURSE_CONDITION,
    GREEN_SPEED,

    /// A club's printed card: par and stroke index for a whole pairing of
    /// đường, submitted as one photograph and reviewed as one decision.
    SCORECARD,

    OTHER
}
