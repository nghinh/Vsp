package vnpt.vsp.module.audit;

/**
 * Enumerates every auditable admin and course-data mutation in the platform.
 * <p>
 * Each value corresponds to a discrete business event that must be recorded in
 * {@code audit_entries} for compliance (NFR10 7-year retention) and operational
 * traceability (§13 Observability Architecture).
 * <p>
 * Naming convention: {@code <NOUN>_<VERB>} in SCREAMING_SNAKE_CASE.
 */
public enum AuditAction {

    // Identity & access
    ADMIN_LOGIN,
    AUTH_LOGIN_FAILED,

    // Course lifecycle
    COURSE_PUBLISH,
    COURSE_ROLLBACK,

    // Course operations
    PIN_UPDATE,
    GREEN_UPDATE,
    CONDITION_UPDATE,

    // Course version (Story 8.3)
    COURSE_VERSION_VALIDATED,
    COURSE_VERSION_PUBLISHED,

    // Correction workflow
    CORRECTION_SUBMITTED,
    CORRECTION_CORROBORATED,
    CORRECTION_APPROVE,
    CORRECTION_REJECT,
    CORRECTION_INFO_REQUESTED,
    CORRECTION_CONVERTED_TO_DRAFT,
    CORRECTION_RESOLVED,

    // RBAC
    ROLE_ASSIGN,
    ROLE_REVOKE,

    // MFA
    MFA_ENABLED,
    MFA_DISABLED,

    // Profile
    PROFILE_UPDATE,

    // Bag
    BAG_CREATE,
    BAG_UPDATE,
    BAG_DELETE,

    // Club
    CLUB_CREATE,
    CLUB_UPDATE,
    CLUB_DELETE,

    // Privacy
    PRIVACY_REQUEST_SUBMITTED,
    PRIVACY_REQUEST_PROCESSED,
    ACCOUNT_DATA_EXPORTED,
    ACCOUNT_DELETED,
    ROUND_DELETED,

    // Round
    ROUND_CREATE,
    ROUND_COMPLETE,
    ROUND_ABANDON,
    SCORE_CORRECTION,

    // Shot (Story 10.3)
    SHOT_STARTED,
    SHOT_ENDED,
    SHOT_EDITED,
    SHOT_DELETED,
    SHOT_MERGED,

    // Tournament
    TOURNAMENT_POLICY_CHANGE,

    // Course alerts (Story 8.6)
    ALERT_SEND,
    ALERT_UPDATE,
    ALERT_CANCEL,
    ALERT_ACK,

    // Geometry editor (Story 8.2)
    GEOMETRY_FEATURE_CREATED,
    GEOMETRY_FEATURE_UPDATED,
    GEOMETRY_FEATURE_DELETED,
    GEOMETRY_VALIDATED,

    // Data quality (Story 9.4)
    DATA_QUALITY_METRICS_EXPORT,

    /// A person confirmed that a hole's imported coordinates are right.
    ///
    /// This is the action that lets the app draw a strategic map for that hole
    /// and let detection score a position against it, so the audit trail has to
    /// be able to name who made the claim and when.
    GEOMETRY_VERIFIED,

    /// A person corrected a hole's par from the course's scorecard.
    ///
    /// Separate from GEOMETRY_VERIFIED because it is a different claim from a
    /// different source: coordinates are checked against a map, par against a
    /// scorecard. Every over/under-par figure a golfer sees is arithmetic
    /// against this number, so who changed it, to what, and on what authority
    /// all have to be answerable.
    HOLE_PAR_CORRECTED
}
