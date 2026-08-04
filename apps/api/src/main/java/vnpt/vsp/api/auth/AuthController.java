package vnpt.vsp.api.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.identity.IdentityService;
import vnpt.vsp.module.identity.dto.*;

import java.util.List;

/**
 * REST controller for authentication endpoints.
 * Per PRD Section 8.1: phone, email registration with OTP verification and password recovery.
 * Per Architecture Section 11.2: /auth/* endpoints are required.
 */
@RestController
@RequestMapping("/auth")
public class AuthController {

    private final IdentityService identityService;

    public AuthController(IdentityService identityService) {
        this.identityService = identityService;
    }

    // ─── Registration ────────────────────────────────────────────────────────

    /**
     * Register a new golfer account with phone number.
     */
    @PostMapping("/register/phone")
    public ResponseEntity<AuthResponse> registerWithPhone(
            @Valid @RequestBody PhoneRegisterRequest request) {
        AuthResponse response = identityService.registerWithPhone(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Register a new golfer account with email.
     */
    @PostMapping("/register/email")
    public ResponseEntity<AuthResponse> registerWithEmail(
            @Valid @RequestBody EmailRegisterRequest request) {
        AuthResponse response = identityService.registerWithEmail(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    // ─── OTP ────────────────────────────────────────────────────────────────

    /**
     * Send an OTP code to the given phone or email.
     */
    @PostMapping("/otp/send")
    public ResponseEntity<OtpSendResponse> sendOtp(
            @Valid @RequestBody OtpSendRequest request) {
        OtpSendResponse response = identityService.sendOtp(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Verify an OTP code and mark the account as verified.
     */
    @PostMapping("/otp/verify")
    public ResponseEntity<AuthResponse> verifyOtp(
            @Valid @RequestBody OtpVerifyRequest request) {
        AuthResponse response = identityService.verifyOtp(request);
        return ResponseEntity.ok(response);
    }

    // ─── Password Recovery ───────────────────────────────────────────────────

    /**
     * Initiate password recovery for the given phone or email.
     */
    @PostMapping("/password/recover")
    public ResponseEntity<OtpSendResponse> initiatePasswordRecovery(
            @Valid @RequestBody PasswordRecoverRequest request) {
        OtpSendResponse response = identityService.initiatePasswordRecovery(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Reset password using a recovery token.
     */
    @PostMapping("/password/reset")
    public ResponseEntity<AuthResponse> resetPassword(
            @Valid @RequestBody PasswordResetRequest request) {
        AuthResponse response = identityService.resetPassword(request);
        return ResponseEntity.ok(response);
    }

    // ─── Login ──────────────────────────────────────────────────────────────

    /**
     * Legacy login endpoint using request body (for compatibility).
     */
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@RequestBody LoginRequest request) {
        AuthResponse response = identityService.login(request.getIdentifier(), request.getPassword());
        return ResponseEntity.ok(response);
    }

    // ─── Token Refresh ──────────────────────────────────────────────────────

    /**
     * Refresh access token using refresh token.
     * Per Story 2.2 AC-1: refresh tokens rotate on each use.
     */
    @PostMapping("/refresh")
    public ResponseEntity<AuthResponse> refreshToken(
            @RequestBody TokenRefreshRequest request,
            HttpServletRequest httpRequest) {
        String deviceInfo = extractDeviceInfo(httpRequest);
        String userAgent = httpRequest.getHeader("User-Agent");
        String ipAddress = extractClientIp(httpRequest);
        AuthResponse response = identityService.rotateRefreshToken(
                request.getRefreshToken(), deviceInfo, userAgent, ipAddress);
        return ResponseEntity.ok(response);
    }

    // ─── Session Management ─────────────────────────────────────────────────

    /**
     * List all active sessions for the authenticated golfer.
     * Per Story 2.2 AC-3: user can list sessions.
     */
    @GetMapping("/sessions")
    public ResponseEntity<List<SessionResponse>> listSessions(
            Authentication authentication,
            @RequestParam(required = false) Long currentSessionId) {
        Long accountId = (Long) authentication.getPrincipal();
        List<SessionResponse> sessions = identityService.listSessions(accountId, currentSessionId);
        return ResponseEntity.ok(sessions);
    }

    /**
     * Revoke a specific session.
     * Per Story 2.2 AC-3: user can revoke sessions; revoked sessions cannot refresh.
     */
    @DeleteMapping("/sessions/{sessionId}")
    public ResponseEntity<Void> revokeSession(
            Authentication authentication,
            @PathVariable Long sessionId) {
        Long accountId = (Long) authentication.getPrincipal();
        identityService.revokeSession(accountId, sessionId);
        return ResponseEntity.noContent().build();
    }

    // ─── Profile ────────────────────────────────────────────────────────────

    /**
     * Get the current authenticated golfer's profile.
     */
    @GetMapping("/me")
    public ResponseEntity<GolferProfileResponse> getCurrentProfile(Authentication authentication) {
        Long accountId = (Long) authentication.getPrincipal();
        GolferProfileResponse response = identityService.getCurrentProfile(accountId);
        return ResponseEntity.ok(response);
    }

    // ─── Social Authentication ─────────────────────────────────────────────

    /**
     * Authenticate using Google Sign-In.
     * Creates a new account or links to an existing canonical account when verified email matches.
     */
    @PostMapping("/google")
    public ResponseEntity<SocialAuthResponse> authenticateWithGoogle(
            @Valid @RequestBody GoogleAuthRequest request) {
        SocialAuthResponse response = identityService.authenticateWithGoogle(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Authenticate using Apple Sign-In.
     * Creates a new account or links to an existing canonical account when verified email matches.
     */
    @PostMapping("/apple")
    public ResponseEntity<SocialAuthResponse> authenticateWithApple(
            @Valid @RequestBody AppleAuthRequest request) {
        SocialAuthResponse response = identityService.authenticateWithApple(request);
        return ResponseEntity.ok(response);
    }

    // ─── Request DTOs ──────────────────────────────────────────────────────

    public static class LoginRequest {
        private String identifier;
        private String password;

        public String getIdentifier() {
            return identifier;
        }

        public void setIdentifier(String identifier) {
            this.identifier = identifier;
        }

        public String getPassword() {
            return password;
        }

        public void setPassword(String password) {
            this.password = password;
        }
    }

    public static class TokenRefreshRequest {
        private String refreshToken;

        public String getRefreshToken() {
            return refreshToken;
        }

        public void setRefreshToken(String refreshToken) {
            this.refreshToken = refreshToken;
        }
    }

    // ─── Helper Methods ───────────────────────────────────────────────────

    private String extractDeviceInfo(HttpServletRequest request) {
        // Prefer X-Device-Info header set by mobile clients
        String deviceInfo = request.getHeader("X-Device-Info");
        if (deviceInfo == null || deviceInfo.isBlank()) {
            deviceInfo = request.getHeader("X-Device-ID");
        }
        if (deviceInfo == null || deviceInfo.isBlank()) {
            // Fall back to parsing User-Agent for mobile platforms
            String ua = request.getHeader("User-Agent");
            if (ua != null) {
                if (ua.contains("Android")) {
                    deviceInfo = "Android";
                } else if (ua.contains("iPhone") || ua.contains("iPad")) {
                    deviceInfo = "iOS";
                } else if (ua.contains("Flutter")) {
                    deviceInfo = "Flutter";
                }
            }
        }
        return deviceInfo;
    }

    private String extractClientIp(HttpServletRequest request) {
        // Check common proxy headers first
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isBlank()) {
            // X-Forwarded-For can contain multiple IPs; the first is the original client
            return xForwardedFor.split(",")[0].trim();
        }
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isBlank()) {
            return xRealIp.trim();
        }
        return request.getRemoteAddr();
    }
}
