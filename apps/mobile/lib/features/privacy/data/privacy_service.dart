// Privacy Service — VSP Mobile App
//
// API calls for privacy request endpoints (/privacy/*).
// All methods return structured results or throw VspApiException.

import '../../../core/network/api_client.dart';
import 'privacy_request_dto.dart';

/// Privacy service — wraps /privacy/* API calls.
class PrivacyService {
  final ApiClient _apiClient;

  PrivacyService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ─── Privacy Requests ────────────────────────────────────────────────────────

  /// GET /privacy/requests — list all privacy requests for the authenticated golfer.
  Future<List<PrivacyRequestDTO>> getMyRequests() async {
    final response = await _apiClient.get('/privacy/requests');
    final list = response as List<dynamic>;
    return list
        .map((e) => PrivacyRequestDTO.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /privacy/requests/{id} — get a specific privacy request.
  Future<PrivacyRequestDTO> getRequestById(int id) async {
    final response = await _apiClient.get('/privacy/requests/$id');
    return PrivacyRequestDTO.fromJson(response as Map<String, dynamic>);
  }

  /// POST /privacy/requests — submit a new privacy request.
  Future<PrivacyRequestDTO> createRequest(CreatePrivacyRequest request) async {
    final response = await _apiClient.post(
      '/privacy/requests',
      body: request.toJson(),
    );
    return PrivacyRequestDTO.fromJson(response as Map<String, dynamic>);
  }

  /// GET /privacy/requests/{id}/export — download data export for a request.
  /// Returns the raw JSON string of the exported data.
  Future<String> downloadExport(int requestId) async {
    final response = await _apiClient.get(
      '/privacy/requests/$requestId/export',
    );
    // The export endpoint may return raw JSON string or a URL to download.
    if (response is String) return response;
    return response.toString();
  }

  /// GET /rounds — list rounds for the authenticated golfer (for round picker).
  /// Returns minimal summary data for round selection.
  Future<List<RoundSummaryDTO>> getMyRounds() async {
    final response = await _apiClient.get('/rounds');
    final list = response as List<dynamic>;
    return list
        .map((e) => RoundSummaryDTO.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
