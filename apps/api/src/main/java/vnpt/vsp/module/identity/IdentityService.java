package vnpt.vsp.module.identity;

import vnpt.vsp.module.identity.dto.*;

import java.util.List;

/**
 * Identity module public service interface.
 * Exposes user authentication, session, and token operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 */
public interface IdentityService {

    // ─── Registration ────────────────────────────────────────────────────────

    /**
     * Register a new golfer account with phone number.
     * Sends OTP for verification.
     */
    AuthResponse registerWithPhone(PhoneRegisterRequest request);

    /**
     * Register a new golfer account with email.
     * Sends OTP for verification.
     */
    AuthResponse registerWithEmail(EmailRegisterRequest request);

    // ─── OTP ────────────────────────────────────────────────────────────────

    /**
     * Send an OTP code to the given phone or email.
     */
    OtpSendResponse sendOtp(OtpSendRequest request);

    /**
     * Verify an OTP code and mark the account as verified.
     */
    AuthResponse verifyOtp(OtpVerifyRequest request);

    // ─── Password Recovery ───────────────────────────────────────────────────

    /**
     * Initiate password recovery for the given phone or email.
     * Sends OTP for verification.
     */
    OtpSendResponse initiatePasswordRecovery(PasswordRecoverRequest request);

    /**
     * Reset password using a recovery token.
     */
    AuthResponse resetPassword(PasswordResetRequest request);

    // ─── Login ──────────────────────────────────────────────────────────────

    /**
     * Authenticate with phone/email and password.
     * Returns JWT tokens if successful.
     */
    AuthResponse login(String identifier, String password);

    // ─── Token Refresh ──────────────────────────────────────────────────────

    /**
     * Refresh access token using refresh token.
     */
    AuthResponse refreshToken(String refreshToken);

    // ─── Profile ────────────────────────────────────────────────────────────

    /**
     * Get the current authenticated golfer's profile.
     */
    GolferProfileResponse getCurrentProfile(Long golferAccountId);

    // ─── Social Authentication ─────────────────────────────────────────────

    /**
     * Authenticate using a Google ID token.
     * Creates a new account or links to an existing canonical account when verified email matches.
     */
    SocialAuthResponse authenticateWithGoogle(GoogleAuthRequest request);

    /**
     * Authenticate using an Apple identity token.
     * Creates a new account or links to an existing canonical account when verified email matches.
     */
    SocialAuthResponse authenticateWithApple(AppleAuthRequest request);

    // ─── Token Validation ───────────────────────────────────────────────────

    /**
     * Validate an access token and return the golfer account ID.
     */
    Long validateAccessToken(String accessToken);

    // ─── Session Management ─────────────────────────────────────────────────

    /**
     * Rotate a refresh token: revoke the old token and issue a new one.
     * Per Story 2.2 AC-1: refresh tokens rotate on each use.
     *
     * @param refreshToken the current refresh token
     * @param deviceInfo  client-reported device info
     * @param userAgent   client user agent
     * @param ipAddress   client IP address
     * @return new auth response with fresh access + refresh tokens
     */
    AuthResponse rotateRefreshToken(String refreshToken, String deviceInfo, String userAgent, String ipAddress);

    /**
     * List all active sessions for a golfer account.
     * Per Story 2.2 AC-3: user can list sessions.
     *
     * @param golferAccountId the account ID
     * @param currentTokenId   the ID of the current session to mark as "current"
     * @return list of active sessions
     */
    List<SessionResponse> listSessions(Long golferAccountId, Long currentTokenId);

    /**
     * Revoke a specific session.
     * Per Story 2.2 AC-3: user can revoke sessions; revoked sessions cannot refresh.
     *
     * @param golferAccountId the account ID
     * @param sessionId        the session ID to revoke
     */
    void revokeSession(Long golferAccountId, Long sessionId);

    /**
     * Revoke all sessions for a golfer account (logout from all devices).
     *
     * @param golferAccountId the account ID
     * @return number of sessions revoked
     */
    int revokeAllSessions(Long golferAccountId);
}
