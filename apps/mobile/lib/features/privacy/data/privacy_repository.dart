// Privacy Repository — VSP Mobile App
//
// Repository wrapping PrivacyService for privacy request data.
// Privacy requests are submitted to the server (no offline queue needed for MVP).

import '../../../core/network/api_client.dart' show VspApiException;
import 'privacy_request_dto.dart';
import 'privacy_service.dart';

/// Result of a submit operation.
class SubmitResult {
  final bool wasSuccess;
  final PrivacyRequestDTO? request;
  final String? errorMessage;

  const SubmitResult.success(this.request)
    : wasSuccess = true,
      errorMessage = null;

  const SubmitResult.failure(this.errorMessage)
    : wasSuccess = false,
      request = null;
}

/// Repository for privacy request data.
class PrivacyRepository {
  final PrivacyService _privacyService;

  PrivacyRepository({required PrivacyService privacyService})
    : _privacyService = privacyService;

  /// Fetch all privacy requests for the current golfer.
  Future<List<PrivacyRequestDTO>> getMyRequests() async {
    return _privacyService.getMyRequests();
  }

  /// Fetch a single privacy request by ID.
  Future<PrivacyRequestDTO> getRequestById(int id) async {
    return _privacyService.getRequestById(id);
  }

  /// Submit a new privacy request.
  Future<SubmitResult> submitRequest(CreatePrivacyRequest request) async {
    try {
      final result = await _privacyService.createRequest(request);
      return SubmitResult.success(result);
    } on VspApiException catch (ex) {
      return SubmitResult.failure(ex.message);
    } catch (ex) {
      return SubmitResult.failure(
        'Failed to submit request. Please try again.',
      );
    }
  }

  /// Fetch rounds for the round picker.
  Future<List<RoundSummaryDTO>> getMyRounds() async {
    return _privacyService.getMyRounds();
  }
}
