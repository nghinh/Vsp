// Bag Service — VSP Mobile App
//
// API calls for golf bag and club endpoints (/bags/*).
// Mirrors the pattern from ProfileService.

import '../../../core/network/api_client.dart';
import 'bag_dto.dart';

/// Bag service — wraps /bags/* API calls.
class BagService {
  final ApiClient _apiClient;

  BagService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ─── Bags ─────────────────────────────────────────────────────────────────

  /// GET /bags — fetch all bags for the authenticated golfer.
  /// Backend auto-creates a default bag on first access.
  Future<List<BagDTO>> getBags() async {
    final response = await _apiClient.get('/bags');
    final list = response as List<dynamic>;
    return list.map((e) => BagDTO.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /bags — create a new golf bag.
  Future<BagDTO> createBag(CreateBagRequest request) async {
    final response = await _apiClient.post('/bags', body: request.toJson());
    return BagDTO.fromJson(response as Map<String, dynamic>);
  }

  /// PUT /bags/{bagId} — update a bag (partial update).
  Future<BagDTO> updateBag(int bagId, UpdateBagRequest request) async {
    final response = await _apiClient.put(
      '/bags/$bagId',
      body: request.toJson(),
    );
    return BagDTO.fromJson(response as Map<String, dynamic>);
  }

  /// DELETE /bags/{bagId} — delete a bag.
  Future<void> deleteBag(int bagId) async {
    await _apiClient.delete('/bags/$bagId');
  }

  /// POST /bags/{bagId}/activate — set a bag as active.
  /// This deactivates all other bags for the golfer (AC-2 enforcement).
  Future<BagDTO> activateBag(int bagId) async {
    final response = await _apiClient.post('/bags/$bagId/activate');
    return BagDTO.fromJson(response as Map<String, dynamic>);
  }

  // ─── Clubs ─────────────────────────────────────────────────────────────────

  /// GET /bags/{bagId}/clubs — fetch all clubs in a bag.
  Future<List<ClubDTO>> getClubs(int bagId) async {
    final response = await _apiClient.get('/bags/$bagId/clubs');
    final list = response as List<dynamic>;
    return list
        .map((e) => ClubDTO.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /bags/{bagId}/clubs — add a club to a bag.
  Future<ClubDTO> createClub(int bagId, CreateClubRequest request) async {
    final response = await _apiClient.post(
      '/bags/$bagId/clubs',
      body: request.toJson(),
    );
    return ClubDTO.fromJson(response as Map<String, dynamic>);
  }

  /// PUT /bags/{bagId}/clubs/{clubId} — update a club (partial update).
  Future<ClubDTO> updateClub(
    int bagId,
    int clubId,
    UpdateClubRequest request,
  ) async {
    final response = await _apiClient.put(
      '/bags/$bagId/clubs/$clubId',
      body: request.toJson(),
    );
    return ClubDTO.fromJson(response as Map<String, dynamic>);
  }

  /// DELETE /bags/{bagId}/clubs/{clubId} — delete a club.
  Future<void> deleteClub(int bagId, int clubId) async {
    await _apiClient.delete('/bags/$bagId/clubs/$clubId');
  }
}
