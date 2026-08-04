// Leaderboard Polling Service — VSP Mobile App
//
// Per Story 12.1 Slice H:
// - Mobile leaderboard polls /tournaments/{id}/leaderboard every 30s when app is active
// - Degraded connectivity: SSE preferred, polling fallback
//
// Story 12.1 Slice H

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/tournament/leaderboard_entry.dart';

/// Period between leaderboard polls while app is active.
const Duration leaderboardPollInterval = Duration(seconds: 30);

/// Manages live leaderboard polling for a tournament.
/// Falls back to HTTP polling when SSE is unavailable.
class LeaderboardNotifier {
  final String _baseUrl;
  final http.Client _httpClient;

  Timer? _pollTimer;
  int _lastKnownVersion = 0;
  String? _activeTournamentId;

  final _controller = StreamController<Leaderboard>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of leaderboard updates.
  Stream<Leaderboard> get leaderboardStream => _controller.stream;

  /// Stream of error messages.
  Stream<String> get errorStream => _errorController.stream;

  /// Currently tracked tournament ID, or null if not tracking.
  String? get activeTournamentId => _activeTournamentId;

  LeaderboardNotifier({required String baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl,
      _httpClient = httpClient ?? http.Client();

  /// Start polling leaderboard for the given tournament.
  /// Idempotent: calling while already tracking the same tournament is a no-op.
  void startTracking(String tournamentId) {
    if (_activeTournamentId == tournamentId && _pollTimer != null) {
      return; // Already tracking
    }

    stopTracking();
    _activeTournamentId = tournamentId;
    _lastKnownVersion = 0;

    // Immediate first fetch
    _fetchLeaderboard();

    // Then poll every 30s
    _pollTimer = Timer.periodic(leaderboardPollInterval, (_) {
      _fetchLeaderboard();
    });
  }

  /// Stop polling and release resources.
  void stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activeTournamentId = null;
  }

  /// Fetch leaderboard from API and emit if version changed.
  Future<void> _fetchLeaderboard() async {
    if (_activeTournamentId == null) return;

    try {
      final uri = Uri.parse(
        '$_baseUrl/tournaments/$_activeTournamentId/leaderboard',
      );
      final response = await _httpClient.get(uri);

      if (response.statusCode == 200) {
        final json =
            jsonDecode(response.body as String) as Map<String, dynamic>;
        final leaderboard = Leaderboard.fromJson(json);

        // Only emit if version incremented (avoid duplicate emissions)
        if (leaderboard.version > _lastKnownVersion) {
          _lastKnownVersion = leaderboard.version;
          _controller.add(leaderboard);
        }
      } else {
        _errorController.add(
          'Failed to fetch leaderboard: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Network error — silently continue polling
      _errorController.add('Leaderboard fetch error: $e');
    }
  }

  /// Dispose of resources.
  void dispose() {
    stopTracking();
    _controller.close();
    _errorController.close();
  }
}
