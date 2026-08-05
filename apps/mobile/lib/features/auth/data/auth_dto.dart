// Auth DTOs — VSP Mobile App
//
// Data Transfer Objects for auth API calls.
// Matches the OpenAPI contract in packages/contracts/schemas/auth.yaml.

import 'package:equatable/equatable.dart';

// ─── Login ───────────────────────────────────────────────────────────────────

/// POST /auth/login — Phone or email + password login.
class LoginRequest extends Equatable {
  final String identifier; // phone or email
  final String password;

  const LoginRequest({required this.identifier, required this.password});

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'password': password,
  };

  @override
  List<Object?> get props => [identifier, password];
}

/// Auth tokens returned from login and social auth.
class AuthTokens extends Equatable {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final int userId;
  final String? displayName;
  final String? status;

  /// Session ID for this login session — used for session management.
  final String? sessionId;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
    required this.userId,
    this.displayName,
    this.status,
    this.sessionId,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      userId: (json['userId'] as num).toInt(),
      displayName: json['displayName'] as String?,
      status: json['status'] as String?,
      sessionId: json['sessionId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    expiresIn,
    tokenType,
    userId,
    displayName,
    status,
    sessionId,
  ];
}

// ─── Registration ─────────────────────────────────────────────────────────────

/// POST /auth/register/phone
class PhoneRegisterRequest extends Equatable {
  final String phone;
  final String password;
  final String displayName;

  const PhoneRegisterRequest({
    required this.phone,
    required this.password,
    required this.displayName,
  });

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'password': password,
    'displayName': displayName,
  };

  @override
  List<Object?> get props => [phone, password, displayName];
}

/// POST /auth/register/email
class EmailRegisterRequest extends Equatable {
  final String email;
  final String password;
  final String displayName;

  const EmailRegisterRequest({
    required this.email,
    required this.password,
    required this.displayName,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'displayName': displayName,
  };

  @override
  List<Object?> get props => [email, password, displayName];
}

// ─── OTP ─────────────────────────────────────────────────────────────────────

/// OTP type enum.
enum OtpType {
  phoneVerify('PHONE_VERIFY'),
  emailVerify('EMAIL_VERIFY'),
  passwordRecovery('PASSWORD_RECOVERY');

  final String value;
  const OtpType(this.value);
}

/// POST /auth/otp/send
class OtpSendRequest extends Equatable {
  final String identifier; // phone or email
  final OtpType type;

  const OtpSendRequest({required this.identifier, required this.type});

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'type': type.value,
  };

  @override
  List<Object?> get props => [identifier, type];
}

/// POST /auth/otp/send response.
class OtpSendResponse extends Equatable {
  final String message;
  final String expiresIn;

  const OtpSendResponse({required this.message, required this.expiresIn});

  factory OtpSendResponse.fromJson(Map<String, dynamic> json) {
    return OtpSendResponse(
      message: json['message'] as String,
      expiresIn: json['expiresIn'] as String,
    );
  }

  @override
  List<Object?> get props => [message, expiresIn];
}

/// POST /auth/otp/verify
class OtpVerifyRequest extends Equatable {
  final String identifier;
  final String code;
  final OtpType type;

  const OtpVerifyRequest({
    required this.identifier,
    required this.code,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'code': code,
    'type': type.value,
  };

  @override
  List<Object?> get props => [identifier, code, type];
}

// ─── Password Recovery ────────────────────────────────────────────────────────

/// POST /auth/password/recover — initiate password recovery.
class PasswordRecoverRequest extends Equatable {
  final String identifier; // phone or email

  const PasswordRecoverRequest({required this.identifier});

  Map<String, dynamic> toJson() => {'identifier': identifier};

  @override
  List<Object?> get props => [identifier];
}

/// POST /auth/password/reset — reset password with recovery token.
class PasswordResetRequest extends Equatable {
  final String token;
  final String newPassword;

  const PasswordResetRequest({required this.token, required this.newPassword});

  Map<String, dynamic> toJson() => {'token': token, 'newPassword': newPassword};

  @override
  List<Object?> get props => [token, newPassword];
}

// ─── Social Auth ──────────────────────────────────────────────────────────────

/// POST /auth/google
class GoogleAuthRequest extends Equatable {
  final String idToken;
  final String? displayName;

  const GoogleAuthRequest({required this.idToken, this.displayName});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'idToken': idToken};
    if (displayName != null) json['displayName'] = displayName;
    return json;
  }

  @override
  List<Object?> get props => [idToken, displayName];
}

/// POST /auth/apple
class AppleAuthRequest extends Equatable {
  final String idToken;
  final String? authorizationCode;
  final String? displayName;

  const AppleAuthRequest({
    required this.idToken,
    this.authorizationCode,
    this.displayName,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'idToken': idToken};
    if (authorizationCode != null)
      json['authorizationCode'] = authorizationCode;
    if (displayName != null) json['displayName'] = displayName;
    return json;
  }

  @override
  List<Object?> get props => [idToken, authorizationCode, displayName];
}

/// Social auth response — includes isNewAccount flag.
class SocialAuthResponse extends Equatable {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final int userId;
  final String? displayName;
  final String? status;
  final String provider; // GOOGLE or APPLE
  final bool isNewAccount;

  const SocialAuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
    required this.userId,
    this.displayName,
    this.status,
    required this.provider,
    required this.isNewAccount,
  });

  AuthTokens toAuthTokens() {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      tokenType: tokenType,
      userId: userId,
      displayName: displayName,
      status: status,
    );
  }

  factory SocialAuthResponse.fromJson(Map<String, dynamic> json) {
    return SocialAuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      userId: (json['userId'] as num).toInt(),
      displayName: json['displayName'] as String?,
      status: json['status'] as String?,
      provider: json['provider'] as String? ?? 'unknown',
      isNewAccount: json['isNewAccount'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    expiresIn,
    tokenType,
    userId,
    displayName,
    status,
    provider,
    isNewAccount,
  ];
}

// ─── Golfer Profile ───────────────────────────────────────────────────────────

/// GET /auth/me response.
class GolferProfile extends Equatable {
  final int id;
  final String? phone;
  final String? email;
  final String? displayName;
  final String? status;
  final bool verified;
  final DateTime? createdAt;

  const GolferProfile({
    required this.id,
    this.phone,
    this.email,
    this.displayName,
    this.status,
    this.verified = false,
    this.createdAt,
  });

  factory GolferProfile.fromJson(Map<String, dynamic> json) {
    return GolferProfile(
      id: (json['id'] as num).toInt(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      status: json['status'] as String?,
      verified: json['verified'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    phone,
    email,
    displayName,
    status,
    verified,
    createdAt,
  ];
}

// ─── Token Refresh ────────────────────────────────────────────────────────────

/// POST /auth/refresh
class TokenRefreshRequest extends Equatable {
  final String refreshToken;

  const TokenRefreshRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};

  @override
  List<Object?> get props => [refreshToken];
}

/// Token refresh response.
class TokenRefreshResponse extends Equatable {
  final String accessToken;
  final int expiresIn;
  final String tokenType;

  const TokenRefreshResponse({
    required this.accessToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
  });

  factory TokenRefreshResponse.fromJson(Map<String, dynamic> json) {
    return TokenRefreshResponse(
      accessToken: json['accessToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      tokenType: json['tokenType'] as String? ?? 'Bearer',
    );
  }

  @override
  List<Object?> get props => [accessToken, expiresIn, tokenType];
}

// ─── Session Management ──────────────────────────────────────────────────────

/// Session info — represents a single active session.
class SessionInfo extends Equatable {
  final String sessionId;
  final String? deviceInfo;
  final String? userAgent;
  final String? ipAddress;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isCurrent;

  const SessionInfo({
    required this.sessionId,
    this.deviceInfo,
    this.userAgent,
    this.ipAddress,
    required this.createdAt,
    required this.expiresAt,
    this.isCurrent = false,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      // API returns sessionId as an integer; coerce to String defensively.
      sessionId: json['sessionId']?.toString() ?? '',
      deviceInfo: json['deviceInfo'] as String?,
      userAgent: json['userAgent'] as String?,
      ipAddress: json['ipAddress'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      // API field is `currentSession`; keep `isCurrent` as a fallback.
      isCurrent:
          json['currentSession'] as bool? ?? json['isCurrent'] as bool? ?? false,
    );
  }

  /// Human-readable device label.
  String get deviceLabel {
    if (deviceInfo != null && deviceInfo!.isNotEmpty) {
      return deviceInfo!;
    }
    if (userAgent != null && userAgent!.isNotEmpty) {
      // Trim long user agent to first meaningful part
      final ua = userAgent!;
      final semicolon = ua.indexOf(';');
      if (semicolon > 0 && semicolon < 80) {
        return ua.substring(0, semicolon).trim();
      }
      return ua.length > 60 ? '${ua.substring(0, 60)}...' : ua;
    }
    return 'Unknown device';
  }

  /// Formatted creation time (relative or absolute).
  String get createdAtLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  @override
  List<Object?> get props => [
    sessionId,
    deviceInfo,
    userAgent,
    ipAddress,
    createdAt,
    expiresAt,
    isCurrent,
  ];
}
