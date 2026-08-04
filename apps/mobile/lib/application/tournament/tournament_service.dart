// Tournament Service — VSP Mobile App
//
// Per Story 12.1 Slice H:
// - Fetch tournament by ID
// - Fetch and cache tournament policy for offline restricted feature checks
// - Tournament rounds use cached policy for feature guards
//
// Story 12.1 Slice H

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/tournament/models.dart';
import '../../domain/models/tournament_policy.dart';
import '../../data/repositories/tournament_policy_repository.dart';

const String _baseUrl = 'https://api.vsp.local';

/// Handles tournament-related API operations on mobile.
class TournamentService {
  final http.Client _httpClient;

  TournamentService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  // ─── Tournament ─────────────────────────────────────────────────────────

  /// Fetch a tournament by ID.
  Future<Tournament?> getTournament(String tournamentId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/tournaments/$tournamentId'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Tournament.fromJson(json);
      }
      return null;
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

      final uri = Uri.parse(
        '$_baseUrl/tournaments',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await _httpClient.get(uri);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => Tournament.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
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
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/tournaments/$tournamentId/leaderboard'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Leaderboard.fromJson(json);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
