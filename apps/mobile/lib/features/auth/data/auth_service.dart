// Auth Service — VSP Mobile App
//
// API calls for authentication endpoints.
// All methods return structured results or throw VspApiException.

import '../../../core/network/api_client.dart';
import 'auth_dto.dart';

/// Auth service — wraps all /auth/* API calls.
class AuthService {
  final ApiClient _apiClient;

  AuthService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ─── Login ───────────────────────────────────────────────────────────────────

  /// POST /auth/login
  Future<AuthTokens> login(LoginRequest request) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: request.toJson(),
    );
    return AuthTokens.fromJson(response as Map<String, dynamic>);
  }

  // ─── Phone Registration ─────────────────────────────────────────────────────

  /// POST /auth/register/phone
  Future<void> registerPhone(PhoneRegisterRequest request) async {
    await _apiClient.post('/auth/register/phone', body: request.toJson());
  }

  // ─── Email Registration ─────────────────────────────────────────────────────

  /// POST /auth/register/email
  Future<void> registerEmail(EmailRegisterRequest request) async {
    await _apiClient.post('/auth/register/email', body: request.toJson());
  }

  // ─── OTP ────────────────────────────────────────────────────────────────────

  /// POST /auth/otp/send
  Future<OtpSendResponse> sendOtp(OtpSendRequest request) async {
    final response = await _apiClient.post(
      '/auth/otp/send',
      body: request.toJson(),
    );
    return OtpSendResponse.fromJson(response as Map<String, dynamic>);
  }

  /// POST /auth/otp/verify
  /// Returns void on success; throws on failure.
  Future<void> verifyOtp(OtpVerifyRequest request) async {
    await _apiClient.post('/auth/otp/verify', body: request.toJson());
  }

  // ─── Password Recovery ───────────────────────────────────────────────────────

  /// POST /auth/password/recover — initiates OTP send
  Future<void> initiatePasswordRecovery(PasswordRecoverRequest request) async {
    await _apiClient.post('/auth/password/recover', body: request.toJson());
  }

  /// POST /auth/password/reset — reset password with recovery token
  Future<void> resetPassword(PasswordResetRequest request) async {
    await _apiClient.post('/auth/password/reset', body: request.toJson());
  }

  // ─── Social Auth ────────────────────────────────────────────────────────────

  /// POST /auth/google
  Future<SocialAuthResponse> authenticateWithGoogle(
    GoogleAuthRequest request,
  ) async {
    final response = await _apiClient.post(
      '/auth/google',
      body: request.toJson(),
    );
    return SocialAuthResponse.fromJson(response as Map<String, dynamic>);
  }

  /// POST /auth/apple
  Future<SocialAuthResponse> authenticateWithApple(
    AppleAuthRequest request,
  ) async {
    final response = await _apiClient.post(
      '/auth/apple',
      body: request.toJson(),
    );
    return SocialAuthResponse.fromJson(response as Map<String, dynamic>);
  }

  // ─── Token Refresh ───────────────────────────────────────────────────────────

  /// POST /auth/refresh
  Future<TokenRefreshResponse> refreshToken(TokenRefreshRequest request) async {
    final response = await _apiClient.post(
      '/auth/refresh',
      body: request.toJson(),
    );
    return TokenRefreshResponse.fromJson(response as Map<String, dynamic>);
  }

  // ─── Profile ─────────────────────────────────────────────────────────────────

  /// GET /auth/me
  Future<GolferProfile> getCurrentProfile() async {
    final response = await _apiClient.get('/auth/me');
    return GolferProfile.fromJson(response as Map<String, dynamic>);
  }

  // ─── Session Management ───────────────────────────────────────────────────────

  /// GET /auth/sessions — list all active sessions for the current user.
  Future<List<SessionInfo>> listSessions() async {
    final response = await _apiClient.get('/auth/sessions');
    final list = response as List<dynamic>;
    return list
        .map((item) => SessionInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /auth/sessions/{sessionId} — revoke a specific session.
  Future<void> revokeSession(String sessionId) async {
    await _apiClient.delete('/auth/sessions/$sessionId');
  }
}
