// Tournament Service — VSP Mobile App
//
// Per Story 12.1 Slice H:
// - Fetch tournament by ID
// - Fetch and cache tournament policy for offline restricted feature checks
// - Tournament rounds use cached policy for feature guards
//
// Story 12.1 Slice H

import '../../domain/models/tournament/models.dart';
import '../../domain/models/tournament_policy.dart';
import '../../data/repositories/tournament_policy_repository.dart';
import 'package:vsp_mobile/core/network/api_client.dart';

/// Handles tournament-related API operations on mobile.
///
/// Goes through [ApiClient] rather than a bare HTTP client. Every tournament
/// route except the leaderboard is authenticated, and a raw client sends no
/// bearer token — so these calls answered 401 and this service, which
/// swallows every failure into null, reported "no tournament" instead. A
/// silent wrong answer is the worst shape a client can have.
class TournamentService {
  final ApiClient _apiClient;

  TournamentService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  // ─── Tournament ─────────────────────────────────────────────────────────

  /// Fetch a tournament by ID.
  Future<Tournament?> getTournament(String tournamentId) async {
    try {
      final json = await _apiClient.get('/tournaments/$tournamentId');
      return Tournament.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// List tournaments with optional status filter.
  Future<List<Tournament>> listTournaments({
    TournamentStatus? status,
    int? courseId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status.name.toUpperCase();
      if (courseId != null) queryParams['courseId'] = courseId.toString();

      final list = await _apiClient.get(
        '/tournaments',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      return (list as List<dynamic>)
          .map((e) => Tournament.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Tournament Policy ─────────────────────────────────────────────────

  /// Fetch the tournament policy for a tournament and cache it.
  /// Used when a tournament round starts to get the policy for feature guards.
  /// Per Story 12.1 Slice H.
  Future<TournamentPolicy?> getTournamentPolicy(
    String tournamentId, {
    required TournamentPolicyRepository policyRepository,
  }) async {
    // First try to get tournament to find its policy ID
    final tournament = await getTournament(tournamentId);
    if (tournament == null || tournament.tournamentPolicyId == null) {
      return null;
    }

    // Fetch the policy
    return policyRepository.getPolicy(tournament.tournamentPolicyId!);
  }

  // ─── Leaderboard ───────────────────────────────────────────────────────

  /// Fetch current leaderboard for a tournament (polling fallback).
  Future<Leaderboard?> getLeaderboard(String tournamentId) async {
    try {
      final json =
          await _apiClient.get('/tournaments/$tournamentId/leaderboard');
      return Leaderboard.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
