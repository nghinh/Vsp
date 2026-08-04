// TournamentPolicyRepository — VSP Mobile App
//
// Repository for fetching, creating, and updating tournament policies
// from the backend API, with local SQLite caching for offline use.
//
// Per PRD §8.12: "Tournament Mode may lock after round start."
//
// Story 7.4 — Slice C: TournamentFeatureGuard

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/models/tournament_policy.dart';
import '../../domain/models/tournament_feature.dart';
import '../../application/services/tournament_feature_guard.dart';

/// Repository for TournamentPolicy CRUD operations.
///
/// Uses TournamentPolicyLocalCache for offline-first behavior.
/// API calls are made when online; stale cache is used when offline.
class TournamentPolicyRepository {
  final String _baseUrl;
  final http.Client _httpClient;
  final TournamentPolicyLocalCache _localCache;

  TournamentPolicyRepository({
    required String baseUrl,
    required http.Client httpClient,
    required TournamentPolicyLocalCache localCache,
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient,
       _localCache = localCache;

  /// Fetch a policy by ID.
  ///
  /// Tries API first; falls back to local cache if offline.
  Future<TournamentPolicy?> getPolicy(String policyId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/tournament-policies/$policyId'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final policy = TournamentPolicy.fromJson(json);
        // Cache locally for offline use
        await _localCache.savePolicy(policy);
        return policy;
      }

      // Not found or error — try local cache
      return _localCache.getPolicy(policyId);
    } catch (_) {
      // Network error — use local cache
      return _localCache.getPolicy(policyId);
    }
  }

  /// Create a new policy.
  ///
  /// Returns the created policy with server-assigned ID.
  Future<TournamentPolicy> createPolicy({
    required String name,
    required String createdBy,
    bool windAdjustmentEnabled = true,
    bool playsLikeEnabled = true,
    bool elevationEnabled = true,
    bool clubRecommendationEnabled = true,
    bool contoursEnabled = true,
    bool puttingHelpEnabled = true,
    bool aiFeaturesEnabled = true,
  }) async {
    final body = jsonEncode({
      'name': name,
      'windAdjustmentEnabled': windAdjustmentEnabled,
      'playsLikeEnabled': playsLikeEnabled,
      'elevationEnabled': elevationEnabled,
      'clubRecommendationEnabled': clubRecommendationEnabled,
      'contoursEnabled': contoursEnabled,
      'puttingHelpEnabled': puttingHelpEnabled,
      'aiFeaturesEnabled': aiFeaturesEnabled,
    });

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/tournament-policies'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final policy = TournamentPolicy.fromJson(json);
      await _localCache.savePolicy(policy);
      return policy;
    }

    throw Exception('Failed to create policy: ${response.statusCode}');
  }

  /// Update an existing policy.
  ///
  /// Throws [TournamentPolicyLockedException] if policy is locked
  /// and caller does not have TournamentDirector role.
  Future<TournamentPolicy> updatePolicy({
    required String policyId,
    required Map<TournamentFeature, bool> featureChanges,
    required bool actorHasDirectorRole,
    String? reason,
  }) async {
    // Build update payload
    final updates = <String, dynamic>{};
    for (final entry in featureChanges.entries) {
      updates[entry.key.flagName] = entry.value;
    }
    if (reason != null) updates['reason'] = reason;

    final body = jsonEncode(updates);

    final response = await _httpClient.patch(
      Uri.parse('$_baseUrl/tournament-policies/$policyId'),
      headers: {
        'Content-Type': 'application/json',
        if (actorHasDirectorRole) 'X-Has-Director-Role': 'true',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final policy = TournamentPolicy.fromJson(json);
      await _localCache.savePolicy(policy);
      return policy;
    }

    if (response.statusCode == 403) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw TournamentPolicyLockedException(
        error['message'] as String? ?? 'Policy is locked',
      );
    }

    throw Exception('Failed to update policy: ${response.statusCode}');
  }

  /// Lock a policy (called when tournament round starts).
  Future<void> lockPolicy(String policyId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/tournament-policies/$policyId/lock'),
      );

      // Even if server returns error, the round has already started.
      // The policy will be locked server-side.
      if (response.statusCode == 200) {
        // Invalidate local cache so next fetch gets fresh state
        await _localCache.removePolicy(policyId);
      }
    } catch (_) {
      // Network error — server will lock on next sync
    }
  }
}
