// Auth BLoC — VSP Mobile App
//
// State management for authentication flows:
// - Login with phone/email + password
// - Phone/email registration with OTP verification
// - Password recovery
// - Google Sign-In
// - Apple Sign-In
//
// States: AuthInitial, AuthLoading, AuthSuccess, AuthFailure
// Events: LoginRequested, RegisterWithPhoneRequested, RegisterWithEmailRequested,
//         OtpSent, OtpVerified, PasswordRecoveryRequested, PasswordResetRequested,
//         GoogleSignInRequested, AppleSignInRequested, LogoutRequested, SessionRestored

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_dto.dart';
import '../data/auth_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Request to login with phone/email + password.
class LoginRequested extends AuthEvent {
  final String identifier;
  final String password;

  const LoginRequested({required this.identifier, required this.password});

  @override
  List<Object?> get props => [identifier, password];
}

/// Request to register with phone.
class RegisterWithPhoneRequested extends AuthEvent {
  final String phone;
  final String password;
  final String displayName;

  const RegisterWithPhoneRequested({
    required this.phone,
    required this.password,
    required this.displayName,
  });

  @override
  List<Object?> get props => [phone, password, displayName];
}

/// Request to register with email.
class RegisterWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;

  const RegisterWithEmailRequested({
    required this.email,
    required this.password,
    required this.displayName,
  });

  @override
  List<Object?> get props => [email, password, displayName];
}

/// Request to send OTP.
class OtpSendRequested extends AuthEvent {
  final String identifier;
  final OtpType type;

  const OtpSendRequested({required this.identifier, required this.type});

  @override
  List<Object?> get props => [identifier, type];
}

/// Request to verify OTP.
class OtpVerifyRequested extends AuthEvent {
  final String identifier;
  final String code;
  final OtpType type;

  const OtpVerifyRequested({
    required this.identifier,
    required this.code,
    required this.type,
  });

  @override
  List<Object?> get props => [identifier, code, type];
}

/// Request password recovery (initiates OTP send).
class PasswordRecoveryRequested extends AuthEvent {
  final String identifier;

  const PasswordRecoveryRequested({required this.identifier});

  @override
  List<Object?> get props => [identifier];
}

/// Request password reset with token from OTP verify.
class PasswordResetRequested extends AuthEvent {
  final String token;
  final String newPassword;

  const PasswordResetRequested({
    required this.token,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [token, newPassword];
}

/// Request Google Sign-In.
class GoogleSignInRequested extends AuthEvent {
  final String idToken;
  final String? displayName;

  const GoogleSignInRequested({required this.idToken, this.displayName});

  @override
  List<Object?> get props => [idToken, displayName];
}

/// Request Apple Sign-In.
class AppleSignInRequested extends AuthEvent {
  final String idToken;
  final String? authorizationCode;
  final String? displayName;

  const AppleSignInRequested({
    required this.idToken,
    this.authorizationCode,
    this.displayName,
  });

  @override
  List<Object?> get props => [idToken, authorizationCode, displayName];
}

/// Request logout.
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// Restore session from stored tokens on app startup.
class SessionRestoreRequested extends AuthEvent {
  const SessionRestoreRequested();
}

/// Request to load all active sessions.
class LoadSessionsRequested extends AuthEvent {
  const LoadSessionsRequested();
}

/// Request to revoke a specific session.
class RevokeSessionRequested extends AuthEvent {
  final String sessionId;

  const RevokeSessionRequested({required this.sessionId});

  @override
  List<Object?> get props => [sessionId];
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no auth action taken yet.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state — async operation in progress.
class AuthLoading extends AuthState {
  final String message;

  const AuthLoading([this.message = 'Please wait...']);

  @override
  List<Object?> get props => [message];
}

/// Success state — auth operation completed successfully.
class AuthSuccess extends AuthState {
  final AuthTokens? tokens;
  final GolferProfile? profile;
  final String? message;
  final bool isNewAccount;

  const AuthSuccess({
    this.tokens,
    this.profile,
    this.message,
    this.isNewAccount = false,
  });

  @override
  List<Object?> get props => [tokens, profile, message, isNewAccount];
}

/// OTP sent — awaiting code entry.
class OtpSent extends AuthState {
  final String identifier;
  final OtpType type;
  final String expiresIn;

  const OtpSent({
    required this.identifier,
    required this.type,
    required this.expiresIn,
  });

  @override
  List<Object?> get props => [identifier, type, expiresIn];
}

/// Password recovery OTP sent — awaiting code entry.
class PasswordRecoveryOtpSent extends AuthState {
  final String identifier;

  const PasswordRecoveryOtpSent({required this.identifier});

  @override
  List<Object?> get props => [identifier];
}

/// Password reset successful.
class PasswordResetSuccess extends AuthState {
  const PasswordResetSuccess();
}

/// Failure state — auth operation failed with error message.
class AuthFailure extends AuthState {
  final String code;
  final String message;
  final bool isNetworkError;
  final Map<String, String>? fieldErrors; // field-level validation errors

  const AuthFailure({
    required this.code,
    required this.message,
    this.isNetworkError = false,
    this.fieldErrors,
  });

  /// Auth failure from API exception.
  /// Maps backend error codes to user-friendly messages and extracts field-level
  /// errors when the backend provides field attribution.
  factory AuthFailure.fromApiException(VspApiException ex) {
    final code = ex.code;
    final field = ex.field;

    // Determine if this error should have field-level display
    final fieldErrors = <String, String>{};

    if (code == 'VSP-ERR-AUTH-008' && field != null) {
      // AUTH_008: identifier already registered — field-level feedback
      if (field == 'phone') {
        fieldErrors['phone'] = 'This phone number is already registered';
      } else if (field == 'email') {
        fieldErrors['email'] = 'This email is already registered';
      }
    } else if (code == 'VSP-ERR-AUTH-011' && field == 'code') {
      // AUTH_011: invalid or expired OTP — field-level feedback
      fieldErrors['code'] = 'Invalid verification code';
    }

    // If we have field-level errors, use the first one as the global message
    final hasFieldErrors = fieldErrors.isNotEmpty;
    final message = hasFieldErrors
        ? fieldErrors.values.first
        : _globalMessageForCode(code, ex.message);

    return AuthFailure(
      code: code,
      message: message,
      isNetworkError: code == 'NETWORK_ERROR',
      fieldErrors: hasFieldErrors ? fieldErrors : null,
    );
  }

  /// Returns the appropriate global (non-field) message for auth error codes.
  /// Per AC-3: credential errors never reveal which field failed.
  static String _globalMessageForCode(String code, String defaultMessage) {
    switch (code) {
      case 'VSP-ERR-AUTH-001':
        return 'Invalid phone number or password';
      case 'VSP-ERR-AUTH-002':
      case 'VSP-ERR-AUTH-007':
        return 'Session expired. Please sign in again.';
      case 'VSP-ERR-AUTH-003':
        return 'Invalid session. Please sign in again.';
      case 'VSP-ERR-AUTH-004':
        return 'Account temporarily locked. Try again later.';
      case 'VSP-ERR-AUTH-005':
        return 'You do not have permission to perform this action.';
      case 'VSP-ERR-AUTH-009':
        return 'Account not verified. Please complete verification.';
      case 'VSP-ERR-AUTH-010':
        return 'Account not found.';
      case 'VSP-ERR-AUTH-012':
        return 'Recovery code expired. Please request a new one.';
      case 'VSP-ERR-AUTH-013':
        return 'This social account is already linked to another account.';
      case 'VSP-ERR-AUTH-014':
        return 'Google sign-in failed. Please try again.';
      case 'VSP-ERR-AUTH-015':
        return 'Apple sign-in failed. Please try again.';
      case 'VSP-ERR-AUTH-016':
        return 'Email mismatch. Please use the same email for both accounts.';
      case 'VSP-ERR-AUTH-017':
        return 'Cannot link social account. Please contact support.';
      case 'NETWORK_ERROR':
        return 'Check your internet connection and try again.';
      default:
        return defaultMessage;
    }
  }

  /// Field-level validation failure.
  factory AuthFailure.fieldError(String field, String message) {
    return AuthFailure(
      code: 'FIELD_ERROR',
      message: message,
      fieldErrors: {field: message},
    );
  }

  @override
  List<Object?> get props => [code, message, isNetworkError, fieldErrors];
}

/// Session restored from storage on app startup.
class SessionRestored extends AuthState {
  const SessionRestored();
}

/// Session not found — no stored tokens.
class SessionNotFound extends AuthState {
  const SessionNotFound();
}

/// Sessions loaded — list of active sessions.
class SessionsLoaded extends AuthState {
  final List<SessionInfo> sessions;

  const SessionsLoaded({required this.sessions});

  @override
  List<Object?> get props => [sessions];
}

/// Session revoke success.
class SessionRevokeSuccess extends AuthState {
  final String revokedSessionId;
  final List<SessionInfo> remainingSessions;

  const SessionRevokeSuccess({
    required this.revokedSessionId,
    required this.remainingSessions,
  });

  @override
  List<Object?> get props => [revokedSessionId, remainingSessions];
}

// ─── Auth BLoC ───────────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<RegisterWithPhoneRequested>(_onRegisterWithPhoneRequested);
    on<RegisterWithEmailRequested>(_onRegisterWithEmailRequested);
    on<OtpSendRequested>(_onOtpSendRequested);
    on<OtpVerifyRequested>(_onOtpVerifyRequested);
    on<PasswordRecoveryRequested>(_onPasswordRecoveryRequested);
    on<PasswordResetRequested>(_onPasswordResetRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<AppleSignInRequested>(_onAppleSignInRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionRestoreRequested>(_onSessionRestoreRequested);
    on<LoadSessionsRequested>(_onLoadSessionsRequested);
    on<RevokeSessionRequested>(_onRevokeSessionRequested);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Signing in...'));
    try {
      final tokens = await _authRepository.login(
        event.identifier,
        event.password,
      );
      emit(AuthSuccess(tokens: tokens));
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        AuthFailure(
          code: 'UNKNOWN',
          message: 'An unexpected error occurred. Please try again.',
        ),
      );
    }
  }

  Future<void> _onRegisterWithPhoneRequested(
    RegisterWithPhoneRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Creating account...'));
    try {
      await _authRepository.registerWithPhone(
        phone: event.phone,
        password: event.password,
        displayName: event.displayName,
      );
      // After registration, send verification OTP
      final otpResponse = await _authRepository.sendPhoneOtp(event.phone);
      emit(
        OtpSent(
          identifier: event.phone,
          type: OtpType.phoneVerify,
          expiresIn: otpResponse.expiresIn,
        ),
      );
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        AuthFailure(
          code: 'UNKNOWN',
          message: 'Registration failed. Please try again.',
        ),
      );
    }
  }

  Future<void> _onRegisterWithEmailRequested(
    RegisterWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Creating account...'));
    try {
      await _authRepository.registerWithEmail(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      // After registration, send verification OTP
      final otpResponse = await _authRepository.sendEmailOtp(event.email);
      emit(
        OtpSent(
          identifier: event.email,
          type: OtpType.emailVerify,
          expiresIn: otpResponse.expiresIn,
        ),
      );
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        AuthFailure(
          code: 'UNKNOWN',
          message: 'Registration failed. Please try again.',
        ),
      );
    }
  }

  Future<void> _onOtpSendRequested(
    OtpSendRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Sending verification code...'));
    try {
      final isRecovery = event.type == OtpType.passwordRecovery;
      if (event.type == OtpType.phoneVerify) {
        final response = await _authRepository.sendPhoneOtp(
          event.identifier,
          isRecovery: isRecovery,
        );
        emit(
          OtpSent(
            identifier: event.identifier,
            type: event.type,
            expiresIn: response.expiresIn,
          ),
        );
      } else if (event.type == OtpType.emailVerify) {
        final response = await _authRepository.sendEmailOtp(
          event.identifier,
          isRecovery: isRecovery,
        );
        emit(
          OtpSent(
            identifier: event.identifier,
            type: event.type,
            expiresIn: response.expiresIn,
          ),
        );
      } else {
        await _authRepository.initiatePasswordRecovery(event.identifier);
        emit(PasswordRecoveryOtpSent(identifier: event.identifier));
      }
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        AuthFailure(
          code: 'UNKNOWN',
          message: 'Failed to send verification code. Please try again.',
        ),
      );
    }
  }

  Future<void> _onOtpVerifyRequested(
    OtpVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Verifying code...'));
    try {
      if (event.type == OtpType.passwordRecovery) {
        await _authRepository.verifyRecoveryOtp(event.identifier, event.code);
        // For password recovery, the verify returns a token we need to use for reset
        // The backend sends the recovery token via email/SMS which the user would have
        // In this flow, we just indicate success and let user set new password
        emit(const PasswordResetSuccess());
      } else if (event.type == OtpType.phoneVerify) {
        await _authRepository.verifyPhoneOtp(event.identifier, event.code);
        emit(const AuthSuccess(message: 'Phone verified successfully'));
      } else {
        await _authRepository.verifyEmailOtp(event.identifier, event.code);
        emit(const AuthSuccess(message: 'Email verified successfully'));
      }
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        AuthFailure(
          code: 'UNKNOWN',
          message: 'Verification failed. Please check the code and try again.',
        ),
      );
    }
  }

  Future<void> _onPasswordRecoveryRequested(
    PasswordRecoveryRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Sending recovery code...'));
    try {
      await _authRepository.initiatePasswordRecovery(event.identifier);
      emit(PasswordRecoveryOtpSent(identifier: event.identifier));
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        AuthFailure(
          code: 'UNKNOWN',
          message: 'Failed to send recovery code. Please try again.',
        ),
      );
    }
  }

  Future<void> _onPasswordResetRequested(
    PasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Resetting password...'));
    try {
      await _authRepository.resetPassword(event.token, event.newPassword);
      emit(const PasswordResetSuccess());
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        AuthFailure(
          code: 'UNKNOWN',
          message: 'Failed to reset password. Please try again.',
        ),
      );
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Signing in with Google...'));
    try {
      final response = await _authRepository.authenticateWithGoogle(
        event.idToken,
        displayName: event.displayName,
      );
      emit(
        AuthSuccess(
          tokens: response.toAuthTokens(),
          isNewAccount: response.isNewAccount,
        ),
      );
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        const AuthFailure(
          code: 'GOOGLE_SIGN_IN_FAILED',
          message: 'Google sign-in failed. Please try again.',
        ),
      );
    }
  }

  Future<void> _onAppleSignInRequested(
    AppleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Signing in with Apple...'));
    try {
      final response = await _authRepository.authenticateWithApple(
        event.idToken,
        authorizationCode: event.authorizationCode,
        displayName: event.displayName,
      );
      emit(
        AuthSuccess(
          tokens: response.toAuthTokens(),
          isNewAccount: response.isNewAccount,
        ),
      );
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        const AuthFailure(
          code: 'APPLE_SIGN_IN_FAILED',
          message: 'Apple sign-in failed. Please try again.',
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthInitial());
  }

  Future<void> _onSessionRestoreRequested(
    SessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Checking your secure session…'));
    final hasSession = await _authRepository.hasValidSession();
    if (hasSession) {
      final refreshed = await _authRepository.tryRefreshToken();
      if (refreshed) {
        emit(const SessionRestored());
      } else {
        emit(const SessionNotFound());
      }
    } else {
      emit(const SessionNotFound());
    }
  }

  Future<void> _onLoadSessionsRequested(
    LoadSessionsRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Loading sessions...'));
    try {
      final sessions = await _authRepository.listSessions();
      emit(SessionsLoaded(sessions: sessions));
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        const AuthFailure(
          code: 'UNKNOWN',
          message: 'Failed to load sessions. Please try again.',
        ),
      );
    }
  }

  Future<void> _onRevokeSessionRequested(
    RevokeSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading('Revoking session...'));
    try {
      await _authRepository.revokeSession(event.sessionId);
      // If revoke succeeded but we're still logged in (not our own session),
      // reload the sessions list
      final hasSession = await _authRepository.hasValidSession();
      if (hasSession) {
        final sessions = await _authRepository.listSessions();
        emit(
          SessionRevokeSuccess(
            revokedSessionId: event.sessionId,
            remainingSessions: sessions,
          ),
        );
      } else {
        // We revoked our own session — emit success then initial
        emit(
          const SessionRevokeSuccess(
            revokedSessionId: '',
            remainingSessions: [],
          ),
        );
        emit(const AuthInitial());
      }
    } on VspApiException catch (ex) {
      emit(AuthFailure.fromApiException(ex));
    } catch (ex) {
      emit(
        const AuthFailure(
          code: 'UNKNOWN',
          message: 'Failed to revoke session. Please try again.',
        ),
      );
    }
  }
}
