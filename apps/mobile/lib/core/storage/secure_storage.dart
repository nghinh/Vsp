// Secure Storage — Vietnam Smart Golf Platform Mobile App
//
// Wraps flutter_secure_storage for encrypted token persistence.
// Tokens are stored in the platform's secure enclave (Keychain on iOS, Keystore on Android).
//
// Security contract (per architecture.md §12):
// - Short-lived access tokens stored in encrypted storage
// - Refresh tokens stored in encrypted storage
// - No tokens in plain SharedPreferences or disk
// - Tokens cleared on logout

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys used for secure storage entries.
abstract final class SecureStorageKeys {
  static const String accessToken = 'vsp_access_token';
  static const String refreshToken = 'vsp_refresh_token';
  static const String golferId = 'vsp_golfer_id';
  static const String golferDisplayName = 'vsp_golfer_display_name';

  /// Current session ID — used for session revocation.
  static const String sessionId = 'vsp_session_id';
}

/// Secure storage service for auth tokens and golfer data.
class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  // ─── Access Token ─────────────────────────────────────────────────────────────

  /// Store the JWT access token.
  Future<void> setAccessToken(String token) async {
    await _storage.write(key: SecureStorageKeys.accessToken, value: token);
  }

  /// Retrieve the JWT access token.
  Future<String?> getAccessToken() async {
    return _storage.read(key: SecureStorageKeys.accessToken);
  }

  /// Delete the access token (on logout).
  Future<void> deleteAccessToken() async {
    await _storage.delete(key: SecureStorageKeys.accessToken);
  }

  // ─── Refresh Token ───────────────────────────────────────────────────────────

  /// Store the JWT refresh token.
  Future<void> setRefreshToken(String token) async {
    await _storage.write(key: SecureStorageKeys.refreshToken, value: token);
  }

  /// Retrieve the refresh token.
  Future<String?> getRefreshToken() async {
    return _storage.read(key: SecureStorageKeys.refreshToken);
  }

  /// Delete the refresh token (on logout).
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: SecureStorageKeys.refreshToken);
  }

  // ─── Golfer Profile ──────────────────────────────────────────────────────────

  /// Store golfer ID.
  Future<void> setGolferId(int id) async {
    await _storage.write(key: SecureStorageKeys.golferId, value: id.toString());
  }

  /// Retrieve golfer ID.
  Future<int?> getGolferId() async {
    final val = await _storage.read(key: SecureStorageKeys.golferId);
    return val != null ? int.tryParse(val) : null;
  }

  /// Store golfer display name.
  Future<void> setGolferDisplayName(String name) async {
    await _storage.write(key: SecureStorageKeys.golferDisplayName, value: name);
  }

  /// Retrieve golfer display name.
  Future<String?> getGolferDisplayName() async {
    return _storage.read(key: SecureStorageKeys.golferDisplayName);
  }

  // ─── Session ID ──────────────────────────────────────────────────────────────

  /// Store the current session ID.
  Future<void> setSessionId(String sessionId) async {
    await _storage.write(key: SecureStorageKeys.sessionId, value: sessionId);
  }

  /// Retrieve the current session ID.
  Future<String?> getSessionId() async {
    return _storage.read(key: SecureStorageKeys.sessionId);
  }

  /// Delete the session ID.
  Future<void> deleteSessionId() async {
    await _storage.delete(key: SecureStorageKeys.sessionId);
  }

  // ─── Bulk Operations ─────────────────────────────────────────────────────────

  /// Clear all stored auth data (on logout or account deletion).
  Future<void> clearAll() async {
    await Future.wait([
      deleteAccessToken(),
      deleteRefreshToken(),
      _storage.delete(key: SecureStorageKeys.golferId),
      _storage.delete(key: SecureStorageKeys.golferDisplayName),
      deleteSessionId(),
    ]);
  }

  /// Check if a valid session exists (both tokens present).
  Future<bool> hasValidSession() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    return access != null && refresh != null;
  }
}
