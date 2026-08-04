// Profile Service — VSP Mobile App
//
// API calls for golfer profile endpoints (/profiles/*).
// All methods return structured results or throw VspApiException.

import '../../../core/network/api_client.dart';
import 'profile_dto.dart';

/// Profile service — wraps /profiles/* API calls.
class ProfileService {
  final ApiClient _apiClient;

  ProfileService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ─── Profile ─────────────────────────────────────────────────────────────────

  /// GET /profiles/me — fetch the authenticated golfer's profile.
  ///
  /// Backend auto-creates a default profile on first access.
  /// All distance values (e.g. driverDistance) are returned in METERS
  /// regardless of the golfer's display unit preference.
  Future<ProfileDTO> getProfile() async {
    final response = await _apiClient.get('/profiles/me');
    return ProfileDTO.fromJson(response as Map<String, dynamic>);
  }

  /// PUT /profiles/me — update the authenticated golfer's profile.
  ///
  /// Supports partial updates (only send fields you want to change).
  /// Idempotency key is required for offline-queued updates to ensure
  /// safe retry without server-side duplication.
  ///
  /// Backend stores driverDistance as canonical METERS — no conversion
  /// happens here; the UI layer handles display-unit conversion.
  Future<ProfileDTO> updateProfile(
    UpdateProfileRequest request, {
    String? idempotencyKey,
  }) async {
    final response = await _apiClient.put(
      '/profiles/me',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
    );
    return ProfileDTO.fromJson(response as Map<String, dynamic>);
  }
}
