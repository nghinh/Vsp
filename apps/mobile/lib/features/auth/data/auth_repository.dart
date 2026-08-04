// Auth Repository — VSP Mobile App
//
// Orchestrates auth service calls and token persistence.
// Single source of truth for auth state from the mobile app perspective.

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'auth_dto.dart';
import 'auth_service.dart';

/// Auth repository — coordinates service calls and local token storage.
class AuthRepository {
  final AuthService _authService;
  final SecureStorage _secureStorage;
  final ApiClient _apiClient;

  AuthRepository({
    required AuthService authService,
    required SecureStorage secureStorage,
    required ApiClient apiClient,
  }) : _authService = authService,
       _secureStorage = secureStorage,
       _apiClient = apiClient;

  // ─── Token Persistence ───────────────────────────────────────────────────────

  /// Persist auth tokens after login or social auth.
  Future<void> _persistTokens(AuthTokens tokens) async {
    await Future.wait([
      _secureStorage.setAccessToken(tokens.accessToken),
      _secureStorage.setRefreshToken(tokens.refreshToken),
      _secureStorage.setGolferId(tokens.userId),
      if (tokens.displayName != null)
        _secureStorage.setGolferDisplayName(tokens.displayName!),
      if (tokens.sessionId != null)
        _secureStorage.setSessionId(tokens.sessionId!),
    ]);
    _apiClient.setAccessToken(tokens.accessToken);
  }

  /// Load tokens from storage and set on API client (app startup).
  Future<bool> restoreSession() async {
    final accessToken = await _secureStorage.getAccessToken();
    if (accessToken != null) {
      _apiClient.setAccessToken(accessToken);
      return true;
    }
    return false;
  }

  /// Clear all auth data (logout).
  Future<void> logout() async {
    await _secureStorage.clearAll();
    _apiClient.setAccessToken(null);
  }

  /// Check if user has a valid stored session.
  Future<bool> hasValidSession() => _secureStorage.hasValidSession();

  // ─── Login ───────────────────────────────────────────────────────────────────

  /// Login with phone or email + password.
  Future<AuthTokens> login(String identifier, String password) async {
    final tokens = await _authService.login(
      LoginRequest(identifier: identifier, password: password),
    );
    await _persistTokens(tokens);
    return tokens;
  }

  // ─── Phone Registration ─────────────────────────────────────────────────────

  /// Register with phone number.
  /// Sends OTP after registration to verify phone.
  Future<void> registerWithPhone({
    required String phone,
    required String password,
    required String displayName,
  }) async {
    await _authService.registerPhone(
      PhoneRegisterRequest(
        phone: phone,
        password: password,
        displayName: displayName,
      ),
    );
  }

  /// Send OTP for phone verification.
  Future<OtpSendResponse> sendPhoneOtp(
    String phone, {
    bool isRecovery = false,
  }) {
    return _authService.sendOtp(
      OtpSendRequest(
        identifier: phone,
        type: isRecovery ? OtpType.passwordRecovery : OtpType.phoneVerify,
      ),
    );
  }

  /// Verify phone OTP.
  Future<void> verifyPhoneOtp(String phone, String code) {
    return _authService.verifyOtp(
      OtpVerifyRequest(
        identifier: phone,
        code: code,
        type: OtpType.phoneVerify,
      ),
    );
  }

  // ─── Email Registration ─────────────────────────────────────────────────────

  /// Register with email.
  /// Sends OTP after registration to verify email.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _authService.registerEmail(
      EmailRegisterRequest(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  /// Send OTP for email verification.
  Future<OtpSendResponse> sendEmailOtp(
    String email, {
    bool isRecovery = false,
  }) {
    return _authService.sendOtp(
      OtpSendRequest(
        identifier: email,
        type: isRecovery ? OtpType.passwordRecovery : OtpType.emailVerify,
      ),
    );
  }

  /// Verify email OTP.
  Future<void> verifyEmailOtp(String email, String code) {
    return _authService.verifyOtp(
      OtpVerifyRequest(
        identifier: email,
        code: code,
        type: OtpType.emailVerify,
      ),
    );
  }

  // ─── Password Recovery ───────────────────────────────────────────────────────

  /// Initiate password recovery — sends OTP to phone or email.
  Future<void> initiatePasswordRecovery(String identifier) {
    return _authService.initiatePasswordRecovery(
      PasswordRecoverRequest(identifier: identifier),
    );
  }

  /// Verify OTP for password recovery — returns void on success.
  Future<void> verifyRecoveryOtp(String identifier, String code) {
    return _authService.verifyOtp(
      OtpVerifyRequest(
        identifier: identifier,
        code: code,
        type: OtpType.passwordRecovery,
      ),
    );
  }

  /// Reset password using the recovery token from OTP verify.
  Future<void> resetPassword(String token, String newPassword) {
    return _authService.resetPassword(
      PasswordResetRequest(token: token, newPassword: newPassword),
    );
  }

  // ─── Social Auth ────────────────────────────────────────────────────────────

  /// Authenticate with Google.
  Future<SocialAuthResponse> authenticateWithGoogle(
    String idToken, {
    String? displayName,
  }) async {
    final response = await _authService.authenticateWithGoogle(
      GoogleAuthRequest(idToken: idToken, displayName: displayName),
    );
    await _persistTokens(response.toAuthTokens());
    return response;
  }

  /// Authenticate with Apple.
  Future<SocialAuthResponse> authenticateWithApple(
    String idToken, {
    String? authorizationCode,
    String? displayName,
  }) async {
    final response = await _authService.authenticateWithApple(
      AppleAuthRequest(
        idToken: idToken,
        authorizationCode: authorizationCode,
        displayName: displayName,
      ),
    );
    await _persistTokens(response.toAuthTokens());
    return response;
  }

  // ─── Profile ─────────────────────────────────────────────────────────────────

  /// Get the current authenticated golfer profile.
  Future<GolferProfile> getCurrentProfile() => _authService.getCurrentProfile();

  // ─── Token Refresh ───────────────────────────────────────────────────────────

  /// Refresh the access token using the stored refresh token.
  Future<bool> tryRefreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _authService.refreshToken(
        TokenRefreshRequest(refreshToken: refreshToken),
      );
      await _secureStorage.setAccessToken(response.accessToken);
      _apiClient.setAccessToken(response.accessToken);
      return true;
    } catch (_) {
      // Refresh failed — clear session
      await logout();
      return false;
    }
  }

  // ─── Session Management ───────────────────────────────────────────────────────

  /// List all active sessions for the current user.
  Future<List<SessionInfo>> listSessions() => _authService.listSessions();

  /// Revoke a specific session by ID.
  /// If revoking the current session, clears local tokens and emits logout.
  Future<void> revokeSession(String sessionId) async {
    final currentSessionId = await _secureStorage.getSessionId();
    await _authService.revokeSession(sessionId);
    // If we revoked our own session, clear local state
    if (currentSessionId == sessionId) {
      await logout();
    }
  }

  /// Get the current session ID from storage.
  Future<String?> getCurrentSessionId() => _secureStorage.getSessionId();
}
