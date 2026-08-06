package vnpt.vsp.api.error;

import org.springframework.http.HttpStatus;

/**
 * Stable machine-readable error codes for the VSP API.
 * <p>
 * Format: {@code VSP-ERR-<DOMAIN>-<NUMBER>}
 * Domain codes: AUTH, COURSE, PACKAGE, ROUND, SCORE, WEATHER, CORRECTION, ADMIN, VALIDATION, INTERNAL.
 */
public enum VspErrorCode {

    // ─── AUTH (VSP-ERR-AUTH-xxx) ──────────────────────────────────────────────

    AUTH_001("VSP-ERR-AUTH-001", "Invalid credentials", HttpStatus.UNAUTHORIZED),
    AUTH_002("VSP-ERR-AUTH-002", "Token expired", HttpStatus.UNAUTHORIZED),
    AUTH_003("VSP-ERR-AUTH-003", "Token malformed", HttpStatus.UNAUTHORIZED),
    AUTH_004("VSP-ERR-AUTH-004", "Account locked", HttpStatus.FORBIDDEN),
    AUTH_005("VSP-ERR-AUTH-005", "Insufficient permissions", HttpStatus.FORBIDDEN),
    AUTH_006("VSP-ERR-AUTH-006", "Session not found", HttpStatus.UNAUTHORIZED),
    AUTH_007("VSP-ERR-AUTH-007", "Refresh token expired", HttpStatus.UNAUTHORIZED),
    AUTH_008("VSP-ERR-AUTH-008", "Identifier already registered", HttpStatus.CONFLICT),
    AUTH_009("VSP-ERR-AUTH-009", "Account not verified", HttpStatus.FORBIDDEN),
    AUTH_010("VSP-ERR-AUTH-010", "Account not found", HttpStatus.NOT_FOUND),
    AUTH_011("VSP-ERR-AUTH-011", "Invalid or expired OTP code", HttpStatus.BAD_REQUEST),
    AUTH_012("VSP-ERR-AUTH-012", "Invalid or expired recovery token", HttpStatus.BAD_REQUEST),
    AUTH_013("VSP-ERR-AUTH-013", "Social account already linked", HttpStatus.CONFLICT),
    AUTH_014("VSP-ERR-AUTH-014", "Google authentication failed", HttpStatus.BAD_REQUEST),
    AUTH_015("VSP-ERR-AUTH-015", "Apple authentication failed", HttpStatus.BAD_REQUEST),
    AUTH_016("VSP-ERR-AUTH-016", "Email mismatch between social account and existing account", HttpStatus.CONFLICT),
    AUTH_017("VSP-ERR-AUTH-017", "Cannot link social account: different provider already linked", HttpStatus.CONFLICT),
    AUTH_018("VSP-ERR-AUTH-018", "Session not found", HttpStatus.NOT_FOUND),
    AUTH_019("VSP-ERR-AUTH-019", "Session already revoked", HttpStatus.BAD_REQUEST),

    // ─── FACILITY (VSP-ERR-FACILITY-xxx) ────────────────────────────────────

    FACILITY_001("VSP-ERR-FACILITY-001", "Golf facility not found", HttpStatus.NOT_FOUND),
    FACILITY_002("VSP-ERR-FACILITY-002", "Facility name is required", HttpStatus.BAD_REQUEST),

    // ─── COURSE (VSP-ERR-COURSE-xxx) ──────────────────────────────────────────

    COURSE_001("VSP-ERR-COURSE-001", "Course not found", HttpStatus.NOT_FOUND),
    COURSE_009("VSP-ERR-COURSE-009", "Course name is required for publication", HttpStatus.BAD_REQUEST),
    COURSE_010("VSP-ERR-COURSE-010", "Course must have at least one hole for publication", HttpStatus.BAD_REQUEST),
    COURSE_002("VSP-ERR-COURSE-002", "Course version mismatch", HttpStatus.CONFLICT),
    COURSE_003("VSP-ERR-COURSE-003", "Course not active", HttpStatus.BAD_REQUEST),
    COURSE_004("VSP-ERR-COURSE-004", "Course layout not found", HttpStatus.NOT_FOUND),
    COURSE_005("VSP-ERR-COURSE-005", "Course layout version mismatch", HttpStatus.CONFLICT),
    COURSE_006("VSP-ERR-COURSE-006", "Search radius exceeds maximum allowed (50km)", HttpStatus.BAD_REQUEST),
    COURSE_007("VSP-ERR-COURSE-007", "Invalid coordinates provided", HttpStatus.BAD_REQUEST),
    COURSE_008("VSP-ERR-COURSE-008", "Favorite course not found", HttpStatus.NOT_FOUND),
    HOLE_001("VSP-ERR-HOLE-001", "Hole not found", HttpStatus.NOT_FOUND),
    HOLE_002("VSP-ERR-HOLE-002", "Hole number is required", HttpStatus.BAD_REQUEST),
    TEE_SET_001("VSP-ERR-TEE-SET-001", "Tee set not found", HttpStatus.NOT_FOUND),
    PIN_001("VSP-ERR-PIN-001", "Pin position not found", HttpStatus.NOT_FOUND),
    CONDITION_001("VSP-ERR-CONDITION-001", "Course condition not found", HttpStatus.NOT_FOUND),
    DATA_VERSION_001("VSP-ERR-DATA-VERSION-001", "Data version not found", HttpStatus.NOT_FOUND),
    DATA_VERSION_002("VSP-ERR-DATA-VERSION-002", "Version is not in ARCHIVED status — cannot roll back", HttpStatus.CONFLICT),
    DATA_VERSION_003("VSP-ERR-DATA-VERSION-003", "No currently published version to replace", HttpStatus.CONFLICT),
    DATA_LICENSE_001("VSP-ERR-DATA-LICENSE-001", "Data license not found", HttpStatus.NOT_FOUND),

    // ─── COURSE IMPORT (VSP-ERR-COURSE-IMPORT-xxx) ───────────────────────────

    COURSE_IMPORT_001("VSP-ERR-COURSE-IMPORT-001", "Invalid GeoJSON format", HttpStatus.BAD_REQUEST),
    COURSE_IMPORT_002("VSP-ERR-COURSE-IMPORT-002", "No features found in GeoJSON", HttpStatus.BAD_REQUEST),
    COURSE_IMPORT_003("VSP-ERR-COURSE-IMPORT-003", "All features failed validation", HttpStatus.BAD_REQUEST),
    COURSE_IMPORT_004("VSP-ERR-COURSE-IMPORT-004", "Preview token expired or invalid", HttpStatus.BAD_REQUEST),
    COURSE_IMPORT_005("VSP-ERR-COURSE-IMPORT-005", "Course not found", HttpStatus.NOT_FOUND),

    // ─── GEOMETRY (VSP-ERR-GEOMETRY-xxx) ─────────────────────────────────────

    GEOMETRY_001("VSP-ERR-GEOMETRY-001", "Draft geometry feature not found", HttpStatus.NOT_FOUND),
    GEOMETRY_002("VSP-ERR-GEOMETRY-002", "Feature does not belong to the specified course", HttpStatus.BAD_REQUEST),
    GEOMETRY_003("VSP-ERR-GEOMETRY-003", "Duplicate feature: external ID already exists for this layer", HttpStatus.CONFLICT),
    GEOMETRY_004("VSP-ERR-GEOMETRY-004", "Geometry validation failed", HttpStatus.BAD_REQUEST),
    GEOMETRY_005("VSP-ERR-GEOMETRY-005", "Invalid GeoJSON format", HttpStatus.BAD_REQUEST),

    // ─── PACKAGE (VSP-ERR-PACKAGE-xxx) ───────────────────────────────────────

    PACKAGE_001("VSP-ERR-PACKAGE-001", "Course package not found", HttpStatus.NOT_FOUND),
    PACKAGE_002("VSP-ERR-PACKAGE-002", "Package version mismatch", HttpStatus.CONFLICT),
    PACKAGE_003("VSP-ERR-PACKAGE-003", "Package not active", HttpStatus.BAD_REQUEST),
    PACKAGE_004("VSP-ERR-PACKAGE-004", "Package superseded by newer version", HttpStatus.GONE),

    // ─── TOURNAMENT (VSP-ERR-TOURNAMENT-xxx) ────────────────────────────────

    TOURNAMENT_001("VSP-ERR-TOURNAMENT-001", "Tournament policy not found", HttpStatus.NOT_FOUND),
    TOURNAMENT_002("VSP-ERR-TOURNAMENT-002", "Tournament policy is locked — feature changes require Tournament Director role", HttpStatus.FORBIDDEN),
    TOURNAMENT_003("VSP-ERR-TOURNAMENT-003", "Tournament policy not provided for tournament-format round", HttpStatus.BAD_REQUEST),
    FEATURE_RESTRICTED("FEATURE_RESTRICTED", "Feature is disabled in tournament mode", HttpStatus.FORBIDDEN),

    // Tournament operations (Story 12.1)
    TOURNAMENT_004("VSP-ERR-TOURNAMENT-004", "Tournament not found", HttpStatus.NOT_FOUND),
    TOURNAMENT_005("VSP-ERR-TOURNAMENT-005", "Tournament cannot be modified in current status", HttpStatus.CONFLICT),
    TOURNAMENT_006("VSP-ERR-TOURNAMENT-006", "Registration deadline has passed", HttpStatus.BAD_REQUEST),
    TOURNAMENT_007("VSP-ERR-TOURNAMENT-007", "Maximum number of players reached", HttpStatus.BAD_REQUEST),
    TOURNAMENT_008("VSP-ERR-TOURNAMENT-008", "Flight not found", HttpStatus.NOT_FOUND),
    TOURNAMENT_009("VSP-ERR-TOURNAMENT-009", "Tee time not found", HttpStatus.NOT_FOUND),
    TOURNAMENT_010("VSP-ERR-TOURNAMENT-010", "All flights must have confirmed scores before completing tournament", HttpStatus.BAD_REQUEST),
    TOURNAMENT_011("VSP-ERR-TOURNAMENT-011", "Player not registered in tournament", HttpStatus.NOT_FOUND),
    TOURNAMENT_012("VSP-ERR-TOURNAMENT-012", "Player already registered in tournament", HttpStatus.CONFLICT),
    TOURNAMENT_013("VSP-ERR-TOURNAMENT-013", "Invalid flight size — must be 2-4 players", HttpStatus.BAD_REQUEST),
    TOURNAMENT_014("VSP-ERR-TOURNAMENT-014", "Tournament must be completed before publishing results", HttpStatus.CONFLICT),

    // ─── ROUND (VSP-ERR-ROUND-xxx) ───────────────────────────────────────────

    ROUND_001("VSP-ERR-ROUND-001", "Round not found", HttpStatus.NOT_FOUND),
    ROUND_002("VSP-ERR-ROUND-002", "Round already in progress", HttpStatus.CONFLICT),
    ROUND_003("VSP-ERR-ROUND-003", "Round already completed", HttpStatus.CONFLICT),
    ROUND_004("VSP-ERR-ROUND-004", "Cannot start round for inactive course", HttpStatus.BAD_REQUEST),
    ROUND_005("VSP-ERR-ROUND-005", "Scorecard not found for round", HttpStatus.NOT_FOUND),
    ROUND_006("VSP-ERR-ROUND-006", "Round cannot be completed in current status", HttpStatus.CONFLICT),

    // ─── SCORE (VSP-ERR-SCORE-xxx) ────────────────────────────────────────────

    SCORE_001("VSP-ERR-SCORE-001", "Score not found", HttpStatus.NOT_FOUND),
    SCORE_002("VSP-ERR-SCORE-002", "Hole already has a score entry", HttpStatus.CONFLICT),
    SCORE_003("VSP-ERR-SCORE-003", "Score submission outside valid scoring window", HttpStatus.BAD_REQUEST),
    SCORE_004("VSP-ERR-SCORE-004", "Invalid score value", HttpStatus.BAD_REQUEST),
    SCORE_005("VSP-ERR-SCORE-005", "Scorecard closed for editing", HttpStatus.CONFLICT),
    SCORE_006("VSP-ERR-SCORE-006", "Score correction field not permitted", HttpStatus.UNPROCESSABLE_ENTITY),

    // ─── SHOT (VSP-ERR-SHOT-xxx) ────────────────────────────────────────────

    SHOT_001("VSP-ERR-SHOT-001", "Shot not found", HttpStatus.NOT_FOUND),
    SHOT_002("VSP-ERR-SHOT-002", "Shot already deleted", HttpStatus.CONFLICT),
    SHOT_003("VSP-ERR-SHOT-003", "Shot does not belong to the specified round", HttpStatus.BAD_REQUEST),
    SHOT_004("VSP-ERR-SHOT-004", "Source and target shots must belong to the same round", HttpStatus.BAD_REQUEST),
    SHOT_005("VSP-ERR-SHOT-005", "Cannot merge a shot that is already merged", HttpStatus.BAD_REQUEST),
    SHOT_006("VSP-ERR-SHOT-006", "Round not found", HttpStatus.NOT_FOUND),
    SHOT_007("VSP-ERR-SHOT-007", "Shot not editable in current round status", HttpStatus.CONFLICT),

    // ─── WEATHER (VSP-ERR-WEATHER-xxx) ───────────────────────────────────────

    WEATHER_001("VSP-ERR-WEATHER-001", "Weather data not available", HttpStatus.SERVICE_UNAVAILABLE),
    WEATHER_002("VSP-ERR-WEATHER-002", "Weather data source timeout", HttpStatus.GATEWAY_TIMEOUT),
    WEATHER_003("VSP-ERR-WEATHER-003", "No weather snapshot for requested location", HttpStatus.NOT_FOUND),
    WEATHER_004("VSP-ERR-WEATHER-004", "Weather provider unavailable and no cached data available", HttpStatus.BAD_GATEWAY),

    // ─── CORRECTION (VSP-ERR-CORRECTION-xxx) ─────────────────────────────────

    CORRECTION_001("VSP-ERR-CORRECTION-001", "Correction request not found", HttpStatus.NOT_FOUND),
    CORRECTION_002("VSP-ERR-CORRECTION-002", "Correction already reviewed", HttpStatus.CONFLICT),
    CORRECTION_003("VSP-ERR-CORRECTION-003", "Invalid correction status transition", HttpStatus.BAD_REQUEST),
    CORRECTION_004("VSP-ERR-CORRECTION-004", "Correction not in pending state", HttpStatus.BAD_REQUEST),

    // ─── PROFILE (VSP-ERR-PROFILE-xxx) ───────────────────────────────────────

    PROFILE_001("VSP-ERR-PROFILE-001", "Profile not found", HttpStatus.NOT_FOUND),
    PROFILE_002("VSP-ERR-PROFILE-002", "Invalid distance unit value", HttpStatus.BAD_REQUEST),
    PROFILE_003("VSP-ERR-PROFILE-003", "Invalid skill level value", HttpStatus.BAD_REQUEST),

    // ─── BAG (VSP-ERR-BAG-xxx) ───────────────────────────────────────────────

    BAG_001("VSP-ERR-BAG-001", "Golf bag not found", HttpStatus.NOT_FOUND),
    BAG_002("VSP-ERR-BAG-002", "Cannot delete the last remaining bag", HttpStatus.BAD_REQUEST),

    // ─── CLUB (VSP-ERR-CLUB-xxx) ─────────────────────────────────────────────

    CLUB_001("VSP-ERR-CLUB-001", "Club not found", HttpStatus.NOT_FOUND),
    CLUB_002("VSP-ERR-CLUB-002", "Club does not belong to the specified bag", HttpStatus.BAD_REQUEST),

    // ─── PERFORMANCE (VSP-ERR-PERF-xxx) ────────────────────────────────────

    PERF_001("VSP-ERR-PERF-001", "Club performance stats not found", HttpStatus.NOT_FOUND),
    PERF_002("VSP-ERR-PERF-002", "Hole not found for dispersion overlay", HttpStatus.NOT_FOUND),
    PERF_003("VSP-ERR-PERF-003", "Layout not found for dispersion overlay", HttpStatus.NOT_FOUND),
    PERF_004("VSP-ERR-PERF-004", "Insufficient shot data for dispersion analysis", HttpStatus.BAD_REQUEST),

    // ─── ROLE (VSP-ERR-ROLE-xxx) ───────────────────────────────────────────

    ROLE_001("VSP-ERR-ROLE-001", "Role not found", HttpStatus.NOT_FOUND),
    ROLE_002("VSP-ERR-ROLE-002", "Admin account not found", HttpStatus.NOT_FOUND),
    ROLE_003("VSP-ERR-ROLE-003", "Role already assigned to this admin", HttpStatus.CONFLICT),
    ROLE_004("VSP-ERR-ROLE-004", "Cannot revoke the last super admin", HttpStatus.BAD_REQUEST),
    ROLE_005("VSP-ERR-ROLE-005", "Cannot assign super admin role", HttpStatus.FORBIDDEN),
    ROLE_006("VSP-ERR-ROLE-006", "Only super admin can assign or revoke super admin roles", HttpStatus.FORBIDDEN),

    // ─── MFA (VSP-ERR-MFA-xxx) ─────────────────────────────────────────────

    MFA_001("VSP-ERR-MFA-001", "MFA is not enabled for this account", HttpStatus.BAD_REQUEST),
    MFA_002("VSP-ERR-MFA-002", "Invalid TOTP code", HttpStatus.BAD_REQUEST),
    MFA_003("VSP-ERR-MFA-003", "MFA secret encryption failed", HttpStatus.INTERNAL_SERVER_ERROR),
    MFA_004("VSP-ERR-MFA-004", "MFA must be verified before it can be disabled", HttpStatus.BAD_REQUEST),
    MFA_005("VSP-ERR-MFA-005", "Too many MFA attempts — try again later", HttpStatus.TOO_MANY_REQUESTS),
    MFA_006("VSP-ERR-MFA-006", "No MFA enrolment in progress — start one first", HttpStatus.BAD_REQUEST),
    MFA_007("VSP-ERR-MFA-007", "MFA is already enabled — disable it before enrolling again", HttpStatus.CONFLICT),

    // ─── PRIVACY (VSP-ERR-PRIVACY-xxx) ───────────────────────────────────────

    PRIVACY_001("VSP-ERR-PRIVACY-001", "Privacy request not found", HttpStatus.NOT_FOUND),
    PRIVACY_002("VSP-ERR-PRIVACY-002", "Privacy request already processed", HttpStatus.CONFLICT),
    PRIVACY_003("VSP-ERR-PRIVACY-003", "Invalid privacy request status transition", HttpStatus.BAD_REQUEST),
    PRIVACY_004("VSP-ERR-PRIVACY-004", "Cannot delete account with active rounds — delete rounds first", HttpStatus.BAD_REQUEST),
    PRIVACY_005("VSP-ERR-PRIVACY-005", "Target round not found", HttpStatus.NOT_FOUND),
    PRIVACY_006("VSP-ERR-PRIVACY-006", "Invalid request type", HttpStatus.BAD_REQUEST),
    PRIVACY_007("VSP-ERR-PRIVACY-007", "Target round does not belong to the requesting account", HttpStatus.FORBIDDEN),
    PRIVACY_008("VSP-ERR-PRIVACY-008", "Cannot process request — missing required permissions", HttpStatus.FORBIDDEN),

    // ─── ADMIN (VSP-ERR-ADMIN-xxx) ───────────────────────────────────────────

    ADMIN_001("VSP-ERR-ADMIN-001", "Course publish failed", HttpStatus.INTERNAL_SERVER_ERROR),
    ADMIN_002("VSP-ERR-ADMIN-002", "Rollback not available for requested version", HttpStatus.CONFLICT),
    ADMIN_003("VSP-ERR-ADMIN-003", "Audit entry not found", HttpStatus.NOT_FOUND),
    ADMIN_004("VSP-ERR-ADMIN-004", "Course is already published", HttpStatus.CONFLICT),
    ADMIN_005("VSP-ERR-ADMIN-005", "Course is not in a publishable state", HttpStatus.BAD_REQUEST),

    // ─── ALERT (VSP-ERR-ALERT-xxx) ──────────────────────────────────────────

    ALERT_001("VSP-ERR-ALERT-001", "Course alert not found", HttpStatus.NOT_FOUND),
    ALERT_002("VSP-ERR-ALERT-002", "Alert cannot be updated after effective time", HttpStatus.BAD_REQUEST),
    ALERT_003("VSP-ERR-ALERT-003", "Alert does not require acknowledgment", HttpStatus.BAD_REQUEST),

    // ─── VALIDATION (VSP-ERR-VALIDATION-xxx) ──────────────────────────────────

    VALIDATION_001("VSP-ERR-VALIDATION-001", "Request validation failed", HttpStatus.BAD_REQUEST),
    VALIDATION_002("VSP-ERR-VALIDATION-002", "Missing required field", HttpStatus.BAD_REQUEST),
    VALIDATION_003("VSP-ERR-VALIDATION-003", "Field value out of allowed range", HttpStatus.BAD_REQUEST),
    VALIDATION_004("VSP-ERR-VALIDATION-004", "Malformed JSON in request body", HttpStatus.BAD_REQUEST),
    VALIDATION_005("VSP-ERR-VALIDATION-005", "Unsupported media type", HttpStatus.UNSUPPORTED_MEDIA_TYPE),
    VALIDATION_006("VSP-ERR-VALIDATION-006", "Idempotency-Key header missing on idempotent endpoint", HttpStatus.BAD_REQUEST),
    VALIDATION_007("VSP-ERR-VALIDATION-007", "Invalid page token format", HttpStatus.BAD_REQUEST),
    VALIDATION_008("VSP-ERR-VALIDATION-008", "Geometry validation failed: invalid WKT format", HttpStatus.BAD_REQUEST),

    // ─── INTERNAL (VSP-ERR-INTERNAL-xxx) ──────────────────────────────────────

    INTERNAL_001("VSP-ERR-INTERNAL-001", "Unexpected server error", HttpStatus.INTERNAL_SERVER_ERROR),
    INTERNAL_002("VSP-ERR-INTERNAL-002", "Database operation failed", HttpStatus.INTERNAL_SERVER_ERROR),
    INTERNAL_003("VSP-ERR-INTERNAL-003", "External service call failed", HttpStatus.BAD_GATEWAY),
    INTERNAL_004("VSP-ERR-INTERNAL-004", "Feature not implemented", HttpStatus.NOT_IMPLEMENTED),
    INTERNAL_005("VSP-ERR-INTERNAL-005", "Resource temporarily unavailable — please retry", HttpStatus.SERVICE_UNAVAILABLE);

    private final String code;
    private final String defaultMessage;
    private final HttpStatus httpStatus;

    VspErrorCode(String code, String defaultMessage, HttpStatus httpStatus) {
        this.code = code;
        this.defaultMessage = defaultMessage;
        this.httpStatus = httpStatus;
    }

    public String getCode() {
        return code;
    }

    public String getDefaultMessage() {
        return defaultMessage;
    }

    public HttpStatus getHttpStatus() {
        return httpStatus;
    }

    /**
     * Returns the code string, matching the enum constant name in a stable format.
     */
    @Override
    public String toString() {
        return code;
    }
}
