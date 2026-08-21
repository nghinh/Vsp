// Auth Repository — VSP Mobile App
//
// Orchestrates auth service calls and token persistence.
// Single source of truth for auth state from the mobile app perspective.

import 'dart:convert';

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

  /// Installs whatever access token is on disk, expired or not.
  ///
  /// Used by [restoreSession] when the server cannot be reached: an expired
  /// token is no worse than none, and the first request that does get through
  /// refreshes on its 401.
  Future<bool> loadStoredAccessToken() async {
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

  /// What restoring a saved session concluded.
  ///
  /// Three outcomes, not two. Collapsing the middle one into "no session" is
  /// what put a golfer with a perfectly good seven-day refresh token at a login
  /// screen because their phone had no signal on the first tee.
  ///
  /// See [restoreSession].
  ///
  /// Makes this repository the refresher every [ApiClient] falls back to on a
  /// 401.
  ///
  /// Called once, at start-up. Before this, [tryRefreshToken] ran only during
  /// session restore, so an access token that lapsed an hour into a four-hour
  /// round was never replaced: every later request 401'd, and the sync queue
  /// gave up on the golfer's scores after five attempts.
  void installTokenRefresh() {
    ApiClient.refreshAccessToken = tryRefreshToken;
  }

  /// Restores a saved session, distinguishing "refused" from "unreachable".
  ///
  /// Returns [SessionRestoreOutcome.offline] when the server could not be
  /// reached: the stored tokens are kept and the access token is installed as
  /// it stands. It may already be expired, which costs nothing — the app is
  /// offline-first, every local screen works without the network, and the
  /// first request that does reach the server refreshes on its 401.
  Future<SessionRestoreOutcome> restoreSession() async {
    if (!await hasValidSession()) {
      return SessionRestoreOutcome.signedOut;
    }

    // An access token that is still good is reason enough. Refreshing anyway
    // is what was signing golfers out.
    //
    // The server rotates on refresh: presenting a refresh token revokes it and
    // returns a new one. Do that on every launch and every launch becomes a
    // chance to lose the session — if the reply never lands (a tunnel, a
    // backgrounded app, a dropped connection) the server has already revoked
    // what the phone still holds, and the next launch is met with "Session not
    // found" and a login screen. The token was never expired; the exchange was
    // interrupted.
    //
    // The access token lives a day, so this skips the exchange for a day at a
    // time rather than burning one every time the app is opened. A token
    // inside the margin, or one this cannot read, still goes the long way.
    // A storage that will not answer is not evidence about the session, so it
    // takes the refresh path rather than propagating: on iOS the keychain item
    // is `first_unlock_this_device`, and a phone that rebooted in a golf bag
    // and has not been unlocked since reads back nothing at all.
    String? stored;
    try {
      stored = await _secureStorage.getAccessToken();
    } catch (_) {
      stored = null;
    }
    if (stored != null && _goodForAtLeast(stored, const Duration(minutes: 10))) {
      _apiClient.setAccessToken(stored);
      return SessionRestoreOutcome.restored;
    }

    if (await tryRefreshToken()) {
      return SessionRestoreOutcome.restored;
    }
    // tryRefreshToken clears storage when the server refuses, and leaves it
    // alone when the server was never reached.
    if (await hasValidSession()) {
      await loadStoredAccessToken();
      return SessionRestoreOutcome.offline;
    }
    return SessionRestoreOutcome.signedOut;
  }

  /// Whether [jwt] still has at least [margin] of life left.
  ///
  /// Reads `exp` out of the payload without verifying the signature, which is
  /// all this needs: the question is "is it worth spending a refresh token on
  /// this", and a token the phone forged for itself would be refused by the
  /// server anyway. Anything unreadable — not a JWT, no `exp`, malformed
  /// base64 — answers false and takes the refresh path, which is the safe way
  /// to be wrong.
  static bool _goodForAtLeast(String jwt, Duration margin) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return false;
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return false;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );
      return expiresAt.isAfter(DateTime.now().toUtc().add(margin));
    } catch (_) {
      return false;
    }
  }

  /// A refresh already in progress, so two callers share one exchange.
  ///
  /// The server rotates on refresh: it revokes the token it was given. Two
  /// refreshes racing therefore poison each other — the second presents a
  /// token the first has just had revoked, gets "Session not found", and signs
  /// the golfer out. That race ran on every launch, between session restore
  /// and the first authenticated request the app fires (which 401s while the
  /// token is still being fetched and asks for a refresh of its own).
  Future<bool>? _refreshInFlight;

  /// Refresh the access token using the stored refresh token.
  ///
  /// Single-flight: concurrent callers await the same exchange.
  Future<bool> tryRefreshToken() {
    return _refreshInFlight ??= _refreshTokenOnce().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _refreshTokenOnce() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _authService.refreshToken(
        TokenRefreshRequest(refreshToken: refreshToken),
      );
      await _secureStorage.setAccessToken(response.accessToken);
      // The server revoked the token we just presented and issued this one.
      // Not storing it leaves the device holding a revoked token, and the next
      // launch is met with "Session not found".
      final rotated = response.refreshToken;
      if (rotated != null && rotated.isNotEmpty) {
        await _secureStorage.setRefreshToken(rotated);
      }
      _apiClient.setAccessToken(response.accessToken);
      return true;
    } on VspApiException catch (ex) {
      if (ex.isNetworkError) {
        // The server was never reached. That is not a rejected session, and it
        // is the normal state of a phone on a golf course — signing the golfer
        // out here destroyed a session the server would still have honoured,
        // and left them at a login screen they cannot get past without the
        // signal they just did not have. The stored tokens stay; the next
        // attempt with a bar of signal picks them up.
        return false;
      }
      if (_refusedTheSession(ex)) {
        // The server answered and refused. The refresh token is spent,
        // revoked or expired, and there is nothing to keep.
        await logout();
      }
      // Anything else the server said is a problem with this one exchange,
      // not a verdict on the session. Keep the tokens and try again later.
      return false;
    } catch (_) {
      // An exception nobody anticipated. It is not evidence the session is
      // over, and signing the golfer out on it is the most destructive
      // possible reading of "something went wrong".
      return false;
    }
  }

  /// Whether the server actually rejected the refresh token.
  ///
  /// The old test was "not a network error", which signed the golfer out on
  /// everything the server said that was not a success. That is far more than
  /// a refusal:
  ///
  ///   * a body the client cannot parse arrives as `PARSE_ERROR` carrying the
  ///     response's own status code, so `isNetworkError` is false — a 200 the
  ///     app failed to read logged the golfer out;
  ///   * a 502 or a gateway timeout page from the tunnel in front of the API
  ///     is HTML with a status code, and read the same way;
  ///   * so does a 500 from a server that is merely having a bad minute.
  ///
  /// None of those is the server saying "this token is no good", and the
  /// evidence says they were the cause: 48 hours of API logs carry not one
  /// authentication failure, while sessions kept ending on the phone. The
  /// server never refused. The client gave up.
  ///
  /// A real refusal is 401 or 403 — verified against the deployment, which
  /// answers a malformed refresh token with 401 VSP-ERR-AUTH-003.
  static bool _refusedTheSession(VspApiException ex) =>
      ex.statusCode == 401 || ex.statusCode == 403;

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

/// Outcome of restoring a saved session at start-up.
enum SessionRestoreOutcome {
  /// Tokens were refreshed against the server.
  restored,

  /// The server was unreachable, but this device holds a session. The golfer
  /// stays signed in — an app that cannot be opened without signal is useless
  /// on a golf course.
  offline,

  /// There is no session, or the server refused the one there was.
  signedOut,
}
